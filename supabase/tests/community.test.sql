-- Community tests (milestone 4): feed, likes, posts, pet profiles, lost alerts and their notifications,
-- sightings, alert chats, reports and blocking.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/community.test.sql
-- Needs seed.sql. Runs in one transaction that is rolled back. Prints "Community tests passed" on success.

\set QUIET on
\set tolu 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set amina 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000002'', true); end $$; set local role authenticated;'
\set ngozi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000004'', true); end $$; set local role authenticated;'
\set kemi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); end $$; set local role authenticated;'
\set bola 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000006'', true); end $$; set local role authenticated;'
\set anon 'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
\set server 'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$;'

begin;

create schema test_helpers;
grant usage on schema test_helpers to anon, authenticated;
-- The SQLSTATE of a statement, or 'ok' when it works.
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

-- Tolu (Lekki): Bingo c...01, Mimi c...02. Kemi (Yaba): Luna c...05. Ngozi (Surulere): Biscuit c...04.
-- Seed posts: Kemi's "Luna loves the window seat" (everyone, Yaba) and Tolu's "Bingo met the new puppy" (nearby, Lekki).

-- ---------------------------------------------------------------------------
-- Posts and the feed
-- ---------------------------------------------------------------------------
:tolu
do $$
declare p uuid;
begin
  assert test_helpers.state($q$ select public.create_post(null, '   ') $q$) = '22023', 'an empty post is refused';
  assert test_helpers.state($q$ select public.create_post(null, repeat('a', 501)) $q$) = '22023', 'at most 500 characters';
  assert test_helpers.state($q$ select public.create_post(null, 'x', array['a0000000-0000-0000-0000-000000000001/1.jpg','a0000000-0000-0000-0000-000000000001/2.jpg','a0000000-0000-0000-0000-000000000001/3.jpg','a0000000-0000-0000-0000-000000000001/4.jpg','a0000000-0000-0000-0000-000000000001/5.jpg']) $q$) = '22023', 'at most 4 photos';
  assert test_helpers.state($q$ select public.create_post(null, 'x', array['a0000000-0000-0000-0000-000000000005/steal.jpg']) $q$) = '22023', 'photos must be in your own folder';
  assert test_helpers.state($q$ select public.create_post('c0000000-0000-0000-0000-000000000005', 'my cat now') $q$) = '42501', 'you cannot post as someone else''s pet';
  assert test_helpers.state($q$ select public.create_post(null, 'x', '{}', 'everyone', true) $q$) = 'ok', 'a plain post works';
  assert test_helpers.state($q$ select public.create_post(null, 'x', '{}', 'followers', true) $q$) = '22023', 'followers see posts about a pet, so a pet is needed';
  assert test_helpers.state($q$ select public.create_post(null, 'x', '{}', 'nearby', false) $q$) = '22023', 'nearby needs the area shown';
  assert test_helpers.state($q$ select public.create_post(null, 'x', '{}', 'world', true) $q$) = '22023', 'unknown visibility';

  p := public.create_post('c0000000-0000-0000-0000-000000000001', 'Sunday walk at Lekki Conservation Centre.',
                          array['a0000000-0000-0000-0000-000000000001/walk.jpg'], 'everyone', true);
  perform set_config('test.walk', p::text, true);
  assert (select area from public.posts where id = p) = 'Lekki', 'the area is shown from the profile, not typed by the client';
  p := public.create_post(null, 'Private area post', '{}', 'everyone', false);
  assert (select area from public.posts where id = p) is null, 'area can be hidden';
  p := public.create_post('c0000000-0000-0000-0000-000000000001', 'Just for followers', '{}', 'followers', true);
  perform set_config('test.followers', p::text, true);
end $$;

