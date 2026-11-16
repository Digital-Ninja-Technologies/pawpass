-- Pet removal tests: who may remove a pet, what stops it, what is cleaned up, and that history keeps working.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/remove_pet.test.sql
-- Needs seed.sql and migrations 20261120100000 and 20261121100000. Runs in one transaction that is rolled back.
-- Prints "Remove pet tests passed" on success.

\set QUIET on
\set tolu 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set kemi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); end $$; set local role authenticated;'
\set bola 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000006'', true); end $$; set local role authenticated;'
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

-- Kemi's cat Luna (c..05) has a record, a share link and a lost alert. Biscuit (c..04) is made Mimi's (c..02) kitten, so
-- removing Mimi cannot delete her row. A share link on Mimi proves the scrub path revokes it too.
:server
insert into public.health_records (pet_id, type, name, given_on) values ('c0000000-0000-0000-0000-000000000005', 'vaccine', 'Rabies', current_date - 30);
insert into public.passport_shares (pet_id, token_hash, expires_at) values ('c0000000-0000-0000-0000-000000000005', 'hash-luna', now() + interval '1 day');
insert into public.lost_alerts (pet_id, last_seen_point) values ('c0000000-0000-0000-0000-000000000005', 'SRID=4326;POINT(3.38 6.52)');
insert into public.passport_shares (pet_id, token_hash, expires_at) values ('c0000000-0000-0000-0000-000000000002', 'hash-mimi', now() + interval '1 day');
update public.pets set mother_pet_id = 'c0000000-0000-0000-0000-000000000002' where id = 'c0000000-0000-0000-0000-000000000004';

-- ---------------------------------------------------------------------------
-- Who may call what
-- ---------------------------------------------------------------------------
:anon
do $$ begin
  assert test_helpers.state($q$ select public.remove_pet('c0000000-0000-0000-0000-000000000005') $q$) = '42501', 'signed out people cannot remove';
end $$;
:bola
do $$ begin
  assert test_helpers.state($q$ select public.remove_pet('c0000000-0000-0000-0000-000000000005') $q$) = 'P0002', 'someone else cannot remove Luna (not found)';
  assert test_helpers.state($q$ delete from public.pets where id = 'c0000000-0000-0000-0000-000000000005' $q$) = '42501', 'and a direct delete is no longer allowed';
end $$;
:kemi
do $$ begin
  assert test_helpers.state($q$ delete from public.pets where id = 'c0000000-0000-0000-0000-000000000005' $q$) = '42501', 'even the owner cannot delete the row directly';
  assert test_helpers.state($q$ select public.remove_pet('c0000000-0000-0000-0000-00000000ffff') $q$) = 'P0002', 'an unknown pet is not found';
end $$;

-- ---------------------------------------------------------------------------
-- What stops a removal
-- ---------------------------------------------------------------------------
:server
insert into public.ownership_transfers (pet_id, from_user_id, to_user_id)
values ('c0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000006');
:kemi
do $$ begin
  assert test_helpers.state($q$ select public.remove_pet('c0000000-0000-0000-0000-000000000005') $q$) = 'P0001', 'and stops the removal';
  assert exists (select 1 from public.pets where id = 'c0000000-0000-0000-0000-000000000005'), 'Luna is still there';
end $$;
:server
delete from public.ownership_transfers where pet_id = 'c0000000-0000-0000-0000-000000000005';

-- ---------------------------------------------------------------------------
-- Removing a pet nothing else depends on deletes it and what hangs off it
-- ---------------------------------------------------------------------------
:kemi
do $$ begin
  perform public.remove_pet('c0000000-0000-0000-0000-000000000005');
  assert not exists (select 1 from public.pets where id = 'c0000000-0000-0000-0000-000000000005'), 'Luna is gone for her owner';
  assert test_helpers.state($q$ select public.remove_pet('c0000000-0000-0000-0000-000000000005') $q$) = 'P0002', 'removing twice is "not found"';
