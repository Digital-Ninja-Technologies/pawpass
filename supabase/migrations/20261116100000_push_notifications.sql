-- Push notifications.
--
-- A phone registers its push token (register_device). A scheduled job (send-push) claims notifications that are
-- ready, sends them through Firebase Cloud Messaging, and says how each went (like email reminders and refunds).
--
-- What is pushed: every in-app notification except likes (too many) and, for vaccine and treatment reminders, only
-- for people who chose "push" and only between 8am and 8pm Lagos time. Nothing older than a day. A notification is
-- pushed to a device only if the device was registered before it was made (a new phone never gets old news).

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null unique check (char_length(token) between 20 and 4096),
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  disabled_at timestamptz
);
create index on public.device_tokens (user_id) where disabled_at is null;
alter table public.device_tokens enable row level security;
-- No policies: nobody reads or writes the table directly. The functions below are the only way in.
revoke all on public.device_tokens from anon, authenticated;

alter table public.notifications
  add column pushed_at timestamptz,
  add column push_claimed_at timestamptz,
  add column push_attempts integer not null default 0;
create index on public.notifications (created_at) where pushed_at is null;

-- ---------------------------------------------------------------------------
-- The phone registers itself, and removes itself when the person signs out.
-- ---------------------------------------------------------------------------
create function public.register_device(p_token text, p_platform text) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  t text := btrim(coalesce(p_token, ''));
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if char_length(t) < 20 or char_length(t) > 4096 then
    raise exception 'That is not a device token' using errcode = '22023';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'Unknown platform' using errcode = '22023';
  end if;
  if exists (select 1 from public.profiles pr where pr.user_id = me and pr.deleted_at is not null) then
    raise exception 'This account has been deleted' using errcode = '42501';
  end if;

  -- A phone belongs to whoever signed in last: the token moves to them (and starts counting from now).
  insert into public.device_tokens (user_id, token, platform)
  values (me, t, p_platform)
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        last_seen_at = now(),
        disabled_at = null,
        created_at = case when public.device_tokens.user_id = excluded.user_id
                          then public.device_tokens.created_at else now() end;

  -- At most ten phones per person: the least recently seen go first.
  delete from public.device_tokens d
   where d.user_id = me
     and d.id in (select x.id from public.device_tokens x where x.user_id = me
                   order by x.last_seen_at desc offset 10);
end;
$$;
revoke all on function public.register_device(text, text) from public, anon;
grant execute on function public.register_device(text, text) to authenticated;

create function public.unregister_device(p_token text) returns void
language sql security definer
set search_path = ''
as $$
  delete from public.device_tokens
   where token = btrim(coalesce(p_token, '')) and user_id = (select auth.uid());
$$;
revoke all on function public.unregister_device(text) from public, anon;
grant execute on function public.unregister_device(text) to authenticated;

-- ---------------------------------------------------------------------------
-- The job claims what is ready to push. One row per notification per device.
-- ---------------------------------------------------------------------------
create function public.claim_push_messages(p_limit integer default 100, p_now timestamptz default now())
returns table (notification_id uuid, token_id uuid, token text, platform text, title text, body text, link text)
language plpgsql security definer
set search_path = ''
as $$
declare
  lagos_hour integer := extract(hour from p_now at time zone 'Africa/Lagos');
begin
  return query
  with picked as (
    select n.id
      from public.notifications n
      join public.profiles pr on pr.user_id = n.user_id
      left join public.reminders r
        on r.id = case when n.kind = 'reminder_due' and n.dedupe_key like 'reminder:%'
                       then split_part(n.dedupe_key, ':', 2)::uuid end
     where n.pushed_at is null
       and n.created_at > p_now - interval '1 day'
       and n.push_attempts < 3
       and (n.push_claimed_at is null or n.push_claimed_at < p_now - interval '5 minutes')
       and coalesce(n.dedupe_key, '') not like 'like:%'
       and coalesce(n.dedupe_key, '') not like 'clike:%'
       and pr.deleted_at is null
       and pr.suspended_at is null
       and (n.kind <> 'reminder_due'
            or (lagos_hour >= 8 and lagos_hour < 20 and r.status = 'scheduled' and 'push' = any (r.channels)))
       and exists (select 1 from public.device_tokens t
                    where t.user_id = n.user_id and t.disabled_at is null
                      and n.created_at >= t.created_at - interval '1 minute')
     order by n.created_at
     limit greatest(coalesce(p_limit, 100), 1)
     for update of n skip locked
  ),
  claimed as (
    update public.notifications n
       set push_claimed_at = p_now, push_attempts = n.push_attempts + 1
      from picked
     where n.id = picked.id
    returning n.id, n.user_id, n.created_at, n.title, n.body, n.link
  )
  select c.id, t.id, t.token, t.platform, c.title, c.body, c.link
    from claimed c
    join public.device_tokens t
      on t.user_id = c.user_id and t.disabled_at is null
     and c.created_at >= t.created_at - interval '1 minute';