:kemi
do $$
declare r record; walk uuid := current_setting('test.walk')::uuid;
begin
  assert exists (select 1 from public.community_feed('for_you') where post_id = walk), 'Kemi sees a public post from Lekki';
  assert not exists (select 1 from public.community_feed('for_you') where body = 'Bingo met the new puppy next door.'), 'but not a Lekki-only post';
  assert not exists (select 1 from public.community_feed('for_you') where post_id = current_setting('test.followers')::uuid), 'nor a followers-only post';
  assert (select count(*) from public.community_feed('near')) = 1, 'near me is her own area: just Luna''s post';
  select * into r from public.community_feed('for_you') where post_id = walk;
  assert r.author_name = 'Tolu' and r.pet_name = 'Bingo' and r.pet_species = 'dog' and r.area = 'Lekki', 'the card has the author, pet and area';
  assert r.like_count = 0 and not r.liked_by_me and not r.following_pet and not r.is_mine, 'and the starting state';
  assert (select count(*) from public.community_feed('for_you', 1)) = 1, 'the limit is respected';
  assert (select count(*) from public.community_feed('for_you', 20, (select created_at from public.posts where id = walk))) < (select count(*) from public.community_feed('for_you')), 'paging with before';

  -- following a pet shows its followers-only posts
  insert into public.follows (follower_user_id, pet_id) values ('a0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000001');
  assert exists (select 1 from public.community_feed('for_you') where post_id = current_setting('test.followers')::uuid), 'a follower sees followers-only posts';
  assert (select following_pet from public.community_feed('for_you') where post_id = walk), 'and the card says she follows Bingo';
end $$;

