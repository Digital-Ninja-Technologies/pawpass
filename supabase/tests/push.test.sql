-- Push notifications: registering phones, what is claimed for pushing (and what never is), retries, dead tokens,
-- and that deleting an account removes its phones.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/push.test.sql
-- Needs seed.sql and migration 20261116100000. Runs in one transaction that is rolled back.
-- Prints "Push tests passed" on success.

\set QUIET on
\set tolu 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set kemi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); end $$; set local role authenticated;'
\set anon 'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
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
create function test_helpers.lagos_at(h integer) returns timestamptz language sql as
$$ select (((now() at time zone 'Africa/Lagos')::date + make_interval(hours => h)) at time zone 'Africa/Lagos') $$;

-- ---------------------------------------------------------------------------
-- Registering
-- ---------------------------------------------------------------------------
:anon
do $$
begin
  assert test_helpers.state($q$ select public.register_device(repeat('a', 40), 'android') $q$) = '42501', 'signed out people cannot register';
  assert test_helpers.state($q$ select * from public.device_tokens $q$) = '42501', 'nor read the table';
end $$;

:tolu
do $$
begin
  assert test_helpers.state($q$ select public.register_device('short', 'android') $q$) = '22023', 'a short token is refused';
  assert test_helpers.state($q$ select public.register_device(repeat('a', 40), 'windows') $q$) = '22023', 'an unknown platform is refused';
  perform public.register_device(repeat('t', 40), 'android');
  perform public.register_device(repeat('t', 40), 'android');
  assert test_helpers.state($q$ select * from public.device_tokens $q$) = '42501', 'the table stays closed to the app';
end $$;
:server
do $$
begin
  assert (select count(*) from public.device_tokens where user_id = 'a0000000-0000-0000-0000-000000000001') = 1, 'registering twice keeps one row';
end $$;

-- A phone belongs to whoever signed in last.
:kemi
do $$
begin
  perform public.register_device(repeat('t', 40), 'android');
end $$;
:server
do $$
begin
  assert (select user_id from public.device_tokens where token = repeat('t', 40)) = 'a0000000-0000-0000-0000-000000000005', 'the token moved to Kemi';
  assert (select count(*) from public.device_tokens) = 1, 'and is still one row';
end $$;

-- Signing out removes only your own phone.
:tolu
do $$
begin
  perform public.unregister_device(repeat('t', 40));
end $$;
:server
do $$
begin
  assert (select count(*) from public.device_tokens) = 1, 'Tolu cannot remove Kemi''s phone';
end $$;
:kemi
do $$
begin
  perform public.unregister_device(repeat('t', 40));
end $$;
:server
do $$
begin
  assert (select count(*) from public.device_tokens) = 0, 'Kemi removes her own';
end $$;

-- At most ten phones: the least recently seen go.
do $$
declare i integer;
begin
  for i in 1..12 loop
    insert into public.device_tokens (user_id, token, platform, last_seen_at)
    values ('a0000000-0000-0000-0000-000000000001', repeat(chr(96 + i), 40), 'ios', now() - make_interval(mins => 100 - i));
  end loop;
end $$;
:tolu
do $$
begin
  perform public.register_device(repeat('z', 40), 'ios');
end $$;
:server
do $$
begin
  assert (select count(*) from public.device_tokens where user_id = 'a0000000-0000-0000-0000-000000000001') = 10, 'ten phones at most';
  assert exists (select 1 from public.device_tokens where token = repeat('z', 40)), 'the new one is kept';
end $$;
delete from public.device_tokens;

-- ---------------------------------------------------------------------------
-- Claiming
-- ---------------------------------------------------------------------------
delete from public.notifications;
delete from public.reminders;
insert into public.device_tokens (user_id, token, platform, created_at) values
  ('a0000000-0000-0000-0000-000000000001', repeat('1', 40), 'android', now() - interval '1 hour'),
  ('a0000000-0000-0000-0000-000000000001', repeat('2', 40), 'ios',     now() - interval '1 hour');