end;
$$;
revoke all on function public.claim_push_messages(integer, timestamptz) from public, anon, authenticated;
grant execute on function public.claim_push_messages(integer, timestamptz) to service_role;

-- Says how a notification went. A failure frees it to be tried again (up to three tries in all). Tokens that
-- Firebase says no longer exist are switched off, so nothing more is sent to them.
create function public.finish_push(p_notification uuid, p_ok boolean, p_dead_tokens uuid[] default '{}')
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.notifications
     set pushed_at = case when p_ok then now() end,
         push_claimed_at = case when p_ok then push_claimed_at end
   where id = p_notification and pushed_at is null;
  if coalesce(cardinality(p_dead_tokens), 0) > 0 then
    update public.device_tokens set disabled_at = now() where id = any (p_dead_tokens);
  end if;
end;
$$;
revoke all on function public.finish_push(uuid, boolean, uuid[]) from public, anon, authenticated;
grant execute on function public.finish_push(uuid, boolean, uuid[]) to service_role;

-- ---------------------------------------------------------------------------
-- Deleting an account also removes its phones.
-- ---------------------------------------------------------------------------
create or replace function public.erase_account(p_user uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  blockers text[];
  pids uuid[];
  pet record;
begin
  if p_user is null or not exists (select 1 from auth.users u where u.id = p_user) then
    raise exception 'Account not found' using errcode = 'P0002';
  end if;
  blockers := private.deletion_blockers(p_user);
  if coalesce(array_length(blockers, 1), 0) > 0 then
    raise exception '%', array_to_string(blockers, ' ') using errcode = 'P0001';
  end if;

  select coalesce(array_agg(a.id), '{}') into pids from public.partner_accounts a where a.owner_user_id = p_user;

  -- What the person posted and who they followed.
  delete from public.posts where author_user_id = p_user;
  delete from public.post_comments where author_user_id = p_user;
  delete from public.post_likes where user_id = p_user;
  delete from public.comment_likes where user_id = p_user;
  delete from public.follows where follower_user_id = p_user;
  delete from public.blocks where user_id = p_user or blocked_user_id = p_user;
  delete from public.notifications where user_id = p_user;
  delete from public.analytics_events where user_id = p_user;
  delete from public.device_tokens where user_id = p_user;

  -- Chats: the other person keeps their half, but nothing this person wrote.
  update public.messages
     set body = 'This message was deleted', attachment_path = null, location = null
   where sender_user_id = p_user;
  update public.direct_requests set status = 'declined', decided_at = now()
   where (requester_user_id = p_user or recipient_user_id = p_user) and status = 'pending';

  -- Support, applications, sightings, tag deliveries: the record stays, the personal words do not.
  update public.support_messages set body = 'This message was deleted' where author_user_id = p_user;
  update public.support_tickets set subject = 'Deleted' where user_id = p_user;
  update public.adoption_applications set answers = '{}'::jsonb where applicant_user_id = p_user;
  update public.sightings set note = null where reporter_user_id = p_user;
  update public.qr_tag_orders set address = '', area = '' where user_id = p_user;

  -- Pets: removed if nothing else depends on them, otherwise emptied of everything about them.
  update public.passport_shares set revoked_at = now()
   where revoked_at is null and pet_id in (select p.id from public.pets p where p.owner_user_id = p_user);
  update public.lost_alerts set status = 'closed'
   where status = 'active' and pet_id in (select p.id from public.pets p where p.owner_user_id = p_user);
  for pet in select p.id from public.pets p where p.owner_user_id = p_user loop
    begin
      delete from public.pets where id = pet.id;
    exception when foreign_key_violation then
      delete from public.health_records where pet_id = pet.id;
      delete from public.follows where pet_id = pet.id;
      update public.pets
         set name = 'Deleted pet', breed = null, date_of_birth = null, colour_markings = null,
             photo_path = null, mother_pet_id = null, father_pet_id = null
       where id = pet.id;
    end;
  end loop;

  -- A business: bank details and documents go, the record stays suspended so settled sales keep their history.
  update public.listings set status = 'removed'
   where partner_account_id = any(pids) and status in ('draft', 'live', 'reserved');
  delete from public.partner_payout_accounts where partner_account_id = any(pids);
  delete from public.partner_documents where partner_account_id = any(pids);
  update public.partner_accounts
     set status = 'suspended', business_name = 'Deleted business', phone = null, address = null, point = null
   where owner_user_id = p_user;

  -- The person.
  update public.profiles
     set first_name = 'Deleted', last_name = 'user', area = null, phone = null, avatar_path = null,
         last_point = null, last_point_at = null, deleted_at = coalesce(deleted_at, now()),
         suspended_at = coalesce(suspended_at, now()),
         suspension_reason = coalesce(suspension_reason, 'Account deleted')
   where user_id = p_user;

  if not exists (select 1 from public.account_deletions d where d.user_id = p_user) then
    insert into public.account_deletions (user_id) values (p_user);
  end if;
end;
$$;
revoke all on function public.erase_account(uuid) from public, anon, authenticated;
grant execute on function public.erase_account(uuid) to service_role;
