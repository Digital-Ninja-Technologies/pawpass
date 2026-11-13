-- Courses: who reads what, drafts, free and paid courses (locked lesson text, previews, buying, confirming payment),
-- saving and reordering lessons, progress, publish and delete, the audit trail, and what deleting an account removes.
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
  assert (select count(*) from public.courses) = 11, 'eleven starter courses';
  assert (select count(*) from public.courses where status = 'published') = 10, 'ten are published';
  assert (select count(*) from public.courses where price_kobo = 0) = 10, 'ten are free';
  assert (select status from public.courses where slug = 'first-year') = 'draft', 'the paid one waits as a draft until its price is set';
  assert (select price_kobo from public.courses where slug = 'first-year') = 250000, 'and starts at N2,500';
  assert not exists (select 1 from public.courses c where not exists (select 1 from public.course_lessons l where l.course_id = c.id)),
    'every course has lessons';
  assert (select count(*) from public.course_lessons) = 50, 'fifty lessons';
  assert (select count(*) from public.course_lesson_text) = 50, 'each with its text';
  assert (select count(*) from public.course_lessons where preview) = 1, 'one free preview';
  assert (select c.slug from public.course_lessons l join public.courses c on c.id = l.course_id where l.preview) = 'first-year', 'in the paid course';
  assert not exists (select 1 from public.course_lesson_text where body ~ E'\u2014') and not exists (select 1 from public.course_lessons where title ~ E'\u2014'), 'no em dashes in the copy';
  assert (select count(distinct sort_order) from public.courses) = 11, 'each course has its own place in the order';
  assert (select audience from public.courses where slug = 'potty-training') = 'puppy', 'potty training is for puppies';
  assert (select count(*) from public.courses where audience in ('dog', 'both')) >= 5, 'there are courses for grown dogs too';
end $$;

-- ---------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------
:tolu
do $$
begin
  assert (select count(*) from public.courses) = 10, 'a signed in person reads the published courses (not the draft)';
  assert (select count(*) from public.course_lessons) = 44, 'and their lessons';
  assert (select count(*) from public.course_lesson_text) = 44, 'and the text of free courses';
  assert (select count(*) from public.admin_course_v) = 10, 'the view only shows what they may read';
  assert (select max(learners) from public.admin_course_v) = 0, 'but never learner counts';
  assert test_helpers.state($q$ insert into public.courses (slug, title, summary) values ('mine', 'My course', 'Not allowed') $q$) = '42501', 'no writing courses';
  assert test_helpers.state($q$ update public.courses set title = 'Hacked title' $q$) = '42501', 'no editing courses';
  assert test_helpers.state($q$ delete from public.course_lessons $q$) = '42501', 'no deleting lessons';
  assert test_helpers.state($q$ insert into public.course_lesson_text (lesson_id, body) select id, 'x' from public.course_lessons limit 1 $q$) = '42501', 'no writing lesson text';
  assert test_helpers.state($q$ insert into public.course_purchases (user_id, course_title, amount_kobo, paystack_reference) values ('a0000000-0000-0000-0000-000000000001', 'Free', 100, 'pc_x') $q$) = '42501', 'no writing purchases';
  assert test_helpers.state($q$ select public.confirm_course_payment('pc_x', 1) $q$) = '42501', 'no confirming payments';
  assert test_helpers.state($q$ insert into public.course_progress (user_id, lesson_id) select 'a0000000-0000-0000-0000-000000000001', id from public.course_lessons limit 1 $q$) = '42501', 'no writing progress directly';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Sneaky","summary":"Sneaky course"}', '[]') $q$) = '42501', 'an owner cannot call the admin functions';
  assert test_helpers.state($q$ select public.admin_delete_course((select id from public.courses limit 1)) $q$) = '42501', 'or delete';