insert into public.notifications (user_id, kind, title, body, link, dedupe_key) values
  ('a0000000-0000-0000-0000-000000000001', 'booking',   'Booking confirmed', 'See you soon', '/bookings', 'b:1'),
  ('a0000000-0000-0000-0000-000000000001', 'community', 'Kemi liked your post', null, '/posts/x', 'like:x:y'),
  ('a0000000-0000-0000-0000-000000000001', 'community', 'Kemi liked your comment', null, '/posts/x', 'clike:x:y'),
  ('a0000000-0000-0000-0000-000000000005', 'booking',   'Booking confirmed', 'No phone', '/bookings', 'b:2');  -- Kemi has no phone

do $$
declare n integer; rows_ integer;
begin
  select count(distinct notification_id), count(*) into n, rows_ from public.claim_push_messages(100, now());
  assert n = 1, 'only the booking is pushed: likes are left out and Kemi has no phone';
  assert rows_ = 2, 'one row for each of Tolu''s two phones';
end $$;

-- Claimed means held; a failed push frees it; a good one closes it.
do $$
declare n integer; nid uuid;
begin
  select id into nid from public.notifications where dedupe_key = 'b:1';
  select count(*) into n from public.claim_push_messages(100, now());
  assert n = 0, 'a claimed notification is not handed out twice';
  perform public.finish_push(nid, false);
  select count(*) into n from public.claim_push_messages(100, now());
  assert n = 2, 'a failed push is tried again';
  perform public.finish_push(nid, true);
  select count(*) into n from public.claim_push_messages(100, now() + interval '10 minutes');
  assert n = 0, 'pushed once, never again';
  assert (select pushed_at is not null from public.notifications where id = nid), 'marked as pushed';
end $$;

-- Dead tokens are switched off and no longer used.
do $$
declare n integer; nid uuid; dead uuid;
begin
  insert into public.notifications (user_id, kind, title, dedupe_key) values ('a0000000-0000-0000-0000-000000000001', 'booking', 'Another', 'b:3') returning id into nid;
  select token_id into dead from public.claim_push_messages(100, now()) where token = repeat('1', 40);
  perform public.finish_push(nid, true, array[dead]);
  assert (select disabled_at is not null from public.device_tokens where token = repeat('1', 40)), 'the dead phone is switched off';
  insert into public.notifications (user_id, kind, title, dedupe_key) values ('a0000000-0000-0000-0000-000000000001', 'booking', 'Third', 'b:4');
  select count(*) into n from public.claim_push_messages(100, now());
  assert n = 1, 'only the live phone is used now';
end $$;

-- Three failures and it stops.
do $$
declare n integer; nid uuid;
begin
  delete from public.notifications;
  insert into public.notifications (user_id, kind, title, dedupe_key) values ('a0000000-0000-0000-0000-000000000001', 'booking', 'Stubborn', 'b:5') returning id into nid;
  for i in 1..3 loop
    perform * from public.claim_push_messages(100, now() + make_interval(mins => 10 * i));
    perform public.finish_push(nid, false);
  end loop;
  select count(*) into n from public.claim_push_messages(100, now() + interval '90 minutes');
  assert n = 0, 'three failures and it stops';
end $$;

