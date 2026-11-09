-- Scheduled reminders and email reminders: everyone is announced, deleted accounts are not, emails go only to people
-- who chose email, once, in the day time, and a failed send is tried again.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/reminders_email.test.sql
-- Needs seed.sql and migration 20261115100000. Runs in one transaction that is rolled back.
-- Prints "Reminder job and email tests passed" on success.

\set QUIET on
\set tolu 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set server 'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$;'

begin;

create schema test_helpers;
grant usage on schema test_helpers to anon, authenticated;
create function test_helpers.state(q text) returns text
language plpgsql as $$
begin
  execute q;
  return 'ok';
exception when others then
  return sqlstate;
end;
$$;
grant execute on all functions in schema test_helpers to anon, authenticated;

-- A fixed clock for the email window: 10am Lagos today, and 11pm Lagos today.
create function test_helpers.lagos_at(h integer) returns timestamptz language sql as
$$ select (((now() at time zone 'Africa/Lagos')::date + make_interval(hours => h)) at time zone 'Africa/Lagos') $$;

-- Start clean: only the reminders this test makes.
:server
delete from public.notifications where kind = 'reminder_due';
delete from public.reminders;
insert into public.reminders (pet_id, due_on, channels) values
  ('c0000000-0000-0000-0000-000000000001', (now() at time zone 'Africa/Lagos')::date + 1,  array['push', 'email']),  -- Tolu, tomorrow, email
  ('c0000000-0000-0000-0000-000000000001', (now() at time zone 'Africa/Lagos')::date + 20, array['push', 'email']),  -- too far off: not announced
  ('c0000000-0000-0000-0000-000000000001', (now() at time zone 'Africa/Lagos')::date - 90, array['push', 'email']),  -- long overdue: quiet
  ('c0000000-0000-0000-0000-000000000005', (now() at time zone 'Africa/Lagos')::date + 3,  array['push']);          -- Kemi, push only

-- ---------------------------------------------------------------------------
-- Announcing for everyone
-- ---------------------------------------------------------------------------
do $$
begin
  assert public.announce_all_reminders() = 2, 'Tolu and Kemi are both announced, nothing else';
  assert (select count(*) from public.notifications where kind = 'reminder_due') = 2, 'two announcements';
  assert public.announce_all_reminders() = 0, 'running again announces nothing new';
  assert exists (select 1 from public.notifications where user_id = 'a0000000-0000-0000-0000-000000000001' and title like '%tomorrow%'), 'Tolu: due tomorrow';
  assert exists (select 1 from public.notifications where user_id = 'a0000000-0000-0000-0000-000000000005' and title like '% in 3 days'), 'Kemi: in 3 days';
end $$;

-- Only the service role may run the job.
:tolu
do $$
begin
  assert test_helpers.state($q$ select public.announce_all_reminders() $q$) = '42501', 'a signed in person cannot run the job';
  assert test_helpers.state($q$ select * from public.claim_reminder_emails() $q$) = '42501', 'nor claim emails';
  assert test_helpers.state($q$ select public.generate_my_reminder_notifications() $q$) = 'ok', 'but the app call still works';
end $$;
:server

