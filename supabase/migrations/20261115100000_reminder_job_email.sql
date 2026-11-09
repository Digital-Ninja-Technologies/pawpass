-- Scheduled reminders and email reminders.
--
-- 1. Reminders were only announced when the owner opened the app. A scheduled job now announces them for everyone,
--    using the same rules, so a person who never opens the app is still told.
-- 2. People who chose "email" as a reminder channel (profiles.reminder_channels, copied onto each reminder) are
--    also emailed. Each announcement is emailed at most once, between 8am and 8pm in Lagos, and an announcement
--    older than two days is never emailed (so nothing old is sent in a rush).

alter table public.notifications
  add column emailed_at timestamptz,
  add column email_claimed_at timestamptz,
  add column email_attempts integer not null default 0;
create index on public.notifications (created_at)
  where kind = 'reminder_due' and emailed_at is null;

-- ---------------------------------------------------------------------------
-- One place for the announcing rules. p_user null means everyone.
-- A reminder is announced once per stage: within 7 days, due today or tomorrow, overdue (up to 30 days; older ones
-- stay quiet). Deleted accounts are skipped.
-- ---------------------------------------------------------------------------
create function private.announce_reminders(p_user uuid) returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  today date := (now() at time zone 'Africa/Lagos')::date;
  n integer;
begin
  insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
  select
    s.owner,
    'reminder_due',
    case s.stage
      when 'overdue' then s.label || ' is overdue'
      when 'd1' then s.label || case when s.days = 0 then ' is due today' else ' is due tomorrow' end
      else s.label || ' in ' || s.days || ' days'
    end,
    case s.stage
      when 'overdue' then s.pet || ' was due on ' || to_char(s.due_on, 'FMDD Mon') || '.'
      else 'Book a vet for ' || s.pet || ' before ' || to_char(s.due_on, 'FMDD Mon') || '.'
    end,
    '/schedule',
    'reminder:' || s.id || ':' || s.stage
  from (
    select
      r.id, r.due_on, p.name as pet, p.owner_user_id as owner, (r.due_on - today) as days,
      case when h.type = 'vaccine' and h.name !~* '(booster|vaccine)' then h.name || ' booster'
           else coalesce(h.name, 'Reminder') end as label,
      case
        when r.due_on < today then 'overdue'
        when r.due_on - today <= 1 then 'd1'
        when r.due_on - today <= 7 then 'd7'
      end as stage
    from public.reminders r
    join public.pets p on p.id = r.pet_id
    join public.profiles pr on pr.user_id = p.owner_user_id
    left join public.health_records h on h.id = r.health_record_id
    where r.status = 'scheduled'
      and pr.deleted_at is null
      and (p_user is null or p.owner_user_id = p_user)
      and r.due_on >= today - 30
  ) s
  where s.stage is not null
  on conflict (user_id, dedupe_key) do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function private.announce_reminders(uuid) from public, anon, authenticated;

-- The app still calls this when it opens.
create or replace function public.generate_my_reminder_notifications() returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  return private.announce_reminders(me);
end;
$$;
revoke all on function public.generate_my_reminder_notifications() from public, anon;
grant execute on function public.generate_my_reminder_notifications() to authenticated;

-- The scheduled job calls this (service role only).
create function public.announce_all_reminders() returns integer
language sql security definer
set search_path = ''
as $$
  select private.announce_reminders(null);
$$;
revoke all on function public.announce_all_reminders() from public, anon, authenticated;
grant execute on function public.announce_all_reminders() to service_role;

-- ---------------------------------------------------------------------------
-- Emailing. The job claims announcements, sends them, then says how each one went (like refunds).
-- ---------------------------------------------------------------------------
create function public.claim_reminder_emails(p_limit integer default 50, p_now timestamptz default now())
returns table (notification_id uuid, email text, first_name text, title text, body text)
language plpgsql security definer
set search_path = ''
as $$
declare
  lagos_hour integer := extract(hour from p_now at time zone 'Africa/Lagos');
begin
  -- Quiet hours: nothing is sent before 8am or from 8pm, Lagos time. It is picked up in the morning.
  if lagos_hour < 8 or lagos_hour >= 20 then
    return;
  end if;

  return query
  with picked as (
    select n.id
      from public.notifications n
      join public.reminders r on r.id = split_part(n.dedupe_key, ':', 2)::uuid
      join public.profiles pr on pr.user_id = n.user_id
      join auth.users u on u.id = n.user_id
     where n.kind = 'reminder_due'
       and n.dedupe_key like 'reminder:%'
       and n.emailed_at is null
       and n.created_at > p_now - interval '2 days'
       and n.email_attempts < 3
       and (n.email_claimed_at is null or n.email_claimed_at < p_now - interval '15 minutes')
       and 'email' = any (r.channels)
       and r.status = 'scheduled'
       and pr.deleted_at is null
       and pr.suspended_at is null
       and u.email is not null
     order by n.created_at
     limit greatest(coalesce(p_limit, 50), 1)
     for update of n skip locked
  )
  update public.notifications n
     set email_claimed_at = p_now, email_attempts = n.email_attempts + 1
    from picked
    join public.profiles pr2 on true
    join auth.users u2 on true
   where n.id = picked.id and pr2.user_id = n.user_id and u2.id = n.user_id
  returning n.id, u2.email::text, pr2.first_name, n.title, n.body;
end;
$$;
revoke all on function public.claim_reminder_emails(integer, timestamptz) from public, anon, authenticated;
grant execute on function public.claim_reminder_emails(integer, timestamptz) to service_role;

-- Says how a send went. A failure frees the announcement to be tried again (up to three tries in all).
create function public.finish_reminder_email(p_notification uuid, p_ok boolean) returns void
language sql security definer
set search_path = ''
as $$
  update public.notifications
     set emailed_at = case when p_ok then now() end,
         email_claimed_at = case when p_ok then email_claimed_at end
   where id = p_notification and emailed_at is null;
$$;
revoke all on function public.finish_reminder_email(uuid, boolean) from public, anon, authenticated;
grant execute on function public.finish_reminder_email(uuid, boolean) to service_role;
