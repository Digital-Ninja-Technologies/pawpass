-- Launch metrics tests (milestone 8): events are private and limited, and the PRD numbers add up.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/metrics.test.sql
-- Needs seed.sql. Runs in one transaction that is rolled back. Prints "Metrics tests passed" on success.

\set QUIET on
\set tolu 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set kemi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); end $$; set local role authenticated;'
\set admin 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000007'', true); end $$; set local role authenticated;'
\set anon 'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
\set server 'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$;'

begin;

create schema test_helpers;
grant usage on schema test_helpers to anon, authenticated, service_role;
create function test_helpers.state(q text) returns text
language plpgsql as $$
begin
  execute q;
  return 'ok';
exception when others then
  return sqlstate;
end;
$$;
grant execute on all functions in schema test_helpers to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
:tolu
select public.track_event('app_open');
select public.track_event('app_open');
select public.track_event('booking_started');
select public.track_event('not_an_event');
do $$ begin
  assert test_helpers.state($q$ select count(*) from public.analytics_events $q$) = '42501', 'nobody reads events directly';
  assert test_helpers.state($q$ insert into public.analytics_events (name) values ('app_open') $q$) = '42501', 'nor writes them directly';
end $$;
:server
do $$ begin
  assert (select count(*) from public.analytics_events where name = 'app_open') = 1, 'a second app_open within 30 minutes is not counted';
  assert (select count(*) from public.analytics_events where name = 'booking_started') = 1, 'a funnel event is recorded';
  assert (select count(*) from public.analytics_events where user_id = 'a0000000-0000-0000-0000-000000000001') = 2, 'unknown names are ignored';
end $$;

:anon
do $$ begin
  assert test_helpers.state($q$ select public.track_event('app_open') $q$) = '42501', 'signed out callers cannot record events';
end $$;

-- A runaway app cannot flood the table.
:server
insert into public.analytics_events (user_id, name)
select 'a0000000-0000-0000-0000-000000000005', 'help_opened' from generate_series(1, 120);
:kemi
select public.track_event('help_opened');
:server
do $$ begin
  assert (select count(*) from public.analytics_events where user_id = 'a0000000-0000-0000-0000-000000000005') = 120, 'over 120 events an hour are dropped';
end $$;

-- Deleting the account deletes its events.
delete from public.analytics_events where user_id = 'a0000000-0000-0000-0000-000000000005';

-- ---------------------------------------------------------------------------
-- The PRD numbers
-- ---------------------------------------------------------------------------
:tolu
do $$ begin
  assert test_helpers.state($q$ select public.admin_launch_metrics() $q$) = '42501', 'owners cannot read the company metrics';
end $$;

:server
-- Active owners: Tolu opened the app (above); make Chidi active too, 40 days ago (not counted).
insert into public.analytics_events (user_id, name, created_at) values
  ('a0000000-0000-0000-0000-000000000003', 'app_open', now() - interval '40 days'),
  ('a0000000-0000-0000-0000-000000000005', 'app_open', now() - interval '2 days');
-- Reminders: two fell due 20 days ago; one done on time, one done late. One due 3 days ago does not count yet.
insert into public.reminders (pet_id, due_on, status, updated_at) values
  ('c0000000-0000-0000-0000-000000000001', current_date - 20, 'done', (current_date - 18)::timestamptz),
  ('c0000000-0000-0000-0000-000000000001', current_date - 21, 'done', (current_date - 5)::timestamptz),
  ('c0000000-0000-0000-0000-000000000001', current_date - 3, 'scheduled', now());
-- Lost pets: one found, one closed, one still active.
insert into public.lost_alerts (pet_id, last_seen_point, status) values
  ('c0000000-0000-0000-0000-000000000003', extensions.st_point(3.34, 6.59, 4326)::extensions.geography, 'found'),
  ('c0000000-0000-0000-0000-000000000004', extensions.st_point(3.35, 6.50, 4326)::extensions.geography, 'closed'),
  ('c0000000-0000-0000-0000-000000000005', extensions.st_point(3.35, 6.50, 4326)::extensions.geography, 'active');

:admin
do $$
declare m jsonb := public.admin_launch_metrics();
begin
  assert (m #>> '{pets_with_record,target}')::int = 20000, 'the target is the PRD one';
  assert (m #>> '{pets_with_record,value}')::int >= 1, 'pets with a record are counted';
  assert (m #>> '{monthly_active_owners,value}')::int = 2, 'Tolu and Kemi opened the app in 30 days; Chidi did not';
  assert (m #>> '{monthly_active_owners,target_pct}')::int = 40, 'with its target';
  assert (m #>> '{reminders_acted_7d,of}')::int >= 2, 'reminders due a week or more ago are counted';
  assert (m #>> '{reminders_acted_7d,value}')::int >= 1, 'one was done on time';
  assert (m #>> '{reminders_acted_7d,value}')::int < (m #>> '{reminders_acted_7d,of}')::int, 'a late one is not counted as acted on';
  assert (m #>> '{verified_providers,value}')::int = 2, 'the two approved vet clinics';
  assert (m #>> '{verified_breeders_shelters,value}')::int = 2, 'one breeder and one shelter are approved';
  assert (m #>> '{lost_found_rate,value}')::int = 1 and (m #>> '{lost_found_rate,of}')::int = 2, 'one of two finished lost reports was found';
  assert (m #>> '{lost_found_rate,pct}')::numeric = 50.0, 'half';
end $$;

reset role;
rollback;
\echo Metrics tests passed
