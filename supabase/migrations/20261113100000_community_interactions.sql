-- Community interactions: comments and replies, comment likes, a single post, activity notifications,
-- and message requests (the pet's owner must accept before a chat starts).
-- Everything goes through functions; the tables are not readable or writable directly.

-- ---------------------------------------------------------------------------
-- Comments (one level of replies) and comment likes
-- ---------------------------------------------------------------------------
create table public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  author_user_id uuid not null references auth.users (id) on delete cascade,
  parent_id uuid references public.post_comments (id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  status text not null default 'published' check (status in ('published', 'hidden', 'removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.post_comments (post_id, created_at);
create index on public.post_comments (parent_id);
create index on public.post_comments (author_user_id, created_at desc);
alter table public.post_comments enable row level security;
revoke all on public.post_comments from anon, authenticated;

create table public.comment_likes (
  comment_id uuid not null references public.post_comments (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);
create index on public.comment_likes (user_id);
alter table public.comment_likes enable row level security;
revoke all on public.comment_likes from anon, authenticated;

-- A short name for notifications.
create function private.display_name(p_user uuid) returns text
language sql stable security definer
set search_path = ''
as $$
  select coalesce(nullif(btrim(pr.first_name), ''), 'Someone')
    from public.profiles pr where pr.user_id = p_user;
$$;
revoke all on function private.display_name(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Likes tell the author (once per person per post)
-- ---------------------------------------------------------------------------
create or replace function public.toggle_like(p_post uuid) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  liked boolean;
  author uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if not private.can_see_post(p_post) then
    raise exception 'Post not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.post_likes where post_id = p_post and user_id = me) then
    delete from public.post_likes where post_id = p_post and user_id = me;
    liked := false;
  else
    insert into public.post_likes (post_id, user_id) values (p_post, me);
    liked := true;
    select author_user_id into author from public.posts where id = p_post;
    if author is not null and author <> me and not private.is_blocked_between(author, me) then
      perform private.notify(author, 'community', private.display_name(me) || ' liked your post', null,
                             '/posts/' || p_post, 'like:' || p_post || ':' || me);
    end if;
  end if;
  return jsonb_build_object('liked', liked, 'count', (select count(*) from public.post_likes where post_id = p_post));
end;
$$;

-- ---------------------------------------------------------------------------
-- Comments
-- ---------------------------------------------------------------------------
create function public.post_comments_list(p_post uuid, p_limit integer default 200)
returns table (
  comment_id uuid,
  parent_id uuid,
  author_user_id uuid,
  author_name text,
  body text,
  created_at timestamptz,
  like_count bigint,
  liked_by_me boolean,
  is_mine boolean
)
language sql stable security definer
set search_path = ''
as $$
  select c.id, c.parent_id, c.author_user_id,
         coalesce(nullif(btrim(pr.first_name), ''), 'A pet owner'),
         c.body, c.created_at,
         (select count(*) from public.comment_likes l where l.comment_id = c.id),
         exists (select 1 from public.comment_likes l where l.comment_id = c.id and l.user_id = (select auth.uid())),
         c.author_user_id = (select auth.uid())
    from public.post_comments c
    join public.profiles pr on pr.user_id = c.author_user_id
    left join public.post_comments par on par.id = c.parent_id
   where c.post_id = p_post
     and (select auth.uid()) is not null
     and private.can_see_post(p_post)
     and c.status = 'published'
     and (c.parent_id is null or par.status = 'published')
     and not private.is_blocked_between(c.author_user_id, (select auth.uid()))
   order by c.created_at
   limit least(greatest(coalesce(p_limit, 200), 1), 500);
$$;
revoke all on function public.post_comments_list(uuid, integer) from public, anon;
grant execute on function public.post_comments_list(uuid, integer) to authenticated;

create function public.add_comment(p_post uuid, p_body text, p_parent uuid default null) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  body text := btrim(coalesce(p_body, ''));
  post_author uuid;
  parent public.post_comments;
  new_id uuid;
  who text;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if not private.can_see_post(p_post) then
    raise exception 'Post not found' using errcode = 'P0002';
  end if;
  if body = '' then
    raise exception 'Write a comment first' using errcode = '22023';
  end if;
  if char_length(body) > 1000 then
    raise exception 'That comment is too long' using errcode = '22023';
  end if;
  if (select count(*) from public.post_comments c
       where c.author_user_id = me and c.created_at > now() - interval '10 minutes') >= 20 then
    raise exception 'You are commenting very quickly. Wait a few minutes and try again.' using errcode = 'P0001';
  end if;
  if p_parent is not null then
    select * into parent from public.post_comments where id = p_parent;
    if not found or parent.post_id <> p_post or parent.status <> 'published' then
      raise exception 'That comment is no longer there' using errcode = 'P0002';
    end if;
    if parent.parent_id is not null then
      -- Replies stay one level deep: answer the top comment instead.
      p_parent := parent.parent_id;
      select * into parent from public.post_comments where id = p_parent;
    end if;
    if private.is_blocked_between(parent.author_user_id, me) then
      raise exception 'That comment is no longer there' using errcode = 'P0002';
    end if;
  end if;

  insert into public.post_comments (post_id, author_user_id, parent_id, body)
  values (p_post, me, p_parent, body)
  returning id into new_id;

  who := private.display_name(me);
  select author_user_id into post_author from public.posts where id = p_post;
  if post_author <> me and not private.is_blocked_between(post_author, me) then
    perform private.notify(post_author, 'community',
      who || case when p_parent is null then ' commented on your post' else ' replied on your post' end,
      left(body, 120), '/posts/' || p_post, 'comment:' || new_id);
  end if;
  if p_parent is not null and parent.author_user_id <> me and parent.author_user_id <> post_author
     and not private.is_blocked_between(parent.author_user_id, me) then
    perform private.notify(parent.author_user_id, 'community', who || ' replied to your comment',
      left(body, 120), '/posts/' || p_post, 'reply:' || new_id);
  end if;
  return new_id;
end;
$$;
revoke all on function public.add_comment(uuid, text, uuid) from public, anon;
grant execute on function public.add_comment(uuid, text, uuid) to authenticated;

-- The author of a comment, or the author of the post it is on, can remove it.
create function public.delete_comment(p_comment uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  c public.post_comments;
  post_author uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into c from public.post_comments where id = p_comment;
  if not found then
    raise exception 'Comment not found' using errcode = 'P0002';
  end if;
  select author_user_id into post_author from public.posts where id = c.post_id;
  if c.author_user_id <> me and post_author is distinct from me then
    raise exception 'You can only remove your own comments' using errcode = '42501';
  end if;
  update public.post_comments set status = 'removed', updated_at = now() where id = p_comment;
end;
$$;
revoke all on function public.delete_comment(uuid) from public, anon;
grant execute on function public.delete_comment(uuid) to authenticated;

create function public.toggle_comment_like(p_comment uuid) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  c public.post_comments;
  liked boolean;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into c from public.post_comments where id = p_comment and status = 'published';
  if not found or not private.can_see_post(c.post_id) then
    raise exception 'Comment not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.comment_likes where comment_id = p_comment and user_id = me) then
    delete from public.comment_likes where comment_id = p_comment and user_id = me;
    liked := false;
  else
    insert into public.comment_likes (comment_id, user_id) values (p_comment, me);
    liked := true;
    if c.author_user_id <> me and not private.is_blocked_between(c.author_user_id, me) then
      perform private.notify(c.author_user_id, 'community', private.display_name(me) || ' liked your comment',
        left(c.body, 120), '/posts/' || c.post_id, 'clike:' || p_comment || ':' || me);
    end if;
  end if;
  return jsonb_build_object('liked', liked, 'count', (select count(*) from public.comment_likes where comment_id = p_comment));
end;
$$;
revoke all on function public.toggle_comment_like(uuid) from public, anon;
grant execute on function public.toggle_comment_like(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- The feed and a pet's posts now carry a comment count; one post can be opened by itself.
-- ---------------------------------------------------------------------------
drop function public.community_feed(text, integer, timestamptz);
create function public.community_feed(p_scope text default 'for_you', p_limit integer default 20, p_before timestamptz default null)
returns table (
  post_id uuid,
  author_user_id uuid,
  author_name text,
  author_area text,
  pet_id uuid,
  pet_name text,
  pet_species text,
  pet_breed text,
  pet_photo_path text,
  body text,
  media_paths text[],
  area text,
  created_at timestamptz,
  like_count bigint,
  liked_by_me boolean,
  following_pet boolean,
  is_mine boolean,
  comment_count bigint
)
language sql stable security definer
set search_path = ''
as $$
  select
    po.id, po.author_user_id,
    coalesce(nullif(btrim(pr.first_name), ''), 'A pet owner'),
    pr.area,
    pe.id, pe.name, pe.species, pe.breed, pe.photo_path,
    po.body, po.media_paths, po.area, po.created_at,
    (select count(*) from public.post_likes l where l.post_id = po.id),
    exists (select 1 from public.post_likes l where l.post_id = po.id and l.user_id = (select auth.uid())),
    po.pet_id is not null and private.follows_pet(po.pet_id),
    po.author_user_id = (select auth.uid()),
    (select count(*) from public.post_comments c where c.post_id = po.id and c.status = 'published')
  from public.posts po
  join public.profiles pr on pr.user_id = po.author_user_id
  left join public.pets pe on pe.id = po.pet_id
  where (select auth.uid()) is not null
    and private.can_see_post(po.id)
    and po.status = 'published'
    and (p_scope <> 'near' or (po.area is not null and po.area = private.my_area()))
    and (p_before is null or po.created_at < p_before)
  order by po.created_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;
revoke all on function public.community_feed(text, integer, timestamptz) from public, anon;
grant execute on function public.community_feed(text, integer, timestamptz) to authenticated;

create function public.post_detail(p_post uuid)
returns table (
  post_id uuid,
  author_user_id uuid,
  author_name text,
  author_area text,
  pet_id uuid,
  pet_name text,
  pet_species text,
  pet_breed text,
  pet_photo_path text,
  body text,
  media_paths text[],
  area text,
  created_at timestamptz,
  like_count bigint,
  liked_by_me boolean,
  following_pet boolean,
  is_mine boolean,
  comment_count bigint
)
language sql stable security definer
set search_path = ''
as $$
  select
    po.id, po.author_user_id,
    coalesce(nullif(btrim(pr.first_name), ''), 'A pet owner'),
    pr.area,
    pe.id, pe.name, pe.species, pe.breed, pe.photo_path,
    po.body, po.media_paths, po.area, po.created_at,
    (select count(*) from public.post_likes l where l.post_id = po.id),
    exists (select 1 from public.post_likes l where l.post_id = po.id and l.user_id = (select auth.uid())),
    po.pet_id is not null and private.follows_pet(po.pet_id),
    po.author_user_id = (select auth.uid()),
    (select count(*) from public.post_comments c where c.post_id = po.id and c.status = 'published')
  from public.posts po
  join public.profiles pr on pr.user_id = po.author_user_id
  left join public.pets pe on pe.id = po.pet_id
  where po.id = p_post
    and (select auth.uid()) is not null
    and private.can_see_post(po.id)
    and po.status = 'published';
$$;
revoke all on function public.post_detail(uuid) from public, anon;
grant execute on function public.post_detail(uuid) to authenticated;

drop function public.pet_posts(uuid, integer);
create function public.pet_posts(p_pet uuid, p_limit integer default 20)
returns table (post_id uuid, body text, media_paths text[], area text, created_at timestamptz, like_count bigint, liked_by_me boolean, comment_count bigint)
language sql stable security definer
set search_path = ''
as $$
  select po.id, po.body, po.media_paths, po.area, po.created_at,
         (select count(*) from public.post_likes l where l.post_id = po.id),
         exists (select 1 from public.post_likes l where l.post_id = po.id and l.user_id = (select auth.uid())),
         (select count(*) from public.post_comments c where c.post_id = po.id and c.status = 'published')
    from public.posts po
   where po.pet_id = p_pet and po.status = 'published' and private.can_see_post(po.id)
   order by po.created_at desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;
revoke all on function public.pet_posts(uuid, integer) from public, anon;
grant execute on function public.pet_posts(uuid, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Reporting a comment
-- ---------------------------------------------------------------------------
do $$
declare c text;
begin
  select conname into c
    from pg_constraint
   where conrelid = 'public.reports'::regclass and contype = 'c'
     and pg_get_constraintdef(oid) like '%target_type%';
  if c is not null then
    execute format('alter table public.reports drop constraint %I', c);
  end if;
end $$;
alter table public.reports
  add constraint reports_target_type_check
  check (target_type in ('post', 'profile', 'listing', 'review', 'user', 'lost_alert', 'comment'));

create or replace function public.file_report(p_target_type text, p_target_id uuid, p_reason text, p_block boolean default false)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  label text;
  target_user uuid;
  target_post uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  label := case p_reason
    when 'scam' then 'Scam or fake seller'
    when 'cruelty' then 'Animal cruelty or neglect'
    when 'unsafe_advice' then 'Unsafe health advice'
    when 'harassment' then 'Harassment or hate'
    when 'spam' then 'Spam or something else'
  end;
  if label is null then
    raise exception 'Choose a reason' using errcode = '22023';
  end if;

  -- Reporting twice is quietly ignored (checked first: a block from the first report hides the post).
  if exists (select 1 from public.reports r
              where r.reporter_user_id = me and r.target_type = p_target_type and r.target_id = p_target_id
                and r.status = 'open') then
    return;
  end if;

  if p_target_type = 'post' then
    if not private.can_see_post(p_target_id) then
      raise exception 'We could not find that post' using errcode = 'P0002';
    end if;
    select author_user_id into target_user from public.posts where id = p_target_id;
  elsif p_target_type = 'comment' then
    select c.author_user_id, c.post_id into target_user, target_post
      from public.post_comments c where c.id = p_target_id and c.status = 'published';
    if target_user is null or not private.can_see_post(target_post) then
      raise exception 'We could not find that comment' using errcode = 'P0002';
    end if;
  elsif p_target_type = 'user' or p_target_type = 'profile' then
    select user_id into target_user from public.profiles where user_id = p_target_id;
  elsif p_target_type = 'lost_alert' then
    select p.owner_user_id into target_user
      from public.lost_alerts a join public.pets p on p.id = a.pet_id where a.id = p_target_id;
  else
    raise exception 'That cannot be reported here' using errcode = '22023';
  end if;
  if target_user is null then
    raise exception 'We could not find that' using errcode = 'P0002';
  end if;
  if target_user = me then
    raise exception 'You cannot report yourself' using errcode = '22023';
  end if;
  insert into public.reports (reporter_user_id, target_type, target_id, reason)
  values (me, p_target_type, p_target_id, label);
  if p_block then
    insert into public.blocks (user_id, blocked_user_id) values (me, target_user) on conflict do nothing;
  end if;
end;
$$;

create or replace view public.admin_report_v with (security_invoker = true) as
with grouped as (
  select
    r.target_type,
    r.target_id,
    count(*) as report_count,
    min(r.created_at) as first_reported_at,
    (array_agg(r.reason order by r.created_at))[1] as top_reason,
    bool_or(r.status = 'open') as is_open,
    max(r.status) as last_status,
    max(r.action) as action
  from public.reports r
  group by r.target_type, r.target_id
)
select
  g.*,
  case g.target_type
    when 'post' then (select left(po.body, 160) from public.posts po where po.id = g.target_id)
    when 'comment' then (select 'Comment: ' || left(c.body, 150) from public.post_comments c where c.id = g.target_id)
    when 'listing' then (select pt.name || ' · ' || l.kind || coalesce(' · ₦' || (l.price_kobo / 100)::text, '')
                           from public.listings l join public.pets pt on pt.id = l.pet_id where l.id = g.target_id)
    when 'review' then (select rv.rating || ' star review' || coalesce(': ' || left(rv.body, 120), '')
                          from public.reviews rv where rv.id = g.target_id)
    when 'lost_alert' then (select 'Lost alert · ' || pt.name
                              from public.lost_alerts la join public.pets pt on pt.id = la.pet_id where la.id = g.target_id)
    else (select trim(pr.first_name || ' ' || pr.last_name) from public.profiles pr
            where pr.user_id = g.target_id or pr.id = g.target_id limit 1)
  end as summary,
  (select a.business_name from public.listings l join public.partner_accounts a on a.id = l.partner_account_id
    where g.target_type = 'listing' and l.id = g.target_id) as seller_name,
  (select a.status from public.listings l join public.partner_accounts a on a.id = l.partner_account_id
    where g.target_type = 'listing' and l.id = g.target_id) as seller_status,
  (select extract(day from now() - a.created_at)::int from public.listings l join public.partner_accounts a on a.id = l.partner_account_id
    where g.target_type = 'listing' and l.id = g.target_id) as seller_age_days,
  (select l.price_kobo from public.listings l where g.target_type = 'listing' and l.id = g.target_id) as price_kobo,
  (select avg(l2.price_kobo)::bigint
     from public.listings l
     join public.pets p1 on p1.id = l.pet_id
     join public.pets p2 on p2.breed is not distinct from p1.breed
     join public.listings l2 on l2.pet_id = p2.id and l2.id <> l.id and l2.price_kobo is not null
    where g.target_type = 'listing' and l.id = g.target_id) as avg_price_kobo
from grouped g;

create or replace function public.admin_resolve_report(p_target_type text, p_target_id uuid, p_action text, p_note text default null)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_user uuid;
begin
  perform private.require_staff(array['support_reports']);
  if p_action not in ('remove_and_suspend', 'remove', 'keep') then
    raise exception 'Unknown action' using errcode = '22023';
  end if;
  if not exists (select 1 from public.reports where target_type = p_target_type and target_id = p_target_id and status = 'open') then
    raise exception 'There are no open reports for this item' using errcode = 'P0002';
  end if;

  if p_action <> 'keep' then
    case p_target_type
      when 'post' then
        update public.posts set status = 'removed' where id = p_target_id returning author_user_id into v_user;
      when 'comment' then
        update public.post_comments set status = 'removed', updated_at = now() where id = p_target_id returning author_user_id into v_user;
      when 'listing' then
        update public.listings set status = 'removed' where id = p_target_id;
        select a.owner_user_id into v_user from public.listings l
          join public.partner_accounts a on a.id = l.partner_account_id where l.id = p_target_id;
      when 'review' then
        update public.reviews set status = 'hidden' where id = p_target_id;
        select b.owner_user_id into v_user from public.reviews r
          join public.bookings b on b.id = r.booking_id where r.id = p_target_id;
      when 'lost_alert' then
        update public.lost_alerts set status = 'closed' where id = p_target_id;
        select pt.owner_user_id into v_user from public.lost_alerts la
          join public.pets pt on pt.id = la.pet_id where la.id = p_target_id;
      else
        select coalesce((select user_id from public.profiles where id = p_target_id), p_target_id) into v_user;
    end case;

    if p_action = 'remove_and_suspend' then
      if v_user is null then
        raise exception 'Could not find the account to suspend' using errcode = 'P0002';
      end if;
      perform private.suspend_user(v_user, coalesce(nullif(btrim(p_note), ''), 'Suspended after a report'));
    end if;
  end if;

  update public.reports
     set status = case when p_action = 'keep' then 'dismissed' else 'actioned' end,
         action = p_action,
         decided_by_staff_id = private.current_staff_id()
   where target_type = p_target_type and target_id = p_target_id and status = 'open';

  perform private.write_audit('report.' || p_action, p_target_type, p_target_id,
    jsonb_build_object('note', nullif(btrim(p_note), ''), 'suspended_user', case when p_action = 'remove_and_suspend' then v_user end));
end;
$$;

-- ---------------------------------------------------------------------------
-- Message requests: the pet's owner accepts before a chat starts
-- ---------------------------------------------------------------------------
do $$
declare c text;
begin
  select conname into c
    from pg_constraint
   where conrelid = 'public.conversations'::regclass and contype = 'c'
     and pg_get_constraintdef(oid) like '%context_type%';
  if c is not null then
    execute format('alter table public.conversations drop constraint %I', c);
  end if;
end $$;
alter table public.conversations
  add constraint conversations_context_type_check
  check (context_type in ('lost_alert', 'booking', 'listing', 'adoption', 'support', 'direct'));

create table public.direct_requests (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null unique references public.conversations (id) on delete cascade,
  requester_user_id uuid not null references auth.users (id) on delete cascade,
  recipient_user_id uuid not null references auth.users (id) on delete cascade,
  pet_id uuid references public.pets (id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  check (requester_user_id <> recipient_user_id),
  unique (requester_user_id, recipient_user_id)
);
create index on public.direct_requests (recipient_user_id, status);
alter table public.direct_requests enable row level security;
revoke all on public.direct_requests from anon, authenticated;

create function public.request_chat(p_pet uuid, p_message text) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  body text := btrim(coalesce(p_message, ''));
  owner uuid;
  pet_name text;
  existing public.direct_requests;
  conv uuid;
  req uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select p.owner_user_id, p.name into owner, pet_name from public.pets p where p.id = p_pet;
  if owner is null or not (private.pet_is_public(p_pet) or private.follows_pet(p_pet)) then
    raise exception 'We could not find that pet' using errcode = 'P0002';
  end if;
  if owner = me then
    raise exception 'That is your own pet' using errcode = '22023';
  end if;
  if private.is_blocked_between(owner, me) then
    raise exception 'We could not find that pet' using errcode = 'P0002';
  end if;

  select * into existing from public.direct_requests
   where (requester_user_id = me and recipient_user_id = owner)
      or (requester_user_id = owner and recipient_user_id = me)
   limit 1;
  if found then
    if existing.status = 'declined' then
      raise exception 'This person is not taking messages from you right now' using errcode = 'P0001';
    end if;
    return existing.conversation_id;
  end if;

  if body = '' then
    raise exception 'Write a short message first' using errcode = '22023';
  end if;
  if char_length(body) > 500 then
    raise exception 'Keep the first message under 500 characters' using errcode = '22023';
  end if;
  if (select count(*) from public.direct_requests r
       where r.requester_user_id = me and r.created_at > now() - interval '24 hours') >= 10 then
    raise exception 'You have sent a lot of message requests today. Try again tomorrow.' using errcode = 'P0001';
  end if;

  insert into public.conversations (context_type, context_id) values ('direct', p_pet) returning id into conv;
  insert into public.conversation_members (conversation_id, user_id) values (conv, me), (conv, owner);
  insert into public.direct_requests (conversation_id, requester_user_id, recipient_user_id, pet_id)
  values (conv, me, owner, p_pet) returning id into req;
  insert into public.messages (conversation_id, sender_user_id, body) values (conv, me, body);
  update public.conversation_members set last_read_at = now() where conversation_id = conv and user_id = me;

  perform private.notify(owner, 'community', private.display_name(me) || ' wants to message you',
    'About ' || pet_name || ': ' || left(body, 100), '/messages', 'dm_req:' || req);
  return conv;
end;
$$;
revoke all on function public.request_chat(uuid, text) from public, anon;
grant execute on function public.request_chat(uuid, text) to authenticated;

create function public.respond_to_chat_request(p_request uuid, p_accept boolean) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  r public.direct_requests;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into r from public.direct_requests where id = p_request and recipient_user_id = me for update;
  if not found then
    raise exception 'Request not found' using errcode = 'P0002';
  end if;
  if r.status <> 'pending' then
    raise exception 'You already answered this request' using errcode = 'P0001';
  end if;
  update public.direct_requests
     set status = case when p_accept then 'accepted' else 'declined' end, decided_at = now()
   where id = p_request;
  if p_accept then
    perform private.notify(r.requester_user_id, 'community', private.display_name(me) || ' accepted your message',
      'You can chat now.', '/chat/' || r.conversation_id, 'dm_ok:' || p_request);
  end if;
end;
$$;
revoke all on function public.respond_to_chat_request(uuid, boolean) from public, anon;
grant execute on function public.respond_to_chat_request(uuid, boolean) to authenticated;

-- Messages: a direct chat needs the owner's acceptance first, and every message tells the other person.
create or replace function public.send_message(
  p_conversation uuid,
  p_body text default null,
  p_lat double precision default null,
  p_lng double precision default null
) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  body text := nullif(btrim(coalesce(p_body, '')), '');
  loc extensions.geography;
  id uuid;
  other record;
  dr public.direct_requests;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if not private.in_conversation(p_conversation) then
    raise exception 'Conversation not found' using errcode = '42501';
  end if;
  if (p_lat is null) <> (p_lng is null) then
    raise exception 'Share a full location' using errcode = '22023';
  end if;
  if p_lat is not null then
    if p_lat not between -90 and 90 or p_lng not between -180 and 180 then
      raise exception 'That location is not valid' using errcode = '22023';
    end if;
    loc := extensions.st_point(p_lng, p_lat, 4326)::extensions.geography;
  end if;
  if body is null and loc is null then
    raise exception 'Write a message first' using errcode = '22023';
  end if;
  if char_length(coalesce(body, '')) > 1000 then
    raise exception 'That message is too long' using errcode = '22023';
  end if;

  select * into dr from public.direct_requests where conversation_id = p_conversation;
  if found then
    if dr.status = 'declined' then
      raise exception 'This chat is closed' using errcode = 'P0001';
    elsif dr.status = 'pending' and dr.requester_user_id = me then
      raise exception 'Wait for them to accept your request before sending more' using errcode = 'P0001';
    elsif dr.status = 'pending' then
      raise exception 'Accept the request to reply' using errcode = 'P0001';
    end if;
  end if;

  for other in
    select m.user_id from public.conversation_members m
     where m.conversation_id = p_conversation and m.user_id <> me
  loop
    if private.is_blocked_between(other.user_id, me) then
      raise exception 'You can no longer message this person' using errcode = 'P0001';
    end if;
  end loop;

  insert into public.messages (conversation_id, sender_user_id, body, location)
  values (p_conversation, me, body, loc)
  returning messages.id into id;
  update public.conversations set updated_at = now() where conversations.id = p_conversation;
  update public.conversation_members set last_read_at = now()
   where conversation_id = p_conversation and user_id = me;

  -- One notification per conversation per half hour, so a busy chat does not flood the list.
  for other in
    select m.user_id from public.conversation_members m
     where m.conversation_id = p_conversation and m.user_id <> me
  loop
    perform private.notify(other.user_id, 'community', private.display_name(me) || ' sent you a message',
      left(coalesce(body, 'Shared a location'), 100), '/chat/' || p_conversation,
      'msg:' || p_conversation || ':' || floor(extract(epoch from now()) / 1800)::bigint);
  end loop;
  return id;
end;
$$;

-- The inbox now says which chats are requests. Declined requests are hidden from both people.
drop function public.conversation_header(uuid);
drop function public.my_conversations();
create function public.my_conversations()
returns table (
  conversation_id uuid,
  context_type text,
  context_id uuid,
  context_label text,
  other_user_id uuid,
  other_name text,
  last_body text,
  last_at timestamptz,
  unread integer,
  request_id uuid,
  request_status text,
  i_requested boolean
)
language sql stable security definer
set search_path = ''
as $$
  select c.id, c.context_type, c.context_id,
         case c.context_type
           when 'lost_alert' then 'Lost alert · ' || coalesce((
             select p.name from public.lost_alerts a join public.pets p on p.id = a.pet_id where a.id = c.context_id), 'a pet')
           when 'listing' then 'Listing · ' || coalesce((
             select p.name from public.listings l join public.pets p on p.id = l.pet_id where l.id = c.context_id), 'a pet')
           when 'direct' then 'About ' || coalesce((select p.name from public.pets p where p.id = c.context_id), 'a pet')
           else initcap(replace(c.context_type, '_', ' '))
         end,
         o.user_id,
         coalesce(nullif(btrim(op.first_name), ''), 'Someone'),
         case when lm.location is not null and lm.body is null then 'Shared a location' else lm.body end,
         coalesce(lm.created_at, c.created_at),
         (select count(*)::integer from public.messages m
           where m.conversation_id = c.id and m.sender_user_id <> (select auth.uid())
             and (me.last_read_at is null or m.created_at > me.last_read_at)),
         dr.id,
         dr.status,
         dr.requester_user_id = (select auth.uid())
    from public.conversations c
    join public.conversation_members me on me.conversation_id = c.id and me.user_id = (select auth.uid())
    join public.conversation_members o on o.conversation_id = c.id and o.user_id <> (select auth.uid())
    join public.profiles op on op.user_id = o.user_id
    left join public.direct_requests dr on dr.conversation_id = c.id
    left join lateral (
      select m.body, m.location, m.created_at from public.messages m
       where m.conversation_id = c.id order by m.created_at desc limit 1
    ) lm on true
   where not private.is_blocked_between(o.user_id, (select auth.uid()))
     and coalesce(dr.status, 'accepted') <> 'declined'
   order by coalesce(lm.created_at, c.created_at) desc;
$$;
revoke all on function public.my_conversations() from public, anon;
grant execute on function public.my_conversations() to authenticated;

create function public.conversation_header(p_conversation uuid) returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object(
           'conversation_id', c.conversation_id, 'context_type', c.context_type, 'context_id', c.context_id,
           'context_label', c.context_label, 'other_name', c.other_name, 'other_user_id', c.other_user_id,
           'request_id', c.request_id, 'request_status', c.request_status, 'i_requested', c.i_requested)
    from public.my_conversations() c
   where c.conversation_id = p_conversation;
$$;
revoke all on function public.conversation_header(uuid) from public, anon;
grant execute on function public.conversation_header(uuid) to authenticated;