end $$;
:anon
do $$
begin
  assert test_helpers.state($q$ select * from public.courses $q$) = '42501', 'signed out people read nothing';
  assert test_helpers.state($q$ select * from public.course_lessons $q$) = '42501', 'not even lessons';
  assert test_helpers.state($q$ select * from public.course_lesson_text $q$) = '42501', 'or their text';
  assert test_helpers.state($q$ select * from public.course_purchases $q$) = '42501', 'or purchases';
  assert test_helpers.state($q$ select public.create_course_purchase((select id from public.courses limit 1)) $q$) = '42501', 'or buy';
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
  assert (select count(*) from public.admin_course_v) = 11, 'but can look (drafts too)';
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
  assert (select count(*) from public.courses) = 11, 'nothing was saved by the failures';

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
  assert not exists (select 1 from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = current_setting('test.course')::uuid), 'nor its text';
  assert test_helpers.state(format($q$ select public.set_lesson_done(%L, true) $q$, current_setting('test.l1'))) = 'P0002', 'and a draft lesson cannot be ticked';
end $$;
:viewer
do $$
begin
  assert (select count(*) from public.courses) = 12, 'staff see drafts';
  assert (select count(*) from public.course_lessons where course_id = current_setting('test.course')::uuid) = 3, 'and their lessons';
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = current_setting('test.course')::uuid) = 3, 'and the text';
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
    (select jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'body', t.body) order by l.position) from public.course_lessons l join public.course_lesson_text t on t.lesson_id = l.id where l.course_id = c));
  assert (select cover_path from public.courses where id = c) = 'covers/rainy.webp', 'cover set';
  perform public.admin_save_course(c,
    '{"title":"Rainy day games","summary":"Fun things to do indoors","status":"published"}',
    (select jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'body', t.body) order by l.position) from public.course_lessons l join public.course_lesson_text t on t.lesson_id = l.id where l.course_id = c));
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
-- Free and paid courses: price rules, locked text, free previews, buying, confirming, owning
-- ---------------------------------------------------------------------------
:admin
do $$
declare
  c uuid;
begin
  -- Price rules: free (0), or N100 to N1,000,000 in kobo.
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Cheap course","summary":"Too cheap","price_kobo":"5000"}', '[]') $q$) = '22023', 'a price under N100 is refused';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Dear course","summary":"Too dear","price_kobo":"100000001"}', '[]') $q$) = '22023', 'and one over N1,000,000';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Odd course","summary":"Odd price","price_kobo":"abc"}', '[]') $q$) = '22023', 'and one that is not a number';
  assert test_helpers.state($q$ select public.admin_save_course(null, '{"title":"Free course","summary":"Costs nothing","price_kobo":"0"}', '[]') $q$) is not null, 'a free course saves';
  assert (select count(*) from public.audit_log where action = 'course.create' and details ->> 'price_kobo' = '0') >= 1, 'the price is in the audit log';

  -- Publish the paid starter course (it was a draft) and tick a preview flag on a new lesson through the console function.
  perform public.admin_set_course_status((select id from public.courses where slug = 'first-year'), 'published');
  c := public.admin_save_course(null,
    '{"title":"Extra paid course","summary":"A small paid course","price_kobo":"150000","status":"published"}',
    '[{"title":"Free taste","body":"Open to everyone.","preview":true},{"title":"The rest","body":"Only for buyers."}]');
  perform set_config('test.paid', c::text, true);
  assert (select price_kobo from public.courses where id = c) = 150000, 'a paid course is saved with its price';
  assert (select array_agg(preview order by position) from public.course_lessons where course_id = c) = array[true, false], 'and which lesson is a free preview';
  assert (select details ->> 'price_kobo' from public.audit_log where action = 'course.create' and target_id = c) = '150000', 'the audit log has the price';
  perform set_config('test.fy1', (select l.id::text from public.course_lessons l join public.courses x on x.id = l.course_id where x.slug = 'first-year' and l.position = 1), true);
  perform set_config('test.fy2', (select l.id::text from public.course_lessons l join public.courses x on x.id = l.course_id where x.slug = 'first-year' and l.position = 2), true);
  perform set_config('test.fy', (select id::text from public.courses where slug = 'first-year'), true);
  assert (select buyers from public.admin_course_v where slug = 'first-year') = 0, 'nobody has bought it yet';
