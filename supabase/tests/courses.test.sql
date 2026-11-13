-- Courses: who reads what, drafts, saving and reordering lessons, progress, publish and delete, the audit trail,
-- and that deleting an account removes its progress.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/courses.test.sql
-- Needs seed.sql and migration 20261118100000. Runs in one transaction that is rolled back.
-- Prints "Courses tests passed" on success.

\set QUIET on
\set tolu    'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set kemi    'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); end $$; set local role authenticated;'
\set bola    'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000006'', true); end $$; set local role authenticated;'
\set admin   'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000007'', true); end $$; set local role authenticated;'
\set support 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f2'', true); end $$; set local role authenticated;'
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

:server
insert into auth.users (id, email, aud, role, email_confirmed_at, raw_user_meta_data) values
  ('a0000000-0000-0000-0000-0000000000f2', 'support@pawpass.example', 'authenticated', 'authenticated', now(), '{"first_name":"Halima","last_name":"S"}'),
  ('a0000000-0000-0000-0000-0000000000f4', 'viewer@pawpass.example',  'authenticated', 'authenticated', now(), '{"first_name":"Read","last_name":"Only"}');
insert into public.staff_members (user_id, role) values
  ('a0000000-0000-0000-0000-0000000000f2', 'support_reports'),
  ('a0000000-0000-0000-0000-0000000000f4', 'read_only');

-- ---------------------------------------------------------------------------
-- The starter courses
-- ---------------------------------------------------------------------------
do $$
begin
  assert (select count(*) from public.courses) = 10, 'ten starter courses';
  assert (select count(*) from public.courses where status = 'published') = 10, 'all published';
  assert not exists (select 1 from public.courses c where not exists (select 1 from public.course_lessons l where l.course_id = c.id)),
    'every course has lessons';
  assert (select count(*) from public.course_lessons) = 44, 'forty four lessons';
  assert not exists (select 1 from public.course_lessons where body ~ E'—' or title ~ E'—'), 'no em dashes in the copy';
  assert (select count(distinct sort_order) from public.courses) = 10, 'each course has its own place in the order';
  assert (select audience from public.courses where slug = 'potty-training') = 'puppy', 'potty training is for puppies';
  assert (select count(*) from public.courses where audience in ('dog', 'both')) >= 5, 'there are courses for grown dogs too';
end $$;

-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------
:tolu
do $$
begin
  assert (select count(*) from public.courses) = 10, 'a signed in person reads the published courses';
  assert (select count(*) from public.course_lessons) = 44, 'and their lessons';
  assert (select count(*) from public.admin_course_v) = 10, 'the view only shows what they may read';
  assert (select max(learners) from public.admin_course_v) = 0, 'but never learner counts';
  assert test_helpers.state($q$ insert into public.courses (slug, title, summary) values ('mine', 'My course', 'Not allowed') $q$) = '42501', 'no writing courses';
  assert test_helpers.state($q$ update public.courses set title = 'Hacked title' $q$) = '42501', 'no editing courses';
  assert test_helpers.state($q$ delete from public.course_lessons $q$) = '42501', 'no deleting lessons';
  assert test_helpers.state($q$ insert into public.course_progress (user_id, lesson_id) select 'a0000000-0000-0000-0000-000000000001', id from public.course_lessons limit 1 $q$) = '42501', 'no writing progress directly';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Sneaky","summary":"Sneaky course"}', '[]') $q$) = '42501', 'an owner cannot call the admin functions';
  assert test_helpers.state($q$ select public.admin_delete_course((select id from public.courses limit 1)) $q$) = '42501', 'or delete';
end $$;
:anon
do $$
begin
  assert test_helpers.state($q$ select * from public.courses $q$) = '42501', 'signed out people read nothing';
  assert test_helpers.state($q$ select * from public.course_lessons $q$) = '42501', 'not even lessons';
  assert test_helpers.state($q$ select public.set_lesson_done((select id from public.course_lessons limit 1), true) $q$) = '42501', 'or tick a lesson';
end $$;

-- ---------------------------------------------------------------------------
-- Admin: only a full admin writes
-- ---------------------------------------------------------------------------
:support
do $$
begin
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Support course","summary":"Not allowed"}', '[]') $q$) = '42501', 'support cannot create';
  assert test_helpers.state($q$ select public.admin_set_course_status((select id from public.courses limit 1), 'draft') $q$) = '42501', 'or unpublish';
  assert test_helpers.state($q$ select public.admin_delete_course((select id from public.courses limit 1)) $q$) = '42501', 'or delete';
