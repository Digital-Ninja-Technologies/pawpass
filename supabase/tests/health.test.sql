-- Health tests (milestone 2): reminders from records, mark done, notifications, share links, emergency vets.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/health.test.sql
-- Needs seed.sql. Runs in one transaction that is rolled back. Prints "Health tests passed" on success.

\set QUIET on
\set tolu 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set bola 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000006'', true); end $$; set local role authenticated;'
\set anon 'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
\set server 'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$;'

begin;

create schema test_helpers;
grant usage on schema test_helpers to anon, authenticated;
-- True when the statement fails (with the given SQLSTATE when one is passed).
create function test_helpers.fails(q text, state text default null) returns boolean
language plpgsql as $$
begin
  execute q;
  return false;
exception when others then
  return state is null or sqlstate = state;
end;
$$;
create function test_helpers.today() returns date language sql as $$ select (now() at time zone 'Africa/Lagos')::date $$;
grant execute on all functions in schema test_helpers to anon, authenticated;

-- Bingo is c...01, Mimi c...02. Tolu already has a rabies reminder and a DHPP reminder from the seed.

-- ---------------------------------------------------------------------------
-- Reminders follow records
-- ---------------------------------------------------------------------------
:tolu
do $$
declare bingo uuid := 'c0000000-0000-0000-0000-000000000001'; rid uuid;
begin
  assert (select count(*) from public.reminders where pet_id = bingo) = 2, 'seeded: rabies and DHPP reminders';

  -- A new record with a next due date gets a reminder using the person's channels.
  insert into public.health_records (pet_id, type, name, given_on, next_due_on, added_by_user_id)
  values (bingo, 'treatment', 'Tick & flea treatment', '2026-10-01', '2026-11-01', 'a0000000-0000-0000-0000-000000000001')
  returning id into rid;
  assert (select count(*) from public.reminders where health_record_id = rid) = 1, 'a reminder is made';
  assert (select channels from public.reminders where health_record_id = rid) = array['push', 'whatsapp'], 'with the owner channels';
  assert (select count(*) from public.reminders where pet_id = bingo) = 3, 'now three';

  -- Moving the date moves the reminder, it does not add one.
  update public.health_records set next_due_on = '2026-12-01' where id = rid;
  assert (select due_on from public.reminders where health_record_id = rid) = '2026-12-01', 'reminder moves with the record';
  assert (select count(*) from public.reminders where health_record_id = rid) = 1, 'still one';

  -- Clearing the date removes the open reminder.
  update public.health_records set next_due_on = null where id = rid;
  assert (select count(*) from public.reminders where health_record_id = rid) = 0, 'no date, no reminder';

  -- A record with no due date (a weight) never gets one.
  insert into public.health_records (pet_id, type, name, given_on, value, added_by_user_id)
  values (bingo, 'weight', 'Weight', '2026-11-01', '42', 'a0000000-0000-0000-0000-000000000001');
  assert (select count(*) from public.reminders where pet_id = bingo) = 2, 'weight adds none';
end $$;

-- Turning reminders off clears the open ones, and turning them on again rebuilds them.
:tolu
do $$
declare bingo uuid := 'c0000000-0000-0000-0000-000000000001';
begin
  update public.profiles set reminder_channels = array[]::text[] where user_id = 'a0000000-0000-0000-0000-000000000001';
  assert (select count(*) from public.reminders where pet_id = bingo) = 0, 'reminders off: none open';
  insert into public.health_records (pet_id, type, name, given_on, next_due_on, added_by_user_id)
  values (bingo, 'vaccine', 'Leptospirosis', '2026-10-01', '2027-10-01', 'a0000000-0000-0000-0000-000000000001');
  assert (select count(*) from public.reminders where pet_id = bingo) = 0, 'and new records add none';

  update public.profiles set reminder_channels = array['email'] where user_id = 'a0000000-0000-0000-0000-000000000001';
  assert (select count(*) from public.reminders where pet_id = bingo) = 3, 'back on: rebuilt from every record with a due date';
  assert (select bool_and(channels = array['email']) from public.reminders where pet_id = bingo), 'with the new channels';
  assert test_helpers.fails($q$ update public.profiles set reminder_channels = array['pigeon'] where user_id = 'a0000000-0000-0000-0000-000000000001' $q$, '23514'),
    'unknown channels are refused';
  update public.profiles set reminder_channels = array['push', 'whatsapp'] where user_id = 'a0000000-0000-0000-0000-000000000001';
