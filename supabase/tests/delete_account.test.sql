-- Account deletion tests: who may call what, what blocks a deletion, what is erased, and that running it again is harmless.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/delete_account.test.sql
-- Needs seed.sql and migration 20261114100000. Runs in one transaction that is rolled back.
-- Prints "Delete account tests passed" on success.

\set QUIET on
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

-- ---------------------------------------------------------------------------
-- Who may call what
-- ---------------------------------------------------------------------------
:bola
do $$
begin
  assert test_helpers.state($q$ select public.my_deletion_blockers() $q$) = 'ok', 'a signed in person can ask what is in the way';
  assert test_helpers.state($q$ select public.erase_account('a0000000-0000-0000-0000-000000000006') $q$) = '42501', 'but cannot erase, even themselves, from the app';
  assert test_helpers.state($q$ select private.deletion_blockers('a0000000-0000-0000-0000-000000000006') $q$) = '42501', 'nor reach the private check';
end $$;
:anon
do $$
begin
  assert test_helpers.state($q$ select public.my_deletion_blockers() $q$) = '42501', 'signed out people cannot ask';
  assert test_helpers.state($q$ select public.erase_account('a0000000-0000-0000-0000-000000000006') $q$) = '42501', 'or erase';
end $$;

-- ---------------------------------------------------------------------------
-- Something to erase: Bola posts, comments on Kemi's post, follows, writes in a chat.
-- ---------------------------------------------------------------------------
:kemi
do $$
declare p uuid;
begin
  p := public.create_post('c0000000-0000-0000-0000-000000000005', 'Luna at the vet', '{}', 'everyone', true);
  perform set_config('test.kemi_post', p::text, true);
end $$;

:bola
do $$
declare mine uuid; c uuid;
begin
  mine := public.create_post(null, 'Bola''s own post', '{}', 'everyone', true);
  perform set_config('test.bola_post', mine::text, true);
  c := public.add_comment(current_setting('test.kemi_post')::uuid, 'Lovely cat');
  perform set_config('test.bola_comment', c::text, true);
  perform public.toggle_like(current_setting('test.kemi_post')::uuid);
  insert into public.follows (follower_user_id, pet_id) values ('a0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000005');
  perform set_config('test.conv', public.request_chat('c0000000-0000-0000-0000-000000000005', 'Hello Kemi')::text, true);
end $$;

-- ---------------------------------------------------------------------------
-- Erasing (as the server). If the seed gives Bola something in flight, the refusal is tested instead.
-- ---------------------------------------------------------------------------
:server
do $$
declare bola uuid := 'a0000000-0000-0000-0000-000000000006'; blockers text[];
begin
  blockers := private.deletion_blockers(bola);
  if coalesce(array_length(blockers, 1), 0) > 0 then
    assert test_helpers.state(format($q$ select public.erase_account(%L) $q$, bola)) = 'P0001', 'refused while something is in flight';
    raise notice 'Bola has something in flight in the seed (%): the erase path was not tested', array_to_string(blockers, ' ');
    return;
  end if;

  assert test_helpers.state($q$ select public.erase_account('00000000-0000-0000-0000-00000000dead') $q$) = 'P0002', 'an unknown account is not found';
  perform public.erase_account(bola);

  assert (select first_name from public.profiles where user_id = bola) = 'Deleted', 'the name is gone';
  assert (select phone from public.profiles where user_id = bola) is null, 'and the phone';
  assert (select deleted_at from public.profiles where user_id = bola) is not null, 'the profile says it was deleted';
  assert not exists (select 1 from public.posts where author_user_id = bola), 'posts are gone';
  assert not exists (select 1 from public.post_comments where author_user_id = bola), 'comments are gone';
  assert not exists (select 1 from public.post_likes where user_id = bola), 'likes are gone';
  assert not exists (select 1 from public.follows where follower_user_id = bola), 'follows are gone';
  assert not exists (select 1 from public.notifications where user_id = bola), 'notifications are gone';
  assert (select body from public.messages where sender_user_id = bola limit 1) = 'This message was deleted', 'what they wrote in a chat is replaced';
  assert (select status from public.direct_requests where requester_user_id = bola) = 'declined', 'a pending request is closed';
  assert not exists (select 1 from public.pets p where p.owner_user_id = bola and p.name <> 'Deleted pet'), 'no pet keeps its name';
  assert (select count(*) from public.account_deletions where user_id = bola) = 1, 'the deletion is recorded';
  -- Other people's things are untouched.
  assert exists (select 1 from public.posts where id = current_setting('test.kemi_post')::uuid), 'Kemi''s post is still there';

  perform public.erase_account(bola);
  assert (select count(*) from public.account_deletions where user_id = bola) = 1, 'running it again changes nothing';
end $$;

-- A person who is on the team is refused, with a readable reason (this is the path that used to fail with
-- "malformed array literal"), and nothing about them is erased.
:server
insert into public.staff_members (user_id, role) values ('a0000000-0000-0000-0000-000000000005', 'read_only');
do $$
declare reasons text[];
begin
  reasons := private.deletion_blockers('a0000000-0000-0000-0000-000000000005');
  assert array_length(reasons, 1) = 1 and reasons[1] like '%PawPass team%', 'staff are told why, in words';
  assert test_helpers.state($q$ select public.erase_account('a0000000-0000-0000-0000-000000000005') $q$) = 'P0001', 'and refused with the blocked code';
  assert not exists (select 1 from public.account_deletions where user_id = 'a0000000-0000-0000-0000-000000000005'), 'nothing was erased';
  assert (select first_name from public.profiles where user_id = 'a0000000-0000-0000-0000-000000000005') <> 'Deleted', 'the profile is untouched';
end $$;
:kemi
do $$
begin
  assert 'You are on the PawPass team. Ask an admin to remove your access first.' = any(public.my_deletion_blockers()), 'the app can read the reasons';
end $$;

reset role;
rollback;
\echo Delete account tests passed