end $$;
:viewer
do $$
begin
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Viewer course","summary":"Not allowed"}', '[]') $q$) = '42501', 'read only cannot create';
  assert (select count(*) from public.admin_course_v) = 10, 'but can look';
end $$;

:admin
do $$
declare
  c uuid;
  other uuid;
  l1 uuid;
  l2 uuid;
  l3 uuid;
begin
  -- Validation comes back as readable messages, nothing is saved.
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Hi","summary":"Short title"}', '[]') $q$) = '22023', 'title too short';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Nice title","summary":""}', '[]') $q$) = '22023', 'summary needed';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Nice title","summary":"Fine","accent":"green"}', '[]') $q$) = '22023', 'unknown colour';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Nice title","summary":"Fine","art":"unicorn"}', '[]') $q$) = '22023', 'unknown illustration';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Nice title","summary":"Fine","audience":"cats"}', '[]') $q$) = '22023', 'unknown audience';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Nice title","summary":"Fine","status":"published"}', '[]') $q$) = '22023', 'cannot publish with no lessons';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Nice title","summary":"Fine","sort_order":"abc"}', '[]') $q$) = '22023', 'order must be a number';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Nice title","summary":"Fine"}', '[{"title":"A","body":"Text"}]') $q$) = '22023', 'lesson title too short';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Nice title","summary":"Fine"}', '[{"title":"Lesson","body":""}]') $q$) = '22023', 'lesson text needed';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Nice title","summary":"Fine"}', '[{"title":"Lesson","body":"Text","minutes":"99"}]') $q$) = '22023', 'lesson minutes out of range';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Nice title","summary":"Fine","cover_path":"../secret.png"}', '[]') $q$) = '22023', 'cover path cannot climb out';
  assert (select count(*) from public.courses) = 10, 'nothing was saved by the failures';

  -- A new draft course with three lessons.
  c := public.admin_save_course(null,
    '{"title":"Rainy day games","summary":"Fun things to do indoors","audience":"both","level":"beginner","accent":"sky","art":"ball","sort_order":"5"}',
    '[{"title":"Hide and seek","body":"Hide a treat.\n\nTip: start easy.","minutes":"3"},
      {"title":"Find it","body":"Scatter kibble."},
      {"title":"Tug","body":"Use a rope toy."}]');
  perform set_config('test.course', c::text, true);
  assert (select slug from public.courses where id = c) = 'rainy-day-games', 'the address is made from the title';
  assert (select status from public.courses where id = c) = 'draft', 'new courses are drafts unless told otherwise';
  assert (select created_by from public.courses where id = c) = (select id from public.staff_members where user_id = 'a0000000-0000-0000-0000-000000000007'), 'who made it is kept';
  assert (select array_agg(title order by position) from public.course_lessons where course_id = c) = array['Hide and seek', 'Find it', 'Tug'], 'lessons are in order';
  assert (select minutes from public.course_lessons where course_id = c and position = 2) = 2, 'minutes default to 2';
  assert (select lessons from public.admin_course_v where id = c) = 3 and (select minutes from public.admin_course_v where id = c) = 7, 'the console view adds them up';

  -- Another course with the same title gets its own address.
  other := public.admin_save_course(null, '{"title":"Rainy day games","summary":"A second one"}', '[]');
  assert (select slug from public.courses where id = other) = 'rainy-day-games-2', 'addresses stay unique';
  assert public.admin_delete_course(other) is null, 'a course with no cover returns no path';

  assert (select count(*) from public.audit_log where action = 'course.create') = 2, 'creating is audited';
  assert (select details ->> 'title' from public.audit_log where action = 'course.create' order by at desc, id limit 1) is not null, 'with the title';

  select id into l1 from public.course_lessons where course_id = c and position = 1;
  select id into l2 from public.course_lessons where course_id = c and position = 2;
  select id into l3 from public.course_lessons where course_id = c and position = 3;
  perform set_config('test.l1', l1::text, true);
  perform set_config('test.l2', l2::text, true);
  perform set_config('test.l3', l3::text, true);
end $$;