end $$;
:server
do $$ begin
  assert not exists (select 1 from public.pets where id = 'c0000000-0000-0000-0000-000000000005'), 'nothing depended on Luna, so her row is deleted';
  assert not exists (select 1 from public.health_records where pet_id = 'c0000000-0000-0000-0000-000000000005'), 'her records went with her';
  assert not exists (select 1 from public.passport_shares where token_hash = 'hash-luna'), 'and her share link';
  assert not exists (select 1 from public.lost_alerts where pet_id = 'c0000000-0000-0000-0000-000000000005'), 'and her lost alert';
end $$;

-- ---------------------------------------------------------------------------
-- A pet that is a parent of another keeps its row (emptied), a pet with nothing is deleted outright
-- ---------------------------------------------------------------------------
:tolu
do $$ begin
  perform public.remove_pet('c0000000-0000-0000-0000-000000000002');   -- Mimi: Biscuit's mother
  assert not exists (select 1 from public.pets where id = 'c0000000-0000-0000-0000-000000000002'), 'Mimi is hidden from her owner';
end $$;
:server
do $$ begin
  assert (select removed_at is not null and name = 'Removed pet' and tag_code is null and photo_path is null
            from public.pets where id = 'c0000000-0000-0000-0000-000000000002'),
    'Mimi stays as an emptied row because Biscuit points at her';
  assert not exists (select 1 from public.health_records where pet_id = 'c0000000-0000-0000-0000-000000000002'), 'her records are gone';
  assert (select revoked_at is not null from public.passport_shares where token_hash = 'hash-mimi'), 'her share link is revoked';
  assert (select mother_pet_id from public.pets where id = 'c0000000-0000-0000-0000-000000000004') = 'c0000000-0000-0000-0000-000000000002',
    'Biscuit keeps her link';
end $$;
:tolu
do $$ begin
  perform public.remove_pet('c0000000-0000-0000-0000-000000000001');   -- Bingo: nothing depends on him
  assert test_helpers.state($q$ select public.remove_pet('c0000000-0000-0000-0000-000000000001') $q$) = 'P0002', 'Bingo is gone';
end $$;
:server
do $$ begin
  assert not exists (select 1 from public.pets where id = 'c0000000-0000-0000-0000-000000000001') or
         (select removed_at is not null from public.pets where id = 'c0000000-0000-0000-0000-000000000001'),
    'Bingo is deleted or emptied, never left as he was';
  assert exists (select 1 from public.pets where id = 'c0000000-0000-0000-0000-000000000004' and removed_at is null), 'other pets are untouched';
end $$;

-- A vet verified record still cannot be deleted on its own, only as part of removing the whole pet (Bingo had some above).
:server
insert into public.health_records (pet_id, type, name, given_on, verified_by_partner_id, verified_at)
values ('c0000000-0000-0000-0000-000000000004', 'vaccine', 'Parvo', current_date - 10, 'b0000000-0000-0000-0000-000000000002', now());
:server
do $$ begin perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000004', true); end $$;
set local role authenticated;
do $$ begin
  assert test_helpers.state($q$ delete from public.health_records where pet_id = 'c0000000-0000-0000-0000-000000000004' $q$) in ('42501'), 'a verified record cannot be deleted alone';
  assert test_helpers.state($q$ select public.remove_pet('c0000000-0000-0000-0000-000000000004') $q$) = 'P0001', 'and stops the removal';
end $$;
reset role;
update public.listings set status = 'removed' where pet_id = 'c0000000-0000-0000-0000-000000000004';
do $$ begin perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000004', true); end $$;
set local role authenticated;
do $$ begin
  perform public.remove_pet('c0000000-0000-0000-0000-000000000004');
  assert not exists (select 1 from public.health_records where pet_id = 'c0000000-0000-0000-0000-000000000004'), 'but it goes with the pet';
end $$;

reset role;
\echo Remove pet tests passed
rollback;
