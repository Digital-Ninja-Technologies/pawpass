-- Launch readiness (milestone 8): the PRD's success metrics, and the few app events needed for the one number that
-- cannot be worked out from the data itself (monthly active owners).
--
-- Events carry no personal details: a fixed list of names, the signed in user's id (removed with the account), and a
-- time. Nothing from a screen, no text typed by a person, no location.

create table public.analytics_events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete cascade,
  name text not null check (name in (
    'app_open', 'booking_started', 'checkout_started', 'share_started', 'partner_started', 'help_opened'
  )),
  created_at timestamptz not null default now()
);
create index on public.analytics_events (name, created_at);
create index on public.analytics_events (user_id, created_at);
alter table public.analytics_events enable row level security;
-- No policies: nobody reads or writes the table directly. track_event writes it and admin_launch_metrics counts it.
revoke all on public.analytics_events from anon, authenticated;

-- Records one event for the signed in user. Unknown names are ignored, and a runaway app cannot flood the table.
create function public.track_event(p_name text) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then
    return;
  end if;
  if p_name not in ('app_open', 'booking_started', 'checkout_started', 'share_started', 'partner_started', 'help_opened') then
    return;
  end if;
  if (select count(*) from public.analytics_events where user_id = me and created_at > now() - interval '1 hour') >= 120 then
    return;
  end if;
  -- One app_open per person per 30 minutes is plenty to tell whether they used the app.
  if p_name = 'app_open' and exists (
    select 1 from public.analytics_events
     where user_id = me and name = 'app_open' and created_at > now() - interval '30 minutes') then
    return;
  end if;
  insert into public.analytics_events (user_id, name) values (me, p_name);
end;
$$;
revoke all on function public.track_event(text) from public, anon;
grant execute on function public.track_event(text) to authenticated;

-- The PRD's twelve month targets, with where we are now. Any staff member can read it.
create function public.admin_launch_metrics() returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  me_month date := date_trunc('month', now() at time zone 'Africa/Lagos')::date;
  owners integer;
  active integer;
  due_total integer;
  due_acted integer;
  found integer;
  reported integer;
begin
  if not private.is_staff() then
    raise exception 'You do not have permission to do this' using errcode = '42501';
  end if;

  select count(*) into owners from public.profiles where onboarded_at is not null;
  select count(distinct e.user_id) into active
    from public.analytics_events e
   where e.name = 'app_open' and e.created_at > now() - interval '30 days';

  -- Reminders that fell due between 97 and 7 days ago: how many were done within 7 days of their due date.
  select count(*), count(*) filter (where status = 'done' and updated_at <= (due_on + 8)::timestamptz)
    into due_total, due_acted
    from public.reminders
   where due_on <= current_date - 7 and due_on > current_date - 97;

  -- Lost pet reports from the last 90 days that are over (found or closed), and how many were found.
  select count(*) filter (where status = 'found'), count(*) filter (where status in ('found', 'closed'))
    into found, reported
    from public.lost_alerts
   where created_at > now() - interval '90 days';

  return jsonb_build_object(
    'pets_with_record', jsonb_build_object(
      'value', (select count(distinct pet_id) from public.health_records), 'target', 20000),
    'monthly_active_owners', jsonb_build_object(
      'value', active, 'of', owners, 'pct', case when owners = 0 then 0 else round(active * 100.0 / owners, 1) end, 'target_pct', 40),
    'reminders_acted_7d', jsonb_build_object(
      'value', due_acted, 'of', due_total, 'pct', case when due_total = 0 then 0 else round(due_acted * 100.0 / due_total, 1) end, 'target_pct', 60),
    'completed_bookings_month', jsonb_build_object(
      'value', (select count(*) from public.bookings
                 where status = 'completed' and (updated_at at time zone 'Africa/Lagos')::date >= me_month), 'target', 3000),
    'verified_providers', jsonb_build_object(
      'value', (select count(*) from public.partner_accounts where status = 'approved' and type in ('vet', 'service')), 'target', 300),
    'verified_breeders_shelters', jsonb_build_object(
      'value', (select count(*) from public.partner_accounts where status = 'approved' and type in ('breeder', 'shelter')), 'target', 50),
    'lost_found_rate', jsonb_build_object(
      'value', found, 'of', reported, 'pct', case when reported = 0 then 0 else round(found * 100.0 / reported, 1) end, 'target_pct', 35)
  );
end;
$$;
revoke all on function public.admin_launch_metrics() from public, anon;
grant execute on function public.admin_launch_metrics() to authenticated;
