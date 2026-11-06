-- Community, lost and found, and chat (milestone 4).
-- Feed, likes, pet profiles, lost pet alerts with nearby notifications, sightings, alert chats, reports.
-- Phone numbers are never returned by any function here.

-- ---------------------------------------------------------------------------
-- Where a person last was, so lost alerts can reach people nearby. Coarse and optional: set only through
-- update_my_location, never readable by other people.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column last_point extensions.geography(Point, 4326),
  add column last_point_at timestamptz;

alter table public.lost_alerts add column address text check (char_length(address) <= 200);
grant update (address) on public.lost_alerts to authenticated;
-- one live alert per pet
create unique index lost_alerts_one_active on public.lost_alerts (pet_id) where status = 'active';

create function public.update_my_location(p_lat double precision, p_lng double precision) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'That location is not valid' using errcode = '22023';
  end if;
  update public.profiles
     set last_point = extensions.st_point(p_lng, p_lat, 4326)::extensions.geography,
         last_point_at = now()
   where user_id = (select auth.uid());
end;
$$;
revoke all on function public.update_my_location(double precision, double precision) from public, anon;
grant execute on function public.update_my_location(double precision, double precision) to authenticated;

-- ---------------------------------------------------------------------------
-- Likes
-- ---------------------------------------------------------------------------
create table public.post_likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index on public.post_likes (user_id);
alter table public.post_likes enable row level security;
create policy "read own likes" on public.post_likes for select to authenticated
  using (user_id = (select auth.uid()));
revoke all on public.post_likes from anon, authenticated;
grant select on public.post_likes to authenticated;

-- Can the signed in person see this post? The same rule as the posts policy, usable from functions.
create function private.can_see_post(p_post uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.posts po
    where po.id = p_post
      and (
        po.author_user_id = (select auth.uid())
        or (
          po.status = 'published'
          and not private.is_blocked_between(po.author_user_id, (select auth.uid()))
          and (
            po.visibility = 'everyone'
            or (po.visibility = 'nearby' and po.area is not null and po.area = private.my_area())
            or (po.visibility = 'followers' and po.pet_id is not null and private.follows_pet(po.pet_id))
          )
        )
      )
  );
$$;
revoke all on function private.can_see_post(uuid) from public, anon;
grant execute on function private.can_see_post(uuid) to authenticated;

create function public.toggle_like(p_post uuid) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  liked boolean;
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
  end if;
  return jsonb_build_object('liked', liked, 'count', (select count(*) from public.post_likes where post_id = p_post));