end $$;

-- A vet adding a record through a live share still creates the owner's reminder (the trigger runs as the owner of the table).
:server
insert into public.passport_shares (pet_id, partner_account_id, token_hash, scopes, expires_at)
values ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'hash-vet-write', array['health', 'write'], now() + interval '1 hour');
set local role authenticated;
do $$ begin perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000002', true); end $$;
do $$
declare before_n int; vet uuid := 'b0000000-0000-0000-0000-000000000001';
begin
  select count(*) into before_n from public.reminders where pet_id = 'c0000000-0000-0000-0000-000000000001';
  insert into public.health_records (pet_id, type, name, given_on, next_due_on, given_by_partner_id, added_by_user_id)
  values ('c0000000-0000-0000-0000-000000000001', 'vaccine', 'Kennel cough', '2026-11-05', '2027-11-05', vet, 'a0000000-0000-0000-0000-000000000002');
end $$;
:server
do $$ begin
  assert (select count(*) from public.reminders where pet_id = 'c0000000-0000-0000-0000-000000000001' and due_on = '2027-11-05') = 1,
    'vet added record makes the owner reminder';
end $$;
delete from public.health_records where name = 'Kennel cough';
delete from public.passport_shares where token_hash = 'hash-vet-write';

-- ---------------------------------------------------------------------------
-- Mark done: records the dose and schedules the next one with the same gap
-- ---------------------------------------------------------------------------
:tolu
do $$
declare rem uuid; fresh public.health_records;
begin
  select r.id into rem from public.reminders r join public.health_records h on h.id = r.health_record_id
   where h.name = 'Rabies booster';
  assert test_helpers.fails(format($q$ select public.complete_reminder(%L, current_date + 3) $q$, rem), '22023'), 'cannot be dated in the future';

  fresh := public.complete_reminder(rem, test_helpers.today());
  assert fresh.name = 'Rabies booster' and fresh.type = 'vaccine', 'the same treatment is recorded';
  assert fresh.given_on = test_helpers.today(), 'given today';
  assert fresh.next_due_on = (test_helpers.today() + interval '12 months')::date, 'yearly stays yearly';
  assert fresh.added_by_user_id = 'a0000000-0000-0000-0000-000000000001' and fresh.verified_at is null, 'owner added, never verified';
  assert (select status from public.reminders where id = rem) = 'done', 'the old reminder is done';
  assert (select count(*) from public.reminders where health_record_id = fresh.id and status = 'scheduled') = 1, 'the next one is scheduled';
  assert test_helpers.fails(format($q$ select public.complete_reminder(%L) $q$, rem), '22023'), 'cannot be done twice';
end $$;

:bola
do $$
declare rem uuid;
begin
  assert test_helpers.fails($q$ select public.complete_reminder('00000000-0000-0000-0000-000000000000') $q$, '42501'), 'unknown reminder';
end $$;

:server
do $$
declare rem uuid;
begin
  select r.id into rem from public.reminders r join public.health_records h on h.id = r.health_record_id where h.name = 'DHPP vaccine';
  perform set_config('test.dhpp_reminder', rem::text, true);
end $$;
:bola
do $$ begin
  assert test_helpers.fails(format($q$ select public.complete_reminder(%L) $q$, current_setting('test.dhpp_reminder')), '42501'),
    'someone else cannot complete my reminder';
end $$;

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------
:server
-- Pin the dates: DHPP due in 7 days, a deworming due tomorrow, a flea treatment overdue.
update public.health_records set next_due_on = test_helpers.today() + 7 where name = 'DHPP vaccine';
insert into public.health_records (pet_id, type, name, given_on, next_due_on, added_by_user_id) values
  ('c0000000-0000-0000-0000-000000000001', 'deworming', 'Deworming', test_helpers.today() - 89, test_helpers.today() + 1, 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000002', 'treatment', 'Tick & flea treatment', test_helpers.today() - 40, test_helpers.today() - 10, 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000001', 'vaccine', 'Far off', test_helpers.today(), test_helpers.today() + 200, 'a0000000-0000-0000-0000-000000000001');