-- Old news, new phones, suspended and deleted people.
do $$
declare n integer;
begin
  delete from public.notifications;
  insert into public.notifications (user_id, kind, title, dedupe_key, created_at)
  values ('a0000000-0000-0000-0000-000000000001', 'booking', 'Old', 'old:1', now() - interval '2 days');
  select count(*) into n from public.claim_push_messages(100, now());
  assert n = 0, 'nothing older than a day is pushed';

  -- A phone registered after the notification does not get it.
  insert into public.notifications (user_id, kind, title, dedupe_key, created_at)
  values ('a0000000-0000-0000-0000-000000000001', 'booking', 'Before the phone', 'new:1', now() - interval '3 hours');
  select count(*) into n from public.claim_push_messages(100, now());
  assert n = 0, 'a new phone is not sent old news';

  delete from public.notifications;
  insert into public.notifications (user_id, kind, title, dedupe_key) values ('a0000000-0000-0000-0000-000000000001', 'booking', 'Fresh', 'f:1');
  update public.profiles set suspended_at = now() where user_id = 'a0000000-0000-0000-0000-000000000001';
  select count(*) into n from public.claim_push_messages(100, now());
  assert n = 0, 'a suspended person is not pushed to';
  update public.profiles set suspended_at = null where user_id = 'a0000000-0000-0000-0000-000000000001';
  update public.profiles set deleted_at = now() where user_id = 'a0000000-0000-0000-0000-000000000001';
  select count(*) into n from public.claim_push_messages(100, now());
  assert n = 0, 'nor a deleted one';
  update public.profiles set deleted_at = null where user_id = 'a0000000-0000-0000-0000-000000000001';
end $$;

-- Reminders: only people who chose push, only in the day time, only while still scheduled.
do $$
declare n integer; rid uuid;
begin
  delete from public.notifications;
  insert into public.reminders (pet_id, due_on, channels)
  values ('c0000000-0000-0000-0000-000000000001', (now() at time zone 'Africa/Lagos')::date + 1, array['email'])
  returning id into rid;
  insert into public.notifications (user_id, kind, title, dedupe_key)
  values ('a0000000-0000-0000-0000-000000000001', 'reminder_due', 'Rabies booster is due tomorrow', 'reminder:' || rid || ':d1');

  select count(*) into n from public.claim_push_messages(100, test_helpers.lagos_at(10));
  assert n = 0, 'a reminder that is email only is not pushed';

  update public.reminders set channels = array['push', 'email'] where id = rid;
  select count(*) into n from public.claim_push_messages(100, test_helpers.lagos_at(23));
  assert n = 0, 'no reminder push at 11pm';
  select count(*) into n from public.claim_push_messages(100, test_helpers.lagos_at(7));
  assert n = 0, 'nor before 8am';
  select count(*) into n from public.claim_push_messages(100, test_helpers.lagos_at(10));
  assert n >= 1, 'in the day it is pushed';
  perform public.finish_push((select id from public.notifications where dedupe_key like 'reminder:%'), false);

  update public.reminders set status = 'done' where id = rid;
  select count(*) into n from public.claim_push_messages(100, test_helpers.lagos_at(10) + interval '20 minutes');
  assert n = 0, 'a reminder already done is not pushed';
end $$;

-- A booking at night is pushed straight away (it is not a reminder).
do $$
declare n integer;
begin
  delete from public.notifications;
  insert into public.notifications (user_id, kind, title, dedupe_key) values ('a0000000-0000-0000-0000-000000000001', 'lost_alert', 'A pet is lost nearby', 'l:1');
  select count(*) into n from public.claim_push_messages(100, test_helpers.lagos_at(23));
  assert n >= 1, 'urgent news is pushed at any hour';
end $$;

-- ---------------------------------------------------------------------------
-- Only the server runs the job; deleting an account removes its phones
-- ---------------------------------------------------------------------------
:tolu
do $$
begin
  assert test_helpers.state($q$ select * from public.claim_push_messages() $q$) = '42501', 'a signed in person cannot claim';
  assert test_helpers.state($q$ select public.finish_push(gen_random_uuid(), true) $q$) = '42501', 'nor finish';
end $$;
:server
do $$
begin
  perform public.erase_account('a0000000-0000-0000-0000-000000000006');
  insert into public.device_tokens (user_id, token, platform) values ('a0000000-0000-0000-0000-000000000006', repeat('9', 40), 'ios');
  perform public.erase_account('a0000000-0000-0000-0000-000000000006');
  assert not exists (select 1 from public.device_tokens where user_id = 'a0000000-0000-0000-0000-000000000006'), 'a deleted account keeps no phones';
end $$;

reset role;
rollback;
\echo Push tests passed