end;
$$;
revoke all on function public.toggle_like(uuid) from public, anon;
grant execute on function public.toggle_like(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Posts
-- ---------------------------------------------------------------------------
create function public.create_post(
  p_pet uuid,
  p_body text,
  p_media text[] default '{}',
  p_visibility text default 'everyone',
  p_show_area boolean default true
) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  body text := btrim(coalesce(p_body, ''));
  area text := private.my_area();
  path text;
  id uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if p_visibility not in ('everyone', 'nearby', 'followers') then
    raise exception 'Choose who can see this post' using errcode = '22023';
  end if;
  if char_length(body) > 500 then
    raise exception 'A post can be at most 500 characters' using errcode = '22023';
  end if;
  if coalesce(cardinality(p_media), 0) > 4 then
    raise exception 'A post can have at most 4 photos' using errcode = '22023';
  end if;
  if body = '' and coalesce(cardinality(p_media), 0) = 0 then
    raise exception 'Write something or add a photo' using errcode = '22023';
  end if;
  foreach path in array coalesce(p_media, '{}') loop
    if path not like me::text || '/%' then
      raise exception 'Photos must be uploaded to your own folder' using errcode = '22023';
    end if;
  end loop;
  if p_pet is not null and not private.owns_pet(p_pet) then
    raise exception 'Pet not found' using errcode = '42501';
  end if;
  if p_visibility = 'followers' and p_pet is null then
    raise exception 'Followers see posts about a pet. Choose a pet to post as.' using errcode = '22023';
  end if;
  if p_visibility = 'nearby' and (area is null or not p_show_area) then
    raise exception 'Nearby posts need your area. Turn on "Show area" and set your area in your profile.' using errcode = '22023';
  end if;

  insert into public.posts (author_user_id, pet_id, body, media_paths, visibility, area)
  values (me, p_pet, body, coalesce(p_media, '{}'), p_visibility, case when p_show_area then area end)
  returning posts.id into id;
  return id;
end;
$$;
revoke all on function public.create_post(uuid, text, text[], text, boolean) from public, anon;
grant execute on function public.create_post(uuid, text, text[], text, boolean) to authenticated;

-- The feed. 'for_you' is everything the person may see; 'near' is posts from their own area.
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
  is_mine boolean
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
    po.author_user_id = (select auth.uid())
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

-- ---------------------------------------------------------------------------
-- Pet profile: identity only. Health records stay private.
-- ---------------------------------------------------------------------------
create function public.pet_profile(p_pet uuid) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  p public.pets;
  owner public.profiles;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into p from public.pets where id = p_pet;
  if not found or not (private.owns_pet(p_pet) or private.pet_is_public(p_pet) or private.follows_pet(p_pet)) then
    raise exception 'Pet not found' using errcode = 'P0002';
  end if;
  if private.is_blocked_between(p.owner_user_id, me) then
    raise exception 'Pet not found' using errcode = 'P0002';
  end if;
  select * into owner from public.profiles where user_id = p.owner_user_id;
  return jsonb_build_object(
    'id', p.id,
    'name', p.name,
    'species', p.species,
    'breed', p.breed,
    'photo_path', p.photo_path,
    'age_months', case when p.date_of_birth is null then null
                       else (extract(year from age(current_date, p.date_of_birth)) * 12
                             + extract(month from age(current_date, p.date_of_birth)))::int end,
    'owner_user_id', p.owner_user_id,
    'owner_name', coalesce(nullif(btrim(owner.first_name), ''), 'A pet owner'),
    'area', owner.area,
    'is_mine', p.owner_user_id = me,
    'is_following', private.follows_pet(p.id),
    'posts', (select count(*) from public.posts po
               where po.pet_id = p.id and po.status = 'published' and po.visibility = 'everyone'),
    'followers', (select count(*) from public.follows f where f.pet_id = p.id),
    'following', (select count(*) from public.follows f where f.follower_user_id = p.owner_user_id),
    'lost', exists (select 1 from public.lost_alerts l where l.pet_id = p.id and l.status = 'active')
  );
end;
$$;
revoke all on function public.pet_profile(uuid) from public, anon;
grant execute on function public.pet_profile(uuid) to authenticated;

-- A pet's own posts (what its profile shows).
create function public.pet_posts(p_pet uuid, p_limit integer default 20)
returns table (post_id uuid, body text, media_paths text[], area text, created_at timestamptz, like_count bigint, liked_by_me boolean)
language sql stable security definer
set search_path = ''
as $$
  select po.id, po.body, po.media_paths, po.area, po.created_at,
         (select count(*) from public.post_likes l where l.post_id = po.id),
         exists (select 1 from public.post_likes l where l.post_id = po.id and l.user_id = (select auth.uid()))
    from public.posts po
   where po.pet_id = p_pet and po.status = 'published' and private.can_see_post(po.id)
   order by po.created_at desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;
revoke all on function public.pet_posts(uuid, integer) from public, anon;
grant execute on function public.pet_posts(uuid, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Lost pet alerts
-- ---------------------------------------------------------------------------
-- Tells people who were recently near the spot (and have not blocked or been blocked by the owner).
-- Only counts are returned to the caller; the notification carries the pet and place, never contact details.
create function private.fan_out_lost_alert(p_alert uuid) returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  a public.lost_alerts;
  p public.pets;
  n integer;
begin
  select * into a from public.lost_alerts where id = p_alert;
  select * into p from public.pets where id = a.pet_id;
  with targets as (
    select pr.user_id
      from public.profiles pr
     where pr.user_id <> p.owner_user_id
       and pr.last_point is not null
       and pr.last_point_at > now() - interval '30 days'
       and extensions.st_dwithin(pr.last_point, a.last_seen_point, a.radius_m)
       and not private.is_blocked_between(pr.user_id, p.owner_user_id)
     limit 1000
  ), ins as (
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select t.user_id, 'lost_alert',
           'Lost ' || case p.species when 'dog' then 'dog' when 'cat' then 'cat' else 'pet' end || ' near you',
           p.name || coalesce(', ' || nullif(btrim(p.breed), ''), '') || ', was last seen'
             || coalesce(' on ' || nullif(btrim(a.address), ''), ' near you') || '.',
           '/lost/' || a.id, 'lost:' || a.id
      from targets t
    on conflict (user_id, dedupe_key) do nothing
    returning 1
  )
  select count(*) into n from ins;
  return n;
end;
$$;
revoke all on function private.fan_out_lost_alert(uuid) from public, anon, authenticated;

create function public.create_lost_alert(
  p_pet uuid,
  p_lat double precision,
  p_lng double precision,
  p_address text default null,
  p_seen_at timestamptz default null,
  p_description text default null,
  p_radius_m integer default 5000
) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  seen timestamptz := coalesce(p_seen_at, now());
  id uuid;
  notified integer;
  pet_name text;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if not private.owns_pet(p_pet) then
    raise exception 'Pet not found' using errcode = '42501';
  end if;
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'Choose where your pet was last seen' using errcode = '22023';
  end if;
  if p_radius_m not in (2000, 5000, 10000) then
    raise exception 'Choose 2, 5 or 10 km' using errcode = '22023';
  end if;
  if seen > now() + interval '5 minutes' or seen < now() - interval '14 days' then
    raise exception 'When was your pet last seen? It must be in the last 14 days.' using errcode = '22023';
  end if;
  if char_length(coalesce(p_description, '')) > 500 or char_length(coalesce(p_address, '')) > 200 then
    raise exception 'That is too long' using errcode = '22023';
  end if;
  select name into pet_name from public.pets where pets.id = p_pet;
  if exists (select 1 from public.lost_alerts l where l.pet_id = p_pet and l.status = 'active') then
    raise exception '% already has an active alert', pet_name using errcode = 'P0001';
  end if;

  insert into public.lost_alerts (pet_id, last_seen_at, last_seen_point, radius_m, description, address)
  values (p_pet, seen, extensions.st_point(p_lng, p_lat, 4326)::extensions.geography, p_radius_m,
          nullif(btrim(p_description), ''), nullif(btrim(p_address), ''))
  returning lost_alerts.id into id;

  notified := private.fan_out_lost_alert(id);
  return jsonb_build_object('alert_id', id, 'notified', notified);
end;
$$;
revoke all on function public.create_lost_alert(uuid, double precision, double precision, text, timestamptz, text, integer) from public, anon;
grant execute on function public.create_lost_alert(uuid, double precision, double precision, text, timestamptz, text, integer) to authenticated;

-- Active alerts that reach this spot, nearest first. The owner always sees their own.
create function public.lost_alerts_nearby(p_lat double precision default null, p_lng double precision default null, p_limit integer default 20)
returns table (
  alert_id uuid,
  pet_id uuid,
  pet_name text,
  species text,
  breed text,
  colour text,
  photo_path text,
  address text,
  description text,
  last_seen_at timestamptz,
  radius_m integer,
  distance_m integer,
  sightings bigint,
  is_mine boolean
)
language sql stable security definer
set search_path = ''
as $$
  with me as (
    select (select auth.uid()) as id,
           case when p_lat is not null and p_lng is not null
                then extensions.st_point(p_lng, p_lat, 4326)::extensions.geography end as pt
  )
  select a.id, p.id, p.name, p.species, p.breed, p.colour_markings, p.photo_path, a.address, a.description,
         a.last_seen_at, a.radius_m,
         case when me.pt is null then null
              else (round(extensions.st_distance(me.pt, a.last_seen_point) / 100) * 100)::integer end,
         (select count(*) from public.sightings s where s.lost_alert_id = a.id),
         p.owner_user_id = me.id
    from public.lost_alerts a
    join public.pets p on p.id = a.pet_id
    cross join me
   where me.id is not null
     and a.status = 'active'
     and not private.is_blocked_between(p.owner_user_id, me.id)
     and (
       p.owner_user_id = me.id
       or me.pt is null
       or extensions.st_dwithin(me.pt, a.last_seen_point, a.radius_m)
     )
   order by (p.owner_user_id = me.id) desc,
            case when me.pt is null then null else extensions.st_distance(me.pt, a.last_seen_point) end nulls last,
            a.last_seen_at desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;
revoke all on function public.lost_alerts_nearby(double precision, double precision, integer) from public, anon;
grant execute on function public.lost_alerts_nearby(double precision, double precision, integer) to authenticated;

create function public.lost_alert_detail(p_alert uuid, p_lat double precision default null, p_lng double precision default null)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  a public.lost_alerts;
  p public.pets;
  owner_name text;
  mine boolean;
  pt extensions.geography;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into a from public.lost_alerts where id = p_alert;
  if not found then
    raise exception 'Alert not found' using errcode = 'P0002';
  end if;
  select * into p from public.pets where id = a.pet_id;
  mine := p.owner_user_id = me;
  if (a.status <> 'active' and not mine) or private.is_blocked_between(p.owner_user_id, me) then
    raise exception 'Alert not found' using errcode = 'P0002';
  end if;
  if p_lat is not null and p_lng is not null then
    pt := extensions.st_point(p_lng, p_lat, 4326)::extensions.geography;
  end if;
  select coalesce(nullif(btrim(first_name), ''), 'the owner') into owner_name from public.profiles where user_id = p.owner_user_id;
  return jsonb_build_object(
    'alert_id', a.id,
    'status', a.status,
    'pet_id', p.id,
    'pet_name', p.name,
    'species', p.species,
    'breed', p.breed,
    'colour', p.colour_markings,
    'photo_path', p.photo_path,
    'address', a.address,
    'description', a.description,
    'last_seen_at', a.last_seen_at,
    'radius_m', a.radius_m,
    'owner_name', owner_name,
    'is_mine', mine,
    'distance_m', case when pt is null then null
                       else (round(extensions.st_distance(pt, a.last_seen_point) / 100) * 100)::integer end,
    'sighting_count', (select count(*) from public.sightings s where s.lost_alert_id = a.id),
    -- The owner sees every sighting with its place; everyone else sees only their own.
    'sightings', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', s.id, 'note', s.note, 'seen_at', s.seen_at, 'mine', s.reporter_user_id = me,
               'lat', case when mine then extensions.st_y(s.point::extensions.geometry) end,
               'lng', case when mine then extensions.st_x(s.point::extensions.geometry) end)
             order by s.seen_at desc)
        from public.sightings s
       where s.lost_alert_id = a.id and (mine or s.reporter_user_id = me)
    ), '[]'::jsonb)
  );