:tolu
do $$
declare n int;
begin
  n := public.generate_my_reminder_notifications();
  assert n = 3, 'week, tomorrow and overdue are announced, far off is not (' || n || ')';
  assert (select count(*) from public.notifications where title = 'DHPP vaccine in 7 days' and body like 'Book a vet for Bingo before %') = 1, 'week notice';
  assert (select count(*) from public.notifications where title = 'Deworming is due tomorrow') = 1, 'tomorrow notice';
  assert (select body from public.notifications where title = 'Tick & flea treatment is overdue') like 'Mimi was due on %', 'overdue notice names the pet';
  assert (select bool_and(link = '/schedule' and read_at is null) from public.notifications where kind = 'reminder_due'), 'link and unread';
  assert (select count(*) from public.notifications where kind = 'record_verified' and body = 'Paws & Claws Vet Clinic verified Bingo''s DHPP vaccine.') = 1,
    'the seeded verified DHPP record was announced when it was created';

  assert public.generate_my_reminder_notifications() = 0, 'calling again announces nothing twice';

  update public.notifications set read_at = now() where title = 'Deworming is due tomorrow';
  assert (select count(*) from public.notifications where read_at is not null) = 1, 'can mark one read';
  assert test_helpers.fails($q$ update public.notifications set title = 'hacked' $q$), 'cannot change the text';
  assert test_helpers.fails($q$ insert into public.notifications (user_id, kind, title) values ('a0000000-0000-0000-0000-000000000001', 'reminder_due', 'fake') $q$),
    'cannot write notifications from the client';
  assert test_helpers.fails($q$ delete from public.notifications $q$), 'cannot delete them either';
end $$;

:bola
do $$ begin
  assert (select count(*) from public.notifications) = 0, 'other people cannot read them';
  assert public.generate_my_reminder_notifications() = 0, 'and have none of their own';
end $$;

:anon
do $$ begin
  assert test_helpers.fails($q$ select public.generate_my_reminder_notifications() $q$), 'anon cannot';
  assert test_helpers.fails($q$ select * from public.notifications $q$), 'anon cannot read';
end $$;

-- A record getting verified tells the owner (server side, as the vet flow will).
:server
update public.health_records set verified_by_partner_id = 'b0000000-0000-0000-0000-000000000001', verified_at = now(),
       given_by_partner_id = 'b0000000-0000-0000-0000-000000000001'
 where name = 'Deworming' and pet_id = 'c0000000-0000-0000-0000-000000000001' and next_due_on is not null;
do $$ begin
  assert (select count(*) from public.notifications where kind = 'record_verified' and body = 'Paws & Claws Vet Clinic verified Bingo''s Deworming.') = 1,
    'the owner hears about a verified record';
end $$;

-- ---------------------------------------------------------------------------
-- Share links
-- ---------------------------------------------------------------------------
:tolu
do $$
declare res jsonb; stored text;
begin
  res := public.create_passport_share('c0000000-0000-0000-0000-000000000001', array['health', 'origin'], 24);
  assert length(res ->> 'token') = 48, 'a long random token is returned';
  assert (res ->> 'expires_at')::timestamptz between now() + interval '23 hours 59 minutes' and now() + interval '24 hours 1 minute', 'expires in 24 hours';
  assert res -> 'scopes' = '["health", "origin"]'::jsonb, 'scopes come back';

  select token_hash into stored from public.passport_shares where id = (res ->> 'id')::uuid;
  assert stored <> res ->> 'token', 'the raw token is not stored';
  assert stored = encode(extensions.digest(res ->> 'token', 'sha256'), 'hex'), 'only its hash is';
  assert (select count(*) from public.passport_shares where token_hash = res ->> 'token') = 0, 'nothing matches the raw token';

  assert public.create_passport_share('c0000000-0000-0000-0000-000000000001') ->> 'token' <> res ->> 'token', 'every link is different';
  assert test_helpers.fails($q$ select public.create_passport_share('c0000000-0000-0000-0000-000000000001', array['health'], 0) $q$, '22023'), 'too short';
  assert test_helpers.fails($q$ select public.create_passport_share('c0000000-0000-0000-0000-000000000001', array['health'], 200) $q$, '22023'), 'too long';
  assert test_helpers.fails($q$ select public.create_passport_share('c0000000-0000-0000-0000-000000000001', array[]::text[], 24) $q$, '22023'), 'needs a scope';
  assert test_helpers.fails($q$ select public.create_passport_share('c0000000-0000-0000-0000-000000000001', array['everything'], 24) $q$, '23514'), 'unknown scope';

  perform public.revoke_passport_share((res ->> 'id')::uuid);
  assert (select revoked_at from public.passport_shares where id = (res ->> 'id')::uuid) is not null, 'can be stopped';
  assert test_helpers.fails(format($q$ select public.revoke_passport_share(%L) $q$, res ->> 'id'), '42501'), 'only once';
