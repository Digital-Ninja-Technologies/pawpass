-- Community interactions tests: comments and replies, comment likes, notifications, reporting a comment,
-- and message requests (the pet's owner accepts before a chat starts).
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/community_interactions.test.sql
-- Needs seed.sql and migration 20261113100000. Runs in one transaction that is rolled back.
-- Prints "Community interaction tests passed" on success.
-- NOT RUN YET: written without a database to run it on. Run it before relying on the migration.

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

-- Tolu (Lekki) owns Bingo c...01. Kemi (Yaba) owns Luna c...05. Tolu posts as Bingo, everyone can see it.
:tolu
do $$
declare p uuid;
begin
  p := public.create_post('c0000000-0000-0000-0000-000000000001', 'Bingo at the beach.', '{}', 'everyone', true);
  perform set_config('test.post', p::text, true);
end $$;

-- ---------------------------------------------------------------------------
-- Comments and replies
-- ---------------------------------------------------------------------------
:kemi
do $$
declare p uuid := current_setting('test.post')::uuid; c1 uuid; c2 uuid; c3 uuid;
begin
  assert test_helpers.state(format($q$ select public.add_comment(%L, '   ') $q$, p)) = '22023', 'an empty comment is refused';
  assert test_helpers.state(format($q$ select public.add_comment(%L, repeat('a', 1001)) $q$, p)) = '22023', 'at most 1000 characters';
  c1 := public.add_comment(p, 'What a handsome boy!');
  c2 := public.add_comment(p, 'Same breed as my uncle''s dog', c1);
  perform set_config('test.c1', c1::text, true);
  perform set_config('test.c2', c2::text, true);
  assert (select count(*) from public.post_comments_list(p)) = 2, 'both are listed';
  assert (select parent_id from public.post_comments_list(p) where comment_id = c2) = c1, 'the reply sits under its comment';
  -- A reply to a reply goes to the top comment: replies stay one level deep.
  c3 := public.add_comment(p, 'Replying to the reply', c2);
  assert (select parent_id from public.post_comments_list(p) where comment_id = c3) = c1, 'replies stay one level deep';
  assert (select comment_count from public.community_feed('for_you') where post_id = p) = 3, 'the feed counts them';
  assert (select comment_count from public.post_detail(p)) = 3, 'so does the post page';
  assert (select is_mine from public.post_comments_list(p) where comment_id = c1), 'Kemi sees her own comment as hers';
  assert (public.toggle_comment_like(c1) ->> 'liked')::boolean, 'a comment can be liked';
  assert not (public.toggle_comment_like(c1) ->> 'liked')::boolean, 'and unliked';
end $$;

-- The author is told about comments and replies, once each.
:tolu
do $$
declare p uuid := current_setting('test.post')::uuid; c1 uuid := current_setting('test.c1')::uuid;
begin
  assert exists (select 1 from public.notifications n where n.user_id = 'a0000000-0000-0000-0000-000000000001'
                   and n.dedupe_key = 'comment:' || c1 and n.link = '/posts/' || p), 'Tolu is told about the comment';
  assert (select count(*) from public.post_comments_list(p)) = 3, 'Tolu sees them too';
  assert (public.toggle_like(p) ->> 'liked')::boolean, 'Tolu likes his own post';
  assert not exists (select 1 from public.notifications n where n.dedupe_key like 'like:' || p || ':a0000000-0000-0000-0000-000000000001'), 'liking your own post tells no one';
end $$;

:kemi
do $$
declare p uuid := current_setting('test.post')::uuid;
begin
  perform public.toggle_like(p);
  assert exists (select 1 from public.notifications n where n.user_id = 'a0000000-0000-0000-0000-000000000001'
                   and n.dedupe_key = 'like:' || p || ':a0000000-0000-0000-0000-000000000005'), 'Tolu is told Kemi liked his post';
end $$;

-- ---------------------------------------------------------------------------
-- Who can remove, report and see what
-- ---------------------------------------------------------------------------
:bola
do $$
declare p uuid := current_setting('test.post')::uuid; c1 uuid := current_setting('test.c1')::uuid;
begin
  assert test_helpers.state(format($q$ select public.delete_comment(%L) $q$, c1)) = '42501', 'a stranger cannot remove someone else''s comment';
  perform public.file_report('comment', c1, 'harassment', false);
  assert exists (select 1 from public.reports where reporter_user_id = 'a0000000-0000-0000-0000-000000000006' and target_type = 'comment'), 'a comment can be reported';
  assert (select count(*) from public.post_comments_list(p)) = 3, 'Bola can read the public comments';
end $$;

:anon
do $$
begin
  assert test_helpers.state(format($q$ select * from public.post_comments_list(%L) $q$, current_setting('test.post'))) = '42501'
      or (select count(*) from public.post_comments_list(current_setting('test.post')::uuid)) = 0, 'signed out people see nothing';
  assert test_helpers.state(format($q$ select public.add_comment(%L, 'hi') $q$, current_setting('test.post'))) = '42501', 'and cannot comment';
end $$;

-- The post's author can remove a comment on their post, and a removed comment takes its replies with it.
:tolu
do $$
declare p uuid := current_setting('test.post')::uuid; c1 uuid := current_setting('test.c1')::uuid;
begin
  perform public.delete_comment(c1);
  assert (select count(*) from public.post_comments_list(p)) = 0, 'the thread is gone';
  assert (select comment_count from public.community_feed('for_you') where post_id = p) = 0, 'and the count follows';
end $$;

-- Blocking hides a person's comments.
:kemi
do $$
declare p uuid := current_setting('test.post')::uuid;
begin
  perform public.add_comment(p, 'A fresh comment');
  insert into public.blocks (user_id, blocked_user_id) values ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000005');
end $$;
:tolu
do $$
begin
  assert test_helpers.state(format($q$ select public.add_comment(%L, 'x') $q$, current_setting('test.post'))) = 'P0002', 'a blocked person''s post is not found';
  delete from public.blocks where user_id = 'a0000000-0000-0000-0000-000000000001';
end $$;

-- ---------------------------------------------------------------------------
-- Message requests
-- ---------------------------------------------------------------------------
:kemi
do $$
declare conv uuid; again uuid; req uuid;
begin
  assert test_helpers.state($q$ select public.request_chat('c0000000-0000-0000-0000-000000000005', 'hi') $q$) = '22023', 'you cannot message your own pet';
  assert test_helpers.state($q$ select public.request_chat('c0000000-0000-0000-0000-000000000001', '   ') $q$) = '22023', 'the first message cannot be empty';
  assert test_helpers.state($q$ select public.request_chat('c0000000-0000-0000-0000-000000000001', repeat('a', 501)) $q$) = '22023', 'at most 500 characters';
  conv := public.request_chat('c0000000-0000-0000-0000-000000000001', 'Hi Tolu, where did you get Bingo?');
  perform set_config('test.conv', conv::text, true);
  again := public.request_chat('c0000000-0000-0000-0000-000000000001', 'Asking again');
  assert again = conv, 'a second request reuses the same chat';
  assert (select i_requested and request_status = 'pending' from public.my_conversations() where conversation_id = conv), 'Kemi sees it waiting';
  assert test_helpers.state(format($q$ select public.send_message(%L, 'more please') $q$, conv)) = 'P0001', 'she cannot send more until he accepts';
  assert (select count(*) from public.conversation_messages(conv)) = 1, 'only the first message is there';
end $$;

:tolu
do $$
declare conv uuid := current_setting('test.conv')::uuid; req uuid;
begin
  assert exists (select 1 from public.notifications n where n.user_id = 'a0000000-0000-0000-0000-000000000001' and n.dedupe_key like 'dm_req:%'), 'Tolu is told about the request';
  select request_id into req from public.my_conversations() where conversation_id = conv;
  assert (select request_status = 'pending' and not i_requested from public.my_conversations() where conversation_id = conv), 'Tolu sees a request to answer';
  assert (select count(*) from public.conversation_messages(conv)) = 1, 'and can read the first message';
  assert test_helpers.state(format($q$ select public.send_message(%L, 'hello') $q$, conv)) = 'P0001', 'he cannot reply before accepting';
  perform public.respond_to_chat_request(req, true);
  assert test_helpers.state(format($q$ select public.respond_to_chat_request(%L, true) $q$, req)) = 'P0001', 'it can only be answered once';
  perform public.send_message(conv, 'Hi Kemi, from a breeder in Ikeja.');
  assert (public.conversation_header(conv) ->> 'request_status') = 'accepted', 'the header says accepted';
end $$;

:kemi
do $$
declare conv uuid := current_setting('test.conv')::uuid;
begin
  assert exists (select 1 from public.notifications n where n.user_id = 'a0000000-0000-0000-0000-000000000005' and n.dedupe_key like 'dm_ok:%'), 'Kemi is told it was accepted';
  perform public.send_message(conv, 'Thank you!');
  assert (select count(*) from public.conversation_messages(conv)) = 3, 'now they can talk';
  assert exists (select 1 from public.notifications n where n.user_id = 'a0000000-0000-0000-0000-000000000001' and n.dedupe_key like 'msg:%'), 'messages tell the other person';
end $$;

-- A declined request is closed for good, and hidden from both people.
:bola
do $$
declare conv uuid; req uuid;
begin
  conv := public.request_chat('c0000000-0000-0000-0000-000000000001', 'Is Bingo for sale?');
  perform set_config('test.conv2', conv::text, true);
end $$;
:tolu
do $$
declare conv uuid := current_setting('test.conv2')::uuid; req uuid;
begin
  select request_id into req from public.my_conversations() where conversation_id = conv;
  perform public.respond_to_chat_request(req, false);
  assert not exists (select 1 from public.my_conversations() where conversation_id = conv), 'declined: gone from his list';
end $$;
:bola
do $$
declare conv uuid := current_setting('test.conv2')::uuid;
begin
  assert not exists (select 1 from public.my_conversations() where conversation_id = conv), 'and from hers';
  assert test_helpers.state(format($q$ select public.send_message(%L, 'please') $q$, conv)) = 'P0001', 'she cannot send into it';
  assert test_helpers.state($q$ select public.request_chat('c0000000-0000-0000-0000-000000000001', 'Please?') $q$) = 'P0001', 'or ask again';
end $$;

:anon
do $$
begin
  assert test_helpers.state($q$ select public.request_chat('c0000000-0000-0000-0000-000000000001', 'hi') $q$) = '42501', 'signed out people cannot ask';
end $$;

-- ---------------------------------------------------------------------------
-- The tables are closed: everything goes through the functions.
-- ---------------------------------------------------------------------------
:kemi
do $$
begin
  assert test_helpers.state($q$ select * from public.post_comments $q$) = '42501', 'comments cannot be read directly';
  assert test_helpers.state($q$ select * from public.direct_requests $q$) = '42501', 'nor requests';
  assert test_helpers.state($q$ insert into public.post_comments (post_id, author_user_id, body) values (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000005', 'x') $q$) = '42501', 'nor written';
end $$;

reset role;
rollback;
\echo Community interaction tests passed