end;
$$;
revoke all on function public.lost_alert_detail(uuid, double precision, double precision) from public, anon;
grant execute on function public.lost_alert_detail(uuid, double precision, double precision) to authenticated;

create function public.report_sighting(
  p_alert uuid,
  p_lat double precision,
  p_lng double precision,
  p_note text default null
) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  a public.lost_alerts;
  p public.pets;
  id uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into a from public.lost_alerts where lost_alerts.id = p_alert and status = 'active';
  if not found then
    raise exception 'This alert has been closed' using errcode = 'P0001';
  end if;
  select * into p from public.pets where pets.id = a.pet_id;
  if p.owner_user_id = me then
    raise exception 'This is your own alert' using errcode = '22023';
  end if;
  if private.is_blocked_between(p.owner_user_id, me) then
    raise exception 'Alert not found' using errcode = 'P0002';
  end if;
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'Share where you saw them' using errcode = '22023';
  end if;
  if char_length(coalesce(p_note, '')) > 300 then
    raise exception 'That note is too long' using errcode = '22023';
  end if;
  if (select count(*) from public.sightings s
       where s.lost_alert_id = p_alert and s.reporter_user_id = me and s.created_at > now() - interval '1 day') >= 5 then
    raise exception 'You have already shared several sightings today. Message the owner instead.' using errcode = 'P0001';
  end if;

  insert into public.sightings (lost_alert_id, reporter_user_id, point, note)
  values (p_alert, me, extensions.st_point(p_lng, p_lat, 4326)::extensions.geography, nullif(btrim(p_note), ''))
  returning sightings.id into id;

  perform private.notify(p.owner_user_id, 'lost_alert', 'Someone saw ' || p.name,
    coalesce(nullif(btrim(p_note), ''), 'A sighting was shared near where ' || p.name || ' was last seen.'),
    '/lost/' || p_alert, 'sighting:' || id);
  return id;