end $$;

:bola
do $$ begin
  assert test_helpers.fails($q$ select public.create_passport_share('c0000000-0000-0000-0000-000000000001') $q$, '42501'),
    'cannot share someone else''s pet';
  assert (select count(*) from public.passport_shares) = 0, 'cannot see anyone''s shares';
end $$;

:anon
do $$ begin
  assert test_helpers.fails($q$ select public.create_passport_share('c0000000-0000-0000-0000-000000000001') $q$), 'anon cannot share';
end $$;

-- ---------------------------------------------------------------------------
-- Emergency vets
-- ---------------------------------------------------------------------------
:server
-- Paws & Claws: open for an hour either side of now. A closed one: opened and closed earlier.
update public.partner_accounts
   set opens_at = ((now() at time zone 'Africa/Lagos')::time - interval '1 hour')::time,
       closes_at = ((now() at time zone 'Africa/Lagos')::time + interval '1 hour')::time
 where id = 'b0000000-0000-0000-0000-000000000001';
insert into public.partner_accounts (id, owner_user_id, type, business_name, area, point, status, verified_at, phone, opens_at, closes_at, emergency_care)
values ('b0000000-0000-0000-0000-0000000000f1', 'a0000000-0000-0000-0000-000000000002', 'vet', 'Closed Clinic', 'Yaba',
        extensions.st_point(3.3700, 6.5100, 4326)::extensions.geography, 'approved', now(), '+2340000000009',
        ((now() at time zone 'Africa/Lagos')::time + interval '2 hours')::time, ((now() at time zone 'Africa/Lagos')::time + interval '3 hours')::time, true),
       ('b0000000-0000-0000-0000-0000000000f2', 'a0000000-0000-0000-0000-000000000002', 'vet', 'Pending Clinic', 'Yaba',
        extensions.st_point(3.3700, 6.5100, 4326)::extensions.geography, 'submitted', null, '+2340000000008', null, null, true),
       ('b0000000-0000-0000-0000-0000000000f3', 'a0000000-0000-0000-0000-000000000002', 'vet', 'Routine Only Clinic', 'Yaba',
        extensions.st_point(3.3700, 6.5100, 4326)::extensions.geography, 'approved', now(), '+2340000000007', null, null, false);

:tolu
do $$
declare names text[]; far int; near int;
begin
  select array_agg(business_name order by ord) into names from (select business_name, row_number() over () ord from public.emergency_vets()) x;
  assert 'Lekki Animal Hospital' = names[1], '24 hour clinic comes first, got ' || names::text;
  assert 'Paws & Claws Vet Clinic' = names[2], 'open now comes next';
  assert 'Closed Clinic' = names[3], 'closed ones come last';
  assert not ('Pending Clinic' = any (names)), 'unapproved clinics are never listed';
  assert not ('Routine Only Clinic' = any (names)), 'nor ones that do not take emergencies';
  assert (select bool_and(distance_m is null) from public.emergency_vets()), 'no position, no distance';

  -- From Lekki, the Lekki hospital is the near one.
  select distance_m into near from public.emergency_vets(6.4400, 3.4720) where business_name = 'Lekki Animal Hospital';
  select distance_m into far from public.emergency_vets(6.4400, 3.4720) where business_name = 'Paws & Claws Vet Clinic';
  assert near < 100 and far > 10000, 'distances are in metres: ' || near || ' and ' || far;
  assert (select open_now from public.emergency_vets() where business_name = 'Paws & Claws Vet Clinic'), 'open now is worked out in Lagos time';
  assert not (select open_now from public.emergency_vets() where business_name = 'Closed Clinic'), 'closed is closed';
  assert (select lat is not null and lng is not null and phone is not null from public.emergency_vets() where business_name = 'Lekki Animal Hospital'),
    'directions and calling details come back';
  assert (select count(*) from public.emergency_vets(null, null, 1)) = 1, 'limit works';
end $$;

:anon
do $$ begin
  assert test_helpers.fails($q$ select * from public.emergency_vets() $q$), 'anon cannot list clinics';
end $$;

reset role;
rollback;
\echo Health tests passed