-- Drafts are hidden from people, visible to staff.
:tolu
do $$
begin
  assert (select count(*) from public.courses) = 10, 'a draft is not shown to the public';
  assert not exists (select 1 from public.course_lessons where course_id = current_setting('test.course')::uuid), 'nor its lessons';
  assert test_helpers.state(format($q$ select public.set_lesson_done(%L, true) $q$, current_setting('test.l1'))) = 'P0002', 'and a draft lesson cannot be ticked';
end $$;
:viewer
do $$
begin
  assert (select count(*) from public.courses) = 11, 'staff see drafts';
  assert (select count(*) from public.course_lessons where course_id = current_setting('test.course')::uuid) = 3, 'and their lessons';
end $$;

-- Publishing.
:admin
do $$
begin
  perform public.admin_set_course_status(current_setting('test.course')::uuid, 'published');
  assert (select status from public.courses where id = current_setting('test.course')::uuid) = 'published', 'published';
  assert (select count(*) from public.audit_log where action = 'course.publish') = 1, 'publishing is audited';
  assert test_helpers.state($q$ select public.admin_set_course_status('00000000-0000-0000-0000-00000000dead', 'draft') $q$) = 'P0002', 'an unknown course is not found';
  assert test_helpers.state(format($q$ select public.admin_set_course_status(%L, 'archived') $q$, current_setting('test.course'))) = '22023', 'only draft or published';
end $$;

-- ---------------------------------------------------------------------------
-- Progress
-- ---------------------------------------------------------------------------
:tolu
do $$
begin
  assert (select count(*) from public.courses) = 11, 'now everyone sees it';
  perform public.set_lesson_done(current_setting('test.l1')::uuid, true);
  perform public.set_lesson_done(current_setting('test.l1')::uuid, true);
  perform public.set_lesson_done(current_setting('test.l2')::uuid, true);
  assert (select count(*) from public.course_progress) = 2, 'ticking twice counts once';
  perform public.set_lesson_done(current_setting('test.l2')::uuid, false);
  assert (select count(*) from public.course_progress) = 1, 'a lesson can be unticked';
  perform public.set_lesson_done(current_setting('test.l2')::uuid, true);
  assert test_helpers.state($q$ select public.set_lesson_done('00000000-0000-0000-0000-00000000dead', true) $q$) = 'P0002', 'an unknown lesson is not found';
end $$;
:kemi
do $$
begin
  assert (select count(*) from public.course_progress) = 0, 'nobody sees anyone else''s progress';
  perform public.set_lesson_done(current_setting('test.l3')::uuid, true);
  assert (select count(*) from public.course_progress) = 1, 'Kemi has her own';
end $$;
:admin
do $$
begin
  assert (select learners from public.admin_course_v where id = current_setting('test.course')::uuid) = 2, 'staff see how many people are learning';
end $$;

-- ---------------------------------------------------------------------------
-- Editing: lessons keep their ids (and ticks), reorder, add, remove
-- ---------------------------------------------------------------------------
:admin
do $$
declare
  c uuid := current_setting('test.course')::uuid;
  l1 text := current_setting('test.l1');
  l2 text := current_setting('test.l2');
  l3 text := current_setting('test.l3');