end;
$$;
revoke all on function public.report_sighting(uuid, double precision, double precision, text) from public, anon;
grant execute on function public.report_sighting(uuid, double precision, double precision, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Chat. Conversations are made here (both members at once); messages go through send_message.
-- ---------------------------------------------------------------------------
create function public.open_alert_chat(p_alert uuid) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  a public.lost_alerts;
  p public.pets;
  conv uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into a from public.lost_alerts where id = p_alert;
  if not found then
    raise exception 'Alert not found' using errcode = 'P0002';
  end if;
  select * into p from public.pets where id = a.pet_id;
  if p.owner_user_id = me then
    raise exception 'This is your own alert' using errcode = '22023';
  end if;
  if private.is_blocked_between(p.owner_user_id, me) then
    raise exception 'Alert not found' using errcode = 'P0002';
  end if;

  select c.id into conv
    from public.conversations c
    join public.conversation_members m1 on m1.conversation_id = c.id and m1.user_id = me
    join public.conversation_members m2 on m2.conversation_id = c.id and m2.user_id = p.owner_user_id
   where c.context_type = 'lost_alert' and c.context_id = p_alert
   limit 1;
  if conv is not null then
    return conv;
  end if;
  if a.status <> 'active' then
    raise exception 'This alert has been closed' using errcode = 'P0001';
  end if;

  insert into public.conversations (context_type, context_id) values ('lost_alert', p_alert) returning id into conv;
  insert into public.conversation_members (conversation_id, user_id) values (conv, me), (conv, p.owner_user_id);
  return conv;
end;
$$;
revoke all on function public.open_alert_chat(uuid) from public, anon;
grant execute on function public.open_alert_chat(uuid) to authenticated;

create function public.send_message(
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
  return id;
end;
$$;
revoke all on function public.send_message(uuid, text, double precision, double precision) from public, anon;
grant execute on function public.send_message(uuid, text, double precision, double precision) to authenticated;

create function public.conversation_messages(p_conversation uuid, p_limit integer default 100)
returns table (message_id uuid, mine boolean, body text, lat double precision, lng double precision, created_at timestamptz)
language sql stable security definer
set search_path = ''
as $$
  select * from (
    select m.id, m.sender_user_id = (select auth.uid()), m.body,
           extensions.st_y(m.location::extensions.geometry), extensions.st_x(m.location::extensions.geometry),
           m.created_at
      from public.messages m
     where m.conversation_id = p_conversation and private.in_conversation(p_conversation)
     order by m.created_at desc
     limit least(greatest(coalesce(p_limit, 100), 1), 200)
  ) last_messages
  order by created_at;
$$;
revoke all on function public.conversation_messages(uuid, integer) from public, anon;
grant execute on function public.conversation_messages(uuid, integer) to authenticated;

create function public.mark_conversation_read(p_conversation uuid) returns void
language sql security definer
set search_path = ''
as $$
  update public.conversation_members set last_read_at = now()
   where conversation_id = p_conversation and user_id = (select auth.uid());
$$;
revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

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
  unread integer
)
language sql stable security definer
set search_path = ''
as $$
  select c.id, c.context_type, c.context_id,
         case c.context_type
           when 'lost_alert' then 'Lost alert · ' || coalesce((
             select p.name from public.lost_alerts a join public.pets p on p.id = a.pet_id where a.id = c.context_id), 'a pet')
           else initcap(replace(c.context_type, '_', ' '))
         end,
         o.user_id,
         coalesce(nullif(btrim(op.first_name), ''), 'Someone'),
         case when lm.location is not null and lm.body is null then 'Shared a location' else lm.body end,
         coalesce(lm.created_at, c.created_at),
         (select count(*)::integer from public.messages m
           where m.conversation_id = c.id and m.sender_user_id <> (select auth.uid())
             and (me.last_read_at is null or m.created_at > me.last_read_at))
    from public.conversations c
    join public.conversation_members me on me.conversation_id = c.id and me.user_id = (select auth.uid())
    join public.conversation_members o on o.conversation_id = c.id and o.user_id <> (select auth.uid())
    join public.profiles op on op.user_id = o.user_id
    left join lateral (
      select m.body, m.location, m.created_at from public.messages m
       where m.conversation_id = c.id order by m.created_at desc limit 1
    ) lm on true
   where not private.is_blocked_between(o.user_id, (select auth.uid()))
   order by coalesce(lm.created_at, c.created_at) desc;
$$;
revoke all on function public.my_conversations() from public, anon;
grant execute on function public.my_conversations() to authenticated;

-- Who the other person in a conversation is, and what it is about (for the chat header).
create function public.conversation_header(p_conversation uuid) returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object(
           'conversation_id', c.conversation_id, 'context_type', c.context_type, 'context_id', c.context_id,
           'context_label', c.context_label, 'other_name', c.other_name, 'other_user_id', c.other_user_id)
    from public.my_conversations() c
   where c.conversation_id = p_conversation;
$$;
revoke all on function public.conversation_header(uuid) from public, anon;
grant execute on function public.conversation_header(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Reports (anonymous to the reported person) and blocking
-- ---------------------------------------------------------------------------
create function public.file_report(p_target_type text, p_target_id uuid, p_reason text, p_block boolean default false)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  label text;
  target_user uuid;
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
    return; -- already reported: nothing more to do, and nothing to tell
  end if;

  if p_target_type = 'post' then
    if not private.can_see_post(p_target_id) then
      raise exception 'We could not find that post' using errcode = 'P0002';
    end if;
    select author_user_id into target_user from public.posts where id = p_target_id;
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
revoke all on function public.file_report(text, uuid, text, boolean) from public, anon;
grant execute on function public.file_report(text, uuid, text, boolean) to authenticated;

-- Realtime for likes is not needed; chat and alerts are already published.