end $$;

:tolu
do $$
declare
  fy uuid := current_setting('test.fy')::uuid;
  ref text;
  intent jsonb;
begin
  assert (select count(*) from public.courses where price_kobo > 0) = 2, 'the paid courses are visible in the list';
  assert (select count(*) from public.course_lessons where course_id = fy) = 6, 'with all their lesson titles';
  -- Only the free preview's text can be read.
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = fy) = 1, 'but only one lesson of text';
  assert exists (select 1 from public.course_lesson_text where lesson_id = current_setting('test.fy1')::uuid), 'the free preview';
  assert not exists (select 1 from public.course_lesson_text where lesson_id = current_setting('test.fy2')::uuid), 'not the locked lessons';
  assert (select count(*) from public.course_lesson_text) = 44 + 1 + 1, 'free courses stay open to read, plus the two previews';
  assert (select max(buyers) from public.admin_course_v) = 0 and (select max(revenue_kobo) from public.admin_course_v) = 0, 'people never see sales figures';

  -- Ticking: the preview, yes; a locked lesson, no.
  perform public.set_lesson_done(current_setting('test.fy1')::uuid, true);
  assert test_helpers.state(format($q$ select public.set_lesson_done(%L, true) $q$, current_setting('test.fy2'))) = 'P0001', 'a locked lesson cannot be ticked';

  -- Buying rules.
  assert test_helpers.state($q$ select public.create_course_purchase((select id from public.courses where slug = 'potty-training')) $q$) = 'P0001', 'a free course cannot be bought';
  assert test_helpers.state($q$ select public.create_course_purchase('00000000-0000-0000-0000-00000000dead') $q$) = 'P0002', 'an unknown course is not found';

  intent := public.create_course_purchase(fy);
  ref := intent ->> 'reference';
  assert ref like 'pc\_%' and char_length(ref) = 35, 'the reference starts pc_ and is unique';
  assert (intent ->> 'amount_kobo')::bigint = 250000, 'the price comes from the course';
  assert public.create_course_purchase(fy) ->> 'reference' = ref, 'tapping Buy twice gives the same open payment';
  assert (select count(*) from public.course_purchases) = 1, 'and only one row';
  assert (select status from public.course_purchases) = 'pending_payment', 'waiting for payment';
  assert (select course_title from public.course_purchases) = 'Your puppy''s first year', 'the title is copied for the record';
  perform set_config('test.ref', ref, true);
  -- Still locked until Paystack confirms.
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = fy) = 1, 'asking to buy unlocks nothing';
end $$;

:kemi
do $$
begin
  assert (select count(*) from public.course_purchases) = 0, 'nobody sees anyone else''s purchases';
end $$;

:server
do $$
declare
  ref text := current_setting('test.ref');
begin
  assert test_helpers.state(format($q$ select public.confirm_course_payment(%L, 249999) $q$, ref)) = 'P0001', 'the wrong amount is refused';
  assert test_helpers.state($q$ select public.confirm_course_payment('pc_nope', 250000) $q$) = 'P0002', 'an unknown reference is not found';
  assert (select status from public.course_purchases where paystack_reference = ref) = 'pending_payment', 'nothing changed by the failures';
  assert public.confirm_course_payment(ref, 250000) ->> 'result' = 'paid', 'the right amount is accepted';
  assert public.confirm_course_payment(ref, 250000) ->> 'result' = 'already_paid', 'a repeat from Paystack is harmless';
  assert (select count(*) from public.course_purchases where status = 'paid') = 1, 'and still one paid purchase';
  assert (select paid_at from public.course_purchases where paystack_reference = ref) is not null, 'the time is kept';
