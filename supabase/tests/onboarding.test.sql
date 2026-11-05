-- Onboarding tests: profile fields and create_pet_passport.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/onboarding.test.sql
-- Runs in one transaction that is rolled back. Prints "Onboarding tests passed" on success.

\set QUIET on
\set tolu 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set bola 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000006'', true); end $$; set local role authenticated;'
\set anon 'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'

begin;

create schema test_helpers;
grant usage on schema test_helpers to anon, authenticated;
-- True when the statement fails with the given SQLSTATE class prefix (or a privilege error).
create function test_helpers.fails(q text, state text default null) returns boolean
language plpgsql as $$
begin
  execute q;
  return false;
exception when others then
  return state is null or sqlstate = state;
end;
$$;
grant execute on all functions in schema test_helpers to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Profile: account types and onboarding state
-- ---------------------------------------------------------------------------
:bola
do $$ begin
  assert (select account_types from public.profiles where user_id = 'a0000000-0000-0000-0000-000000000006') = array['owner'],
    'new profiles default to owner';
  assert (select onboarded_at from public.profiles where user_id = 'a0000000-0000-0000-0000-000000000006') is null,
    'not onboarded until the passport is created';
  update public.profiles set account_types = array['owner', 'breeder'] where user_id = 'a0000000-0000-0000-0000-000000000006';
  assert (select account_types from public.profiles where user_id = 'a0000000-0000-0000-0000-000000000006') = array['owner', 'breeder'],
    'owner can choose several account types';
  assert test_helpers.fails($q$ update public.profiles set account_types = array[]::text[] where user_id = 'a0000000-0000-0000-0000-000000000006' $q$, '23514'),
    'at least one account type is required';
  assert test_helpers.fails($q$ update public.profiles set account_types = array['admin'] where user_id = 'a0000000-0000-0000-0000-000000000006' $q$, '23514'),
    'unknown account types are rejected';
end $$;

-- ---------------------------------------------------------------------------
-- create_pet_passport
-- ---------------------------------------------------------------------------
:anon
do $$ begin
  assert test_helpers.fails($q$ select public.create_pet_passport('{"name":"X","species":"dog"}') $q$),
    'anon cannot create a passport';
end $$;

:bola
do $$
declare p public.pets; q public.pets;
begin
  p := public.create_pet_passport(
    '{"name":"  Rex ","species":"dog","breed":"Boerboel","sex":"male","date_of_birth":"2024-08-14"}'::jsonb,
    '[
       {"type":"vaccine","name":"Rabies","given_on":"2025-11-12","next_due_on":"2026-11-12"},
       {"type":"deworming","name":"Deworming","given_on":"2026-10-20","next_due_on":"2027-01-20"},
       {"type":"vaccine","name":"DHPP (5-in-1)","given_on":"2026-03-12"}
     ]'::jsonb,
    array['push', 'whatsapp']);

  assert p.owner_user_id = 'a0000000-0000-0000-0000-000000000006', 'the caller owns the pet';
  assert p.name = 'Rex', 'name is trimmed';
  assert p.tag_code ~ '^PP-[0-9]{4}-[A-HJ-NP-Z]{2}$', 'tag code looks like PP-4821-LK, got ' || coalesce(p.tag_code, 'null');
  assert (select count(*) from public.health_records where pet_id = p.id) = 3, 'three records saved';
  assert (select bool_and(added_by_user_id = 'a0000000-0000-0000-0000-000000000006') from public.health_records where pet_id = p.id),
    'records are marked as added by the owner';
  assert (select bool_and(verified_by_partner_id is null) from public.health_records where pet_id = p.id),
    'owner added records are never vet verified';
  assert (select count(*) from public.reminders where pet_id = p.id) = 2, 'a reminder only for records with a next due date';
  assert (select bool_and(channels = array['push', 'whatsapp']) from public.reminders where pet_id = p.id), 'channels are stored';
  assert (select status from public.reminders where pet_id = p.id order by due_on limit 1) = 'scheduled', 'reminders start scheduled';
  assert (select onboarded_at from public.profiles where user_id = 'a0000000-0000-0000-0000-000000000006') is not null,
    'profile is marked onboarded';

  q := public.create_pet_passport('{"name":"Tiny","species":"cat"}'::jsonb);
  assert q.tag_code <> p.tag_code, 'every pet gets its own tag code';
  assert q.sex = 'unknown', 'sex defaults to unknown';
  assert (select count(*) from public.reminders where pet_id = q.id) = 0, 'no records means no reminders';
end $$;

-- Reminders off: records are saved but no reminders are created.
:bola
do $$
declare p public.pets;
begin
  p := public.create_pet_passport('{"name":"Quiet","species":"dog"}'::jsonb,
    '[{"type":"vaccine","name":"Rabies","given_on":"2025-11-12","next_due_on":"2026-11-12"}]'::jsonb, array[]::text[]);
  assert (select count(*) from public.health_records where pet_id = p.id) = 1, 'record saved';
  assert (select count(*) from public.reminders where pet_id = p.id) = 0, 'no channels, no reminders';
end $$;

-- Privacy: other owners cannot see the new pet or its records.
:tolu
do $$ begin
  assert (select count(*) from public.pets where name in ('Rex', 'Tiny', 'Quiet')) = 0, 'other owners cannot see it';
  assert (select count(*) from public.health_records where name = 'Deworming' and added_by_user_id = 'a0000000-0000-0000-0000-000000000006') = 0,
    'nor its health records';
end $$;

-- Validation: all or nothing.
:bola
do $$
declare before_pets int; before_records int;
begin
  select count(*) into before_pets from public.pets;
  select count(*) into before_records from public.health_records;

  assert test_helpers.fails($q$ select public.create_pet_passport('{"name":"   ","species":"dog"}') $q$, '22023'), 'blank name rejected';
  assert test_helpers.fails($q$ select public.create_pet_passport('{"name":"X","species":"horse"}') $q$, '23514'), 'unknown species rejected';
  assert test_helpers.fails($q$ select public.create_pet_passport('{"name":"X","species":"dog"}', '{}') $q$, '22023'), 'records must be a list';
  assert test_helpers.fails($q$ select public.create_pet_passport('{"name":"X","species":"dog"}', '[{"type":"vaccine","name":"A","given_on":"2026-01-10","next_due_on":"2026-01-01"}]') $q$, '22023'),
    'next due must be after given';
  assert test_helpers.fails($q$ select public.create_pet_passport('{"name":"X","species":"dog"}', '[{"type":"magic","name":"A"}]') $q$, '23514'), 'unknown record type rejected';
  assert test_helpers.fails($q$ select public.create_pet_passport('{"name":"X","species":"dog"}', '[{"type":"vaccine","name":"A","given_on":"2026-01-01","next_due_on":"2027-01-01"}]', array['pigeon']) $q$, '23514'),
    'unknown channel rejected';

  assert (select count(*) from public.pets) = before_pets, 'a failed call saves no pet';
  assert (select count(*) from public.health_records) = before_records, 'a failed call saves no records';
end $$;

reset role;
rollback;
\echo Onboarding tests passed