begin
  perform public.admin_save_course(c,
    '{"title":"Rainy day games","summary":"Fun things to do indoors","accent":"mint","art":"ball","status":"published","sort_order":"7"}',
    format('[{"id":"%s","title":"Tug of war","body":"Use a rope toy."},
             {"id":"%s","title":"Hide and seek","body":"Hide a treat.","minutes":"3"},
             {"title":"Brand new lesson","body":"Added later."}]', l3, l1)::jsonb);
  set constraints all immediate;

  assert (select array_agg(title order by position) from public.course_lessons where course_id = c) = array['Tug of war', 'Hide and seek', 'Brand new lesson'],
    'reordered, renamed and added';
  assert (select position from public.course_lessons where id = l3::uuid) = 1 and (select position from public.course_lessons where id = l1::uuid) = 2,
    'kept lessons keep their id';
  assert not exists (select 1 from public.course_lessons where id = l2::uuid), 'the lesson left out is removed';
  assert (select accent from public.courses where id = c) = 'mint' and (select sort_order from public.courses where id = c) = 7, 'the course fields changed';
  assert (select slug from public.courses where id = c) = 'rainy-day-games', 'the address does not change';
  assert (select count(*) from public.audit_log where action = 'course.update') = 1, 'editing is audited';
  assert (select details ->> 'was' from public.audit_log where action = 'course.update') = 'published', 'with the previous status';
  -- A cover path set, kept when left out, and cleared.
  perform public.admin_save_course(c,
    '{"title":"Rainy day games","summary":"Fun things to do indoors","status":"published","cover_path":"covers/rainy.webp"}',
    (select jsonb_agg(jsonb_build_object('id', id, 'title', title, 'body', body)) from public.course_lessons where course_id = c));
  assert (select cover_path from public.courses where id = c) = 'covers/rainy.webp', 'cover set';
  perform public.admin_save_course(c,
    '{"title":"Rainy day games","summary":"Fun things to do indoors","status":"published"}',
    (select jsonb_agg(jsonb_build_object('id', id, 'title', title, 'body', body)) from public.course_lessons where course_id = c));
  assert (select cover_path from public.courses where id = c) = 'covers/rainy.webp', 'left out keeps the cover';
  assert (select count(*) from public.course_lessons where course_id = c) = 3, 'and the lessons';

  -- Taking a course down hides it again but keeps everything.
  perform public.admin_set_course_status(c, 'draft');
  assert (select count(*) from public.audit_log where action = 'course.unpublish') = 1, 'unpublishing is audited';
end $$;
:server
do $$
begin
  -- Progress follows the kept lessons and goes with removed ones (staff cannot read other people's rows, so the server checks).
  assert (select count(*) from public.course_progress where lesson_id = current_setting('test.l1')::uuid) = 1, 'ticks on a kept lesson stay';
  assert (select count(*) from public.course_progress where lesson_id = current_setting('test.l3')::uuid) = 1, 'even after moving';
  assert (select count(*) from public.course_progress where lesson_id = current_setting('test.l2')::uuid) = 0, 'ticks on a removed lesson go';
end $$;
:tolu
do $$
begin
  assert (select count(*) from public.courses) = 10, 'unpublished means gone from the app';
  assert test_helpers.state(format($q$ select public.set_lesson_done(%L, true) $q$, current_setting('test.l3'))) = 'P0002', 'and cannot be ticked';
end $$;

-- ---------------------------------------------------------------------------
-- Deleting a course removes lessons and progress, and returns the cover path
-- ---------------------------------------------------------------------------
:admin
do $$
declare
  c uuid := current_setting('test.course')::uuid;
begin
  assert public.admin_delete_course(c) = 'covers/rainy.webp', 'the cover path comes back for cleaning up';
  assert not exists (select 1 from public.courses where id = c), 'the course is gone';
  assert not exists (select 1 from public.course_lessons where course_id = c), 'with its lessons';
  assert (select details ->> 'title' from public.audit_log where action = 'course.delete' and target_id = c) = 'Rainy day games', 'deleting is audited with the title';
  assert (select count(*) from public.audit_log where action = 'course.delete') = 2, 'both deletions are audited';
  assert test_helpers.state(format($q$ select public.admin_delete_course(%L) $q$, c)) = 'P0002', 'deleting twice is not found';
end $$;
:server
do $$
begin
  assert (select count(*) from public.course_progress) = 0, 'everyone''s ticks for the course went with it';
end $$;

-- ---------------------------------------------------------------------------
-- Deleting an account removes its progress
-- ---------------------------------------------------------------------------
:bola
do $$
begin
  perform public.set_lesson_done((select id from public.course_lessons order by course_id, position limit 1), true);
  assert (select count(*) from public.course_progress) = 1, 'Bola has some progress';
end $$;
:server
do $$
declare
  bola uuid := 'a0000000-0000-0000-0000-000000000006';
  blockers text[];
begin
  select private.deletion_blockers(bola) into blockers;
  if coalesce(array_length(blockers, 1), 0) > 0 then
    raise notice 'Bola has something in flight in the seed (%): the erase path was not tested', array_to_string(blockers, ' ');
    return;
  end if;
  perform public.erase_account(bola);
  assert not exists (select 1 from public.course_progress where user_id = bola), 'progress is erased with the account';
end $$;

do $$ begin raise notice 'Courses tests passed'; end $$;
rollback;