end $$;

:tolu
do $$
declare
  fy uuid := current_setting('test.fy')::uuid;
begin
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = fy) = 6, 'after paying, all six lessons can be read';
  perform public.set_lesson_done(current_setting('test.fy2')::uuid, true);
  assert (select count(*) from public.course_progress) = 2, 'and ticked';
  assert test_helpers.state(format($q$ select public.create_course_purchase(%L) $q$, fy)) = 'P0001', 'you cannot buy it twice';
  assert (select count(*) from public.course_lesson_text) = 44 + 6 + 1, 'the other paid course is still locked except its preview';
end $$;

:kemi
do $$
declare
  fy uuid := current_setting('test.fy')::uuid;
begin
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = fy) = 1, 'someone else who has not paid is still locked out';
  -- Kemi starts paying, then the price changes while her payment is open.
  perform set_config('test.kemi_ref_a', public.create_course_purchase(fy) ->> 'reference', true);
end $$;

:admin
do $$
declare
  fy uuid := current_setting('test.fy')::uuid;
begin
  assert (select buyers from public.admin_course_v where id = fy) = 1 and (select revenue_kobo from public.admin_course_v where id = fy) = 250000, 'sales show one buyer and N2,500';
  assert (select buyers from public.admin_course_v where slug = 'potty-training') = 0, 'free courses have no sales';
  -- A bought course cannot be deleted; it can be unpublished.
  assert test_helpers.state(format($q$ select public.admin_delete_course(%L) $q$, fy)) = 'P0001', 'a bought course cannot be deleted';
  assert (select count(*) from public.courses where id = fy) = 1, 'it is still there';
  -- Change the price: payments already open keep their price, new ones use the new price.
  perform public.admin_save_course(fy,
    '{"title":"Your puppy''s first year","summary":"A plan from eight weeks to twelve months.","audience":"puppy","level":"intermediate","accent":"tangerine","art":"ball","status":"published","price_kobo":"300000"}',
    (select jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'body', t.body, 'minutes', l.minutes, 'preview', l.preview) order by l.position)
       from public.course_lessons l join public.course_lesson_text t on t.lesson_id = l.id where l.course_id = fy));
  assert (select price_kobo from public.courses where id = fy) = 300000, 'the price changed';
  assert (select details ->> 'was_price_kobo' from public.audit_log where action = 'course.update' and target_id = fy order by at desc, id limit 1) = '250000', 'the audit log has the old price too';
  assert (select count(*) from public.course_lessons where course_id = fy and preview) = 1, 'the preview flag survived the save';
end $$;

:kemi
do $$
declare
  fy uuid := current_setting('test.fy')::uuid;
  b text;
begin
  b := public.create_course_purchase(fy) ->> 'reference';
  assert b <> current_setting('test.kemi_ref_a'), 'a new price means a new payment';
  assert (select amount_kobo from public.course_purchases where paystack_reference = b) = 300000, 'at the new price';
  assert (select amount_kobo from public.course_purchases where paystack_reference = current_setting('test.kemi_ref_a')) = 250000, 'while the open one keeps the old price';
  perform set_config('test.kemi_ref_b', b, true);
end $$;

:server
do $$
declare
  fy uuid := current_setting('test.fy')::uuid;
  kemi uuid := 'a0000000-0000-0000-0000-000000000005';
begin
  assert test_helpers.state(format($q$ select public.confirm_course_payment(%L, 300000) $q$, current_setting('test.kemi_ref_a'))) = 'P0001', 'the old payment cannot be settled at the new price';
  assert public.confirm_course_payment(current_setting('test.kemi_ref_a'), 250000) ->> 'result' = 'paid', 'it settles at its own price';
  -- She paid the second one too: both are recorded, only one owns the course.
  assert public.confirm_course_payment(current_setting('test.kemi_ref_b'), 300000) ->> 'result' = 'paid', 'a second payment for the same course is still recorded';
  assert (select count(*) from public.course_purchases where user_id = kemi and status = 'paid') = 2, 'both payments are on record';
  assert (select count(*) from public.course_purchases where user_id = kemi and status = 'paid' and course_id = fy) = 1, 'but only one grants the course';