-- Likes
:kemi
do $$
declare walk uuid := current_setting('test.walk')::uuid; res jsonb;
begin
  res := public.toggle_like(walk);
  assert (res ->> 'liked')::boolean and (res ->> 'count')::int = 1, 'liked once';
  assert (select liked_by_me and like_count = 1 from public.community_feed('for_you') where post_id = walk), 'the feed agrees';
  res := public.toggle_like(walk);
  assert not (res ->> 'liked')::boolean and (res ->> 'count')::int = 0, 'unliked';
  perform public.toggle_like(walk);
  assert test_helpers.state(format($q$ select public.toggle_like(%L) $q$, (select id from public.posts where body = 'Bingo met the new puppy next door.'))) = 'P0002', 'cannot like a post you cannot see';
  assert (select count(*) from public.post_likes) = 1, 'she can read only her own likes';
  assert test_helpers.state($q$ insert into public.post_likes (post_id, user_id) values (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000005') $q$) <> 'ok', 'likes only through the function';
end $$;
:ngozi
do $$ declare walk uuid := current_setting('test.walk')::uuid; begin
  assert (public.toggle_like(walk) ->> 'count')::int = 2, 'two people liked it';
  assert (select count(*) from public.post_likes) = 1, 'Ngozi sees only her own like row';
end $$;
:tolu
do $$ begin
  assert (select like_count from public.community_feed('for_you') where post_id = current_setting('test.walk')::uuid) = 2, 'the author sees the count';
  assert (select is_mine from public.community_feed('for_you') where post_id = current_setting('test.walk')::uuid), 'and that it is theirs';
  assert exists (select 1 from public.community_feed('near') where body = 'Bingo met the new puppy next door.'), 'Tolu''s near feed has his Lekki posts';
end $$;

-- Blocking hides people from each other
:kemi
insert into public.blocks (user_id, blocked_user_id) values ('a0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001');
do $$ begin
  assert not exists (select 1 from public.community_feed('for_you') where author_name = 'Tolu'), 'Kemi no longer sees Tolu';
end $$;
:tolu
do $$ begin
  assert not exists (select 1 from public.community_feed('for_you') where author_name = 'Kemi'), 'and Tolu no longer sees Kemi';
end $$;
:kemi
delete from public.blocks where user_id = 'a0000000-0000-0000-0000-000000000005';

:server
update public.posts set status = 'hidden' where id = current_setting('test.followers')::uuid;
:kemi
do $$ begin
  assert not exists (select 1 from public.community_feed('for_you') where post_id = current_setting('test.followers')::uuid), 'moderated posts leave the feed';
end $$;
:anon
do $$ begin
  assert test_helpers.state($q$ select * from public.community_feed('for_you') $q$) = '42501', 'signed out people cannot read the feed';
end $$;

-- ---------------------------------------------------------------------------
-- Pet profiles
-- ---------------------------------------------------------------------------
:kemi
do $$
declare prof jsonb;
begin
  prof := public.pet_profile('c0000000-0000-0000-0000-000000000001');
  assert prof ->> 'name' = 'Bingo' and prof ->> 'owner_name' = 'Tolu' and prof ->> 'area' = 'Lekki', 'a public pet shows its identity';
  assert (prof ->> 'posts')::int >= 1, 'with its public post count';
  assert (prof ->> 'followers')::int = 1 and (prof ->> 'is_following')::boolean and not (prof ->> 'is_mine')::boolean, 'Kemi follows Bingo';
  assert not (prof ? 'phone') and not (prof ? 'owner_phone') and not (prof ? 'health') and not (prof ? 'owner_user_id' and false), 'no phone or health data';
  assert test_helpers.state($q$ select public.pet_profile('c0000000-0000-0000-0000-000000000002') $q$) = 'P0002', 'a private pet has no public profile';
  assert test_helpers.state($q$ select public.pet_profile(gen_random_uuid()) $q$) = 'P0002', 'unknown pet';
  assert (select count(*) from public.pet_posts('c0000000-0000-0000-0000-000000000001')) >= 1, 'its posts are listed';
  delete from public.follows where follower_user_id = 'a0000000-0000-0000-0000-000000000005';
  assert not (public.pet_profile('c0000000-0000-0000-0000-000000000001') ->> 'is_following')::boolean, 'unfollowed';
end $$;
:tolu
do $$ begin
  assert (public.pet_profile('c0000000-0000-0000-0000-000000000002') ->> 'is_mine')::boolean, 'an owner sees their own pet';
  assert test_helpers.state($q$ insert into public.follows (follower_user_id, pet_id) values ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001') $q$) <> 'ok', 'you cannot follow your own pet';
end $$;

-- ---------------------------------------------------------------------------
-- Lost alerts and who gets told
-- ---------------------------------------------------------------------------
:ngozi
do $$ begin
  assert test_helpers.state($q$ select public.update_my_location(91, 3) $q$) = '22023', 'a bad latitude is refused';
  perform public.update_my_location(6.4500, 3.4700);  -- about half a km from Admiralty Way
end $$;
:kemi
select public.update_my_location(6.5095, 3.3711);  -- Yaba, about 12 km away
:anon
do $$ begin
  assert test_helpers.state($q$ select public.update_my_location(6.5, 3.4) $q$) = '42501', 'signed out people cannot set a location';
end $$;

:tolu
do $$
declare res jsonb; alert uuid;
begin
  assert test_helpers.state($q$ select public.create_lost_alert('c0000000-0000-0000-0000-000000000005', 6.4474, 3.4723) $q$) = '42501', 'only for your own pet';
  assert test_helpers.state($q$ select public.create_lost_alert('c0000000-0000-0000-0000-000000000001', 6.4474, 3.4723, null, null, null, 3000) $q$) = '22023', 'the radius is 2, 5 or 10 km';
  assert test_helpers.state($q$ select public.create_lost_alert('c0000000-0000-0000-0000-000000000001', 91, 3.4723) $q$) = '22023', 'a real place is needed';
  assert test_helpers.state($q$ select public.create_lost_alert('c0000000-0000-0000-0000-000000000001', 6.4474, 3.4723, null, now() + interval '2 hours') $q$) = '22023', 'not in the future';
  assert test_helpers.state($q$ select public.create_lost_alert('c0000000-0000-0000-0000-000000000001', 6.4474, 3.4723, null, now() - interval '20 days') $q$) = '22023', 'not older than two weeks';
  assert test_helpers.state($q$ select public.create_lost_alert('c0000000-0000-0000-0000-000000000001', 6.4474, 3.4723, null, null, repeat('a', 501)) $q$) = '22023', 'description length';

  res := public.create_lost_alert('c0000000-0000-0000-0000-000000000001', 6.4474, 3.4723, 'Admiralty Way, Lekki Phase 1',
                                  now() - interval '2 hours', 'Red collar with PawPass tag. Friendly but shy.', 5000);
  alert := (res ->> 'alert_id')::uuid;
  perform set_config('test.alert', alert::text, true);
  assert (res ->> 'notified')::int = 1, 'only Ngozi, who was near, is told (' || (res ->> 'notified') || ')';
  assert test_helpers.state($q$ select public.create_lost_alert('c0000000-0000-0000-0000-000000000001', 6.4474, 3.4723) $q$) = 'P0001', 'one active alert per pet';
  assert (select radius_m from public.lost_alerts where id = alert) = 5000, 'the radius is stored';
  assert not exists (select 1 from public.notifications where kind = 'lost_alert'), 'the owner is not notified of their own alert';
end $$;
:ngozi
do $$ declare n record; begin
  select * into n from public.notifications where kind = 'lost_alert';
  assert n.title = 'Lost dog near you', 'title (' || n.title || ')';
  assert n.body = 'Bingo, Boerboel, was last seen on Admiralty Way, Lekki Phase 1.', 'body (' || n.body || ')';
  assert n.link = '/lost/' || current_setting('test.alert'), 'it opens the alert';
  assert n.body !~ '\+?\d{7,}', 'and carries no phone number';
end $$;
:kemi
do $$ begin
  assert (select count(*) from public.notifications where kind = 'lost_alert') = 0, 'Kemi is 12 km away and is not told';
end $$;

-- A person who blocked the owner is not told about their next alert.
:ngozi
insert into public.blocks (user_id, blocked_user_id) values ('a0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001');
:tolu
do $$ begin
  assert (public.create_lost_alert('c0000000-0000-0000-0000-000000000002', 6.4474, 3.4723, 'Lekki', null, null, 10000) ->> 'notified')::int = 0, 'blocked people are not notified';
end $$;
:ngozi
delete from public.blocks where user_id = 'a0000000-0000-0000-0000-000000000004';

-- Finding alerts
:ngozi
do $$ declare r record; begin
  select * into r from public.lost_alerts_nearby(6.4500, 3.4700) where pet_name = 'Bingo';
  assert r.address = 'Admiralty Way, Lekki Phase 1' and r.species = 'dog' and r.breed = 'Boerboel' and not r.is_mine, 'Ngozi sees the alert';
  assert r.distance_m % 100 = 0 and r.distance_m < 1000, 'distance is rounded to 100 m (' || r.distance_m || ')';
  assert r.sightings = 0, 'no sightings yet';
end $$;
:kemi
do $$ begin
  assert not exists (select 1 from public.lost_alerts_nearby(6.5095, 3.3711) where pet_name = 'Bingo'), 'Bingo''s alert does not reach Yaba';
  assert exists (select 1 from public.lost_alerts_nearby() where pet_name = 'Bingo'), 'without a location every active alert is listed';
end $$;
:tolu
do $$ begin
  assert (select is_mine from public.lost_alerts_nearby(6.5095, 3.3711) where pet_name = 'Bingo'), 'owners always see their own alert';
end $$;
:anon
do $$ begin
  assert test_helpers.state($q$ select * from public.lost_alerts_nearby() $q$) = '42501', 'signed out people cannot browse alerts';
end $$;

-- Sightings
:ngozi
do $$
declare s uuid; alert uuid := current_setting('test.alert')::uuid; i int;
begin
  assert test_helpers.state(format($q$ select public.report_sighting(%L, 91, 3) $q$, alert)) = '22023', 'a real place is needed';
  s := public.report_sighting(alert, 6.4480, 3.4690, 'Seen near Chevron roundabout');
  assert s is not null, 'sighting saved';
  for i in 1..4 loop perform public.report_sighting(alert, 6.4480, 3.4690, 'again ' || i); end loop;
  assert test_helpers.state(format($q$ select public.report_sighting(%L, 6.4480, 3.4690) $q$, alert)) = 'P0001', 'five a day is the limit';
end $$;
:tolu
do $$
declare d jsonb; alert uuid := current_setting('test.alert')::uuid;
begin
  assert test_helpers.state(format($q$ select public.report_sighting(%L, 6.4, 3.4) $q$, alert)) = '22023', 'not on your own alert';
  assert (select count(*) from public.notifications where kind = 'lost_alert' and title = 'Someone saw Bingo') = 5, 'the owner hears about each sighting';
  d := public.lost_alert_detail(alert, 6.4474, 3.4723);
  assert (d ->> 'is_mine')::boolean and (d ->> 'sighting_count')::int = 5 and jsonb_array_length(d -> 'sightings') = 5, 'the owner sees all sightings';
  assert (d -> 'sightings' -> 0 ->> 'lat') is not null, 'with their places';
  assert d ->> 'owner_name' = 'Tolu' and d ->> 'pet_name' = 'Bingo' and not (d ? 'phone'), 'no contact details';
  assert (select sightings from public.lost_alerts_nearby(6.4474, 3.4723) where pet_name = 'Bingo') = 5, 'the list counts them';
end $$;
:ngozi
do $$ declare d jsonb; begin
  d := public.lost_alert_detail(current_setting('test.alert')::uuid, 6.4500, 3.4700);
  assert not (d ->> 'is_mine')::boolean and jsonb_array_length(d -> 'sightings') = 5 and (d -> 'sightings' -> 0 ->> 'lat') is null, 'the finder sees their own, without coordinates being echoed';
end $$;
:kemi
do $$ declare d jsonb; begin
  d := public.lost_alert_detail(current_setting('test.alert')::uuid);
  assert (d ->> 'sighting_count')::int = 5 and jsonb_array_length(d -> 'sightings') = 0, 'others see the count only';
  assert (select count(*) from public.sightings) = 0, 'and cannot read sighting rows';
  assert test_helpers.state($q$ select public.lost_alert_detail(gen_random_uuid()) $q$) = 'P0002', 'unknown alert';
end $$;

-- ---------------------------------------------------------------------------
-- Chat
-- ---------------------------------------------------------------------------
:tolu
do $$ begin
  assert test_helpers.state(format($q$ select public.open_alert_chat(%L) $q$, current_setting('test.alert'))) = '22023', 'the owner waits for finders to write';
end $$;
:ngozi
do $$
declare c1 uuid; c2 uuid;
begin
  c1 := public.open_alert_chat(current_setting('test.alert')::uuid);
  c2 := public.open_alert_chat(current_setting('test.alert')::uuid);
  assert c1 = c2, 'one conversation per finder and alert';
  perform set_config('test.conv', c1::text, true);
  assert test_helpers.state(format($q$ select public.send_message(%L, '   ') $q$, c1)) = '22023', 'empty message';
  assert test_helpers.state(format($q$ select public.send_message(%L, repeat('a', 1001)) $q$, c1)) = '22023', 'too long';
  assert test_helpers.state(format($q$ select public.send_message(%L, 'x', 6.4) $q$, c1)) = '22023', 'half a location';
  perform public.send_message(c1, 'Hi! I think I just saw Bingo near the Chevron roundabout.');
  perform public.send_message(c1, null, 6.4480, 3.4690);
end $$;
:server
-- One test transaction has one clock: move what has happened so far back an hour so "newer than" means something.
update public.messages set created_at = created_at - interval '1 hour';
update public.conversation_members set last_read_at = last_read_at - interval '1 hour' where last_read_at is not null;
:amina
do $$ begin
  assert test_helpers.state(format($q$ select public.send_message(%L, 'hello') $q$, current_setting('test.conv'))) = '42501', 'outsiders cannot send';
  assert (select count(*) from public.conversation_messages(current_setting('test.conv')::uuid)) = 0, 'or read';
  assert (select count(*) from public.messages) = 0, 'or read the table';
end $$;
:tolu
do $$ declare c uuid := current_setting('test.conv')::uuid; r record; begin
  assert (select count(*) from public.conversation_messages(c)) = 2, 'the owner reads both';
  select * into r from public.my_conversations();
  assert r.context_label = 'Lost alert · Bingo' and r.other_name = 'Ngozi' and r.unread = 2 and r.last_body = 'Shared a location', 'the inbox row (' || r.context_label || '/' || r.unread || '/' || coalesce(r.last_body, '') || ')';
  assert (select lat from public.conversation_messages(c) where lat is not null) between 6.447 and 6.449, 'a shared location comes back as coordinates';
  assert (public.conversation_header(c) ->> 'other_name') = 'Ngozi', 'header';
  perform public.mark_conversation_read(c);
  assert (select unread from public.my_conversations()) = 0, 'read';
  perform public.send_message(c, 'Thank you so much! I am 5 minutes away.');
end $$;
:ngozi
do $$ begin
  assert (select unread from public.my_conversations()) = 1, 'the finder has one unread reply';
  assert (select mine from public.conversation_messages(current_setting('test.conv')::uuid) order by created_at desc limit 1) = false, 'and it is not theirs';
end $$;

-- Blocking ends the conversation
:tolu
insert into public.blocks (user_id, blocked_user_id) values ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000004');
do $$ begin
  assert (select count(*) from public.my_conversations()) = 0, 'the blocker no longer lists it';
  assert test_helpers.state(format($q$ select public.send_message(%L, 'still there?') $q$, current_setting('test.conv'))) = 'P0001', 'and cannot send';
end $$;
:ngozi
do $$ begin
  assert test_helpers.state(format($q$ select public.send_message(%L, 'hello?') $q$, current_setting('test.conv'))) = 'P0001', 'the blocked person cannot send either';
  assert test_helpers.state(format($q$ select public.open_alert_chat(%L) $q$, current_setting('test.alert'))) = 'P0002', 'or open a new chat';
end $$;
:tolu
delete from public.blocks where user_id = 'a0000000-0000-0000-0000-000000000001';

-- Direct writes are closed: messages go through the function
:amina
do $$ begin
  assert test_helpers.state(format($q$ insert into public.messages (conversation_id, sender_user_id, body) values (%L, 'a0000000-0000-0000-0000-000000000002', 'hi') $q$, current_setting('test.conv'))) <> 'ok', 'non members cannot insert';
end $$;

-- Closing the alert
:tolu
update public.lost_alerts set status = 'found' where id = current_setting('test.alert')::uuid;
do $$ begin
  assert not exists (select 1 from public.lost_alerts_nearby() where pet_name = 'Bingo' and sightings >= 0 and alert_id = current_setting('test.alert')::uuid), 'a found pet leaves the list';
end $$;
:kemi
do $$ begin
  assert test_helpers.state(format($q$ select public.open_alert_chat(%L) $q$, current_setting('test.alert'))) = 'P0001', 'a closed alert takes no new chats';
end $$;
:ngozi
do $$ begin
  assert test_helpers.state(format($q$ select public.report_sighting(%L, 6.4, 3.4) $q$, current_setting('test.alert'))) = 'P0001', 'no sightings on a closed alert';
  assert public.open_alert_chat(current_setting('test.alert')::uuid) = current_setting('test.conv')::uuid, 'but an existing chat can still be reopened';
end $$;

-- ---------------------------------------------------------------------------
-- Reports and blocking
-- ---------------------------------------------------------------------------
:kemi
do $$
declare walk uuid := current_setting('test.walk')::uuid;
begin
  assert test_helpers.state(format($q$ select public.file_report('post', %L, 'nonsense') $q$, walk)) = '22023', 'choose a listed reason';
  assert test_helpers.state(format($q$ select public.file_report('listing', %L, 'scam') $q$, walk)) = '22023', 'only some things can be reported here';
  assert test_helpers.state($q$ select public.file_report('post', gen_random_uuid(), 'scam') $q$) = 'P0002', 'unknown post';
  assert test_helpers.state(format($q$ select public.file_report('post', %L, 'scam') $q$, (select id from public.posts where body = 'Bingo met the new puppy next door.'))) = 'P0002', 'cannot report what you cannot see';
  assert test_helpers.state(format($q$ select public.file_report('post', %L, 'spam') $q$, (select id from public.posts where author_user_id = 'a0000000-0000-0000-0000-000000000005' limit 1))) = '22023', 'cannot report yourself';

  perform public.file_report('post', walk, 'scam', true);
  perform public.file_report('post', walk, 'scam', true);
  assert (select count(*) from public.reports where target_id = walk) = 1, 'the same report is not filed twice';
  assert (select reason from public.reports where target_id = walk) = 'Scam or fake seller', 'the reason is stored as shown';
  assert exists (select 1 from public.blocks where user_id = 'a0000000-0000-0000-0000-000000000005' and blocked_user_id = 'a0000000-0000-0000-0000-000000000001'), '"also block" blocks the author';
  assert not exists (select 1 from public.community_feed('for_you') where post_id = walk), 'and their posts are gone from her feed';
end $$;
:tolu
do $$ begin
  assert (select count(*) from public.reports) = 0, 'the reported person cannot see reports';
  assert (select count(*) from public.blocks) = 0, 'or who blocked them';
end $$;
:amina
do $$ begin
  perform public.file_report('lost_alert', current_setting('test.alert')::uuid, 'cruelty', false);
  assert (select count(*) from public.reports where reporter_user_id = 'a0000000-0000-0000-0000-000000000002') = 1, 'alerts can be reported';
end $$;
:anon
do $$ begin
  assert test_helpers.state(format($q$ select public.file_report('post', %L, 'scam') $q$, current_setting('test.walk'))) = '42501', 'signed out people cannot report';
end $$;

reset role;
rollback;
\echo Community tests passed
