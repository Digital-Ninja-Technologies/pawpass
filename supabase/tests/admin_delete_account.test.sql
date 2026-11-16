-- Admin account deletion tests: only full admins can check, the check names what is in the way, and the audit helper is
-- for the server only.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/admin_delete_account.test.sql
-- Needs seed.sql and migration 20261122100000. Runs in one transaction that is rolled back.
-- Prints "Admin delete account tests passed" on success.

\set QUIET on
\set tolu    'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set admin   'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000007'', true); end $$; set local role authenticated;'
\set support 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f2'', true); end $$; set local role authenticated;'
\set finance 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f1'', true); end $$; set local role authenticated;'
\set viewer  'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f4'', true); end $$; set local role authenticated;'
\set anon    'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
\set server  'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$;'

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

-- Who may check
:anon
do $$ begin
  assert test_helpers.state($q$ select public.admin_account_deletion_check('a0000000-0000-0000-0000-000000000005') $q$) = '42501', 'signed out people cannot check';
end $$;
:tolu
do $$ begin
  assert test_helpers.state($q$ select public.admin_account_deletion_check('a0000000-0000-0000-0000-000000000005') $q$) = '42501', 'an ordinary user cannot check';
  assert test_helpers.state($q$ select public.log_admin_account_deletion(null, 'a0000000-0000-0000-0000-000000000005', 'x') $q$) = '42501', 'or write the audit row';
end $$;
:support
do $$ begin assert test_helpers.state($q$ select public.admin_account_deletion_check('a0000000-0000-0000-0000-000000000005') $q$) = '42501', 'support staff cannot check'; end $$;
:finance
do $$ begin assert test_helpers.state($q$ select public.admin_account_deletion_check('a0000000-0000-0000-0000-000000000005') $q$) = '42501', 'payouts staff cannot check'; end $$;
:viewer
do $$ begin assert test_helpers.state($q$ select public.admin_account_deletion_check('a0000000-0000-0000-0000-000000000005') $q$) = '42501', 'read only staff cannot check'; end $$;

-- A full admin: a clear account, an unknown one, their own, and one with something unfinished
:admin
do $$
declare r jsonb;
begin
  r := public.admin_account_deletion_check('a0000000-0000-0000-0000-000000000005');
  assert (r->>'deleted')::boolean = false, 'Kemi is not deleted';
  assert jsonb_array_length(r->'blockers') = 0, 'nothing is in the way for Kemi';

  assert test_helpers.state($q$ select public.admin_account_deletion_check('a0000000-0000-0000-0000-00000000ffff') $q$) = 'P0002', 'an unknown account is not found';

  r := public.admin_account_deletion_check('a0000000-0000-0000-0000-000000000007');
  assert (r->'blockers'->>0) like '%your own account%', 'your own account is named first';
end $$;

:server
insert into public.ownership_transfers (pet_id, from_user_id, to_user_id)
values ('c0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000006');
:admin
do $$
declare r jsonb;
begin
  r := public.admin_account_deletion_check('a0000000-0000-0000-0000-000000000005');
  assert r->'blockers'->>0 like '%passport transfer%', 'an unfinished transfer is named';
end $$;

-- The audit helper is for the server
:server
do $$
declare sid uuid;
begin
  select id into sid from public.staff_members where user_id = 'a0000000-0000-0000-0000-000000000007';
  perform public.log_admin_account_deletion(sid, 'a0000000-0000-0000-0000-000000000005', 'Asked by email');
  assert exists (select 1 from public.audit_log
                  where action = 'account.delete' and target_id = 'a0000000-0000-0000-0000-000000000005'
                    and staff_id = sid and details->>'reason' = 'Asked by email'), 'the deletion is in the audit log with its reason';
end $$;

reset role;
\echo Admin delete account tests passed
rollback;