end $$;
:kemi
do $$
declare
  fy uuid := current_setting('test.fy')::uuid;
begin
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = fy) = 6, 'Kemi can read it all now';
end $$;

-- Unpublishing hides a bought course and its lessons from everyone (owners keep the purchase).
:admin
do $$
begin
  perform public.admin_set_course_status(current_setting('test.fy')::uuid, 'draft');
end $$;
:tolu
do $$
begin
  assert (select count(*) from public.courses where id = current_setting('test.fy')::uuid) = 0, 'an unpublished course is gone from the app even for its buyer';
  assert test_helpers.state(format($q$ select public.set_lesson_done(%L, true) $q$, current_setting('test.fy2'))) = 'P0002', 'and cannot be ticked';
  assert (select count(*) from public.course_purchases) = 1, 'but the purchase is still theirs';
end $$;
:admin
do $$
begin
  perform public.admin_set_course_status(current_setting('test.fy')::uuid, 'published');
end $$;
:tolu
do $$
begin
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = current_setting('test.fy')::uuid) = 6, 'publishing it again gives the buyer everything back';
end $$;

-- Making a paid course free opens it to everyone.
:admin
do $$
declare
  c uuid := current_setting('test.paid')::uuid;
begin
  perform public.admin_save_course(c,
    '{"title":"Extra paid course","summary":"A small paid course","price_kobo":"0","status":"published"}',
    (select jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'body', t.body, 'minutes', l.minutes, 'preview', l.preview) order by l.position)
       from public.course_lessons l join public.course_lesson_text t on t.lesson_id = l.id where l.course_id = c));
end $$;
:bola
do $$
begin
  assert (select count(*) from public.course_lesson_text t join public.course_lessons l on l.id = t.lesson_id where l.course_id = current_setting('test.paid')::uuid) = 2, 'a course made free can be read by everyone';
  assert test_helpers.state(format($q$ select public.create_course_purchase(%L) $q$, current_setting('test.paid'))) = 'P0001', 'and no longer sold';
end $$;
:admin
do $$
begin
  -- Nobody bought it, so it can go.
  assert public.admin_delete_course(current_setting('test.paid')::uuid) is null, 'a paid course nobody bought can be deleted';
end $$;

-- ---------------------------------------------------------------------------
-- Deleting an account removes its progress and keeps its payment record
-- ---------------------------------------------------------------------------
:bola
do $$
begin
  perform public.set_lesson_done((select l.id from public.course_lessons l join public.courses c on c.id = l.course_id where c.price_kobo = 0 order by c.sort_order, l.position limit 1), true);
  assert (select count(*) from public.course_progress) = 1, 'Bola has some progress';
  perform set_config('test.bola_ref', public.create_course_purchase(current_setting('test.fy')::uuid) ->> 'reference', true);
end $$;
:server
do $$
declare
  bola uuid := 'a0000000-0000-0000-0000-000000000006';
  blockers text[];
begin
  perform public.confirm_course_payment(current_setting('test.bola_ref'), 300000);
  select private.deletion_blockers(bola) into blockers;
  if coalesce(array_length(blockers, 1), 0) > 0 then
    raise notice 'Bola has something in flight in the seed (%): the erase path was not tested', array_to_string(blockers, ' ');
    return;
  end if;
  perform public.erase_account(bola);
  assert not exists (select 1 from public.course_progress where user_id = bola), 'progress is erased with the account';
  assert (select count(*) from public.course_purchases where user_id = bola and status = 'paid') = 1, 'the payment record stays, like other payments';
end $$;

do $$ begin raise notice 'Courses tests passed'; end $$;
rollback;