-- ---------------------------------------------------------------------------
-- Emails
-- ---------------------------------------------------------------------------
do $$
declare got record; n integer;
begin
  -- At night nothing is claimed.
  select count(*) into n from public.claim_reminder_emails(50, test_helpers.lagos_at(23));
  assert n = 0, 'nothing is sent at 11pm';
  select count(*) into n from public.claim_reminder_emails(50, test_helpers.lagos_at(7));
  assert n = 0, 'or before 8am';

  -- In the day, only Tolu (chose email) is claimed; Kemi chose push only.
  select count(*) into n from public.claim_reminder_emails(50, test_helpers.lagos_at(10));
  assert n = 1, 'one email: Tolu';
  select * into got from public.notifications where kind = 'reminder_due' and user_id = 'a0000000-0000-0000-0000-000000000005';
  assert got.email_attempts = 0 and got.emailed_at is null, 'Kemi is not emailed';

  -- Claimed means held: a second run in the same minutes does not hand it out again.
  select count(*) into n from public.claim_reminder_emails(50, test_helpers.lagos_at(10));
  assert n = 0, 'a claimed email is not handed out twice';

  -- A failed send frees it; a good one closes it for ever.
  perform public.finish_reminder_email((select id from public.notifications where kind = 'reminder_due' and user_id = 'a0000000-0000-0000-0000-000000000001'), false);
  select count(*) into n from public.claim_reminder_emails(50, test_helpers.lagos_at(10));
  assert n = 1, 'a failed send is tried again';
  select * into got from public.claim_reminder_emails(50, test_helpers.lagos_at(10) + interval '5 minutes') limit 1;
  assert got is null, 'still held while the second try is out';
  perform public.finish_reminder_email((select id from public.notifications where kind = 'reminder_due' and user_id = 'a0000000-0000-0000-0000-000000000001'), true);
  select count(*) into n from public.claim_reminder_emails(50, test_helpers.lagos_at(12));
  assert n = 0, 'sent once, never again';
  assert (select emailed_at is not null from public.notifications where kind = 'reminder_due' and user_id = 'a0000000-0000-0000-0000-000000000001'), 'it is marked as emailed';
end $$;

-- The row handed out has what the email needs, and no more.
do $$
declare got record;
begin
  delete from public.notifications where kind = 'reminder_due';
  perform public.announce_all_reminders();
  select * into got from public.claim_reminder_emails(50, test_helpers.lagos_at(10));
  assert got.email = 'tolu@example.com' and got.first_name = 'Tolu' and got.title like '%tomorrow%' and got.body like 'Book a vet for Bingo%', 'the email row is complete';
end $$;

-- Three failed tries and it is dropped (no endless retrying).
do $$
declare id uuid; n integer;
begin
  delete from public.notifications where kind = 'reminder_due';
  perform public.announce_all_reminders();
  select n2.id into id from public.notifications n2 where n2.kind = 'reminder_due' and n2.user_id = 'a0000000-0000-0000-0000-000000000001';
  for i in 1..3 loop
    perform * from public.claim_reminder_emails(50, test_helpers.lagos_at(10));
    perform public.finish_reminder_email(id, false);
  end loop;
  select count(*) into n from public.claim_reminder_emails(50, test_helpers.lagos_at(10));
  assert n = 0, 'three failures and it stops';
end $$;

-- Opting out of email, being deleted or suspended, and old announcements are all respected.
do $$
declare n integer;
begin
  delete from public.notifications where kind = 'reminder_due';
  perform public.announce_all_reminders();
  update public.reminders set channels = array['push'] where pet_id = 'c0000000-0000-0000-0000-000000000001';
  select count(*) into n from public.claim_reminder_emails(50, test_helpers.lagos_at(10));
  assert n = 0, 'a reminder without the email channel is not emailed';
  update public.reminders set channels = array['push', 'email'] where pet_id = 'c0000000-0000-0000-0000-000000000001';

  update public.profiles set suspended_at = now() where user_id = 'a0000000-0000-0000-0000-000000000001';
  select count(*) into n from public.claim_reminder_emails(50, test_helpers.lagos_at(10));
  assert n = 0, 'a suspended person is not emailed';
  update public.profiles set suspended_at = null where user_id = 'a0000000-0000-0000-0000-000000000001';

  update public.notifications set created_at = now() - interval '3 days';
  select count(*) into n from public.claim_reminder_emails(50, test_helpers.lagos_at(10));
  assert n = 0, 'an announcement older than two days is not emailed';

  update public.profiles set deleted_at = now() where user_id = 'a0000000-0000-0000-0000-000000000005';
  delete from public.notifications where kind = 'reminder_due';
  assert public.announce_all_reminders() = 1, 'a deleted account is not announced to';
end $$;

reset role;
rollback;
\echo Reminder job and email tests passed
