-- Courses: short, friendly puppy and dog courses in the app, managed from the admin console.
--
-- Everyone signed in reads published courses and their lessons and keeps their own progress (a tick per lesson).
-- Staff read drafts too. Nobody writes through the client: the admin console calls audited admin_* functions
-- (full admin only), which write the audit log. Cover pictures live in the public `course-covers` bucket; a course
-- without one shows its illustration (`art`) on its colour (`accent`). The ten starter courses are added at the end.
-- Re-creates erase_account so deleting an account also removes its course progress.

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 60),
  title text not null check (char_length(btrim(title)) between 3 and 80),
  summary text not null check (char_length(btrim(summary)) between 3 and 200),
  audience text not null default 'both' check (audience in ('puppy', 'dog', 'both')),
  level text not null default 'beginner' check (level in ('beginner', 'intermediate', 'advanced')),
  accent text not null default 'sunny' check (accent in ('sunny', 'coral', 'tangerine', 'mint', 'sky', 'grape', 'lime', 'rose')),
  art text not null default 'paw' check (art in ('welcome', 'potty', 'sit', 'leash', 'chew', 'social', 'crate', 'recall', 'tricks', 'health', 'ball', 'paw')),
  cover_path text check (cover_path is null or char_length(cover_path) <= 300),
  status text not null default 'draft' check (status in ('draft', 'published')),
  sort_order integer not null default 100 check (sort_order between 0 and 9999),
  created_by uuid references public.staff_members (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.courses (status, sort_order);

create table public.course_lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses (id) on delete cascade,
  position integer not null check (position > 0),
  title text not null check (char_length(btrim(title)) between 2 and 80),
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  minutes integer not null default 2 check (minutes between 1 and 60),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Checked at the end of the saving transaction, so lessons can be reordered in one go.
  constraint course_lessons_position unique (course_id, position) deferrable initially deferred
);

create table public.course_progress (
  user_id uuid not null references auth.users (id) on delete cascade,
  lesson_id uuid not null references public.course_lessons (id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (user_id, lesson_id)
);
create index on public.course_progress (lesson_id);

create trigger touch_updated_at before update on public.courses
  for each row execute function private.touch_updated_at();
create trigger touch_updated_at before update on public.course_lessons
  for each row execute function private.touch_updated_at();

alter table public.courses enable row level security;
alter table public.course_lessons enable row level security;
alter table public.course_progress enable row level security;
revoke all on public.courses, public.course_lessons, public.course_progress from anon, authenticated;
grant select on public.courses, public.course_lessons, public.course_progress to authenticated;

-- A published course is visible to everyone signed in; drafts only to staff.
create function private.course_visible(p_course uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.courses c
    where c.id = p_course and (c.status = 'published' or private.is_staff())
  );
$$;

create policy "read published courses" on public.courses for select to authenticated
  using (status = 'published' or private.is_staff());
create policy "read lessons of visible courses" on public.course_lessons for select to authenticated
  using (private.course_visible(course_id));
create policy "read own course progress" on public.course_progress for select to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Ticking a lesson done (or not) is the only thing a person writes.
-- ---------------------------------------------------------------------------
create function public.set_lesson_done(p_lesson uuid, p_done boolean) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles pr where pr.user_id = me and pr.deleted_at is not null) then
    raise exception 'This account has been deleted' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.course_lessons l join public.courses c on c.id = l.course_id
    where l.id = p_lesson and c.status = 'published'
  ) then
    raise exception 'That lesson is not available' using errcode = 'P0002';
  end if;
  if coalesce(p_done, true) then
    insert into public.course_progress (user_id, lesson_id) values (me, p_lesson) on conflict do nothing;
  else
    delete from public.course_progress where user_id = me and lesson_id = p_lesson;
  end if;
end;
$$;
revoke all on function public.set_lesson_done(uuid, boolean) from public, anon;
grant execute on function public.set_lesson_done(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Admin console
-- ---------------------------------------------------------------------------
create function private.course_learners(p_course uuid) returns integer
language sql stable security definer
set search_path = ''
as $$
  select case when private.is_staff() then
    (select count(distinct p.user_id)::int from public.course_progress p
       join public.course_lessons l on l.id = p.lesson_id where l.course_id = p_course)
  else 0 end;
$$;

create view public.admin_course_v with (security_invoker = true) as
select
  c.id, c.slug, c.title, c.summary, c.audience, c.level, c.accent, c.art, c.cover_path, c.status,
  c.sort_order, c.created_at, c.updated_at,
  (select count(*)::int from public.course_lessons l where l.course_id = c.id) as lessons,
  (select coalesce(sum(l.minutes), 0)::int from public.course_lessons l where l.course_id = c.id) as minutes,
  private.course_learners(c.id) as learners
from public.courses c;

create function private.course_slug(p_title text) returns text
language plpgsql
set search_path = ''
as $$
declare
  base text := left(trim(both '-' from regexp_replace(lower(coalesce(p_title, '')), '[^a-z0-9]+', '-', 'g')), 50);
  candidate text;
  n integer := 1;
begin
  base := trim(both '-' from base);
  if base = '' then
    base := 'course';
  end if;
  candidate := base;
  while exists (select 1 from public.courses where slug = candidate) loop
    n := n + 1;
    candidate := base || '-' || n;
  end loop;
  return candidate;
end;
$$;

-- Creates (p_id null) or updates a course and replaces its lessons. Lessons that carry the id of an existing lesson
-- keep it (and everyone's ticks); lessons left out are removed. A cover_path key left out keeps the cover.
create function public.admin_save_course(p_id uuid, p_course jsonb, p_lessons jsonb) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_staff uuid;
  v_id uuid := p_id;
  v_title text := btrim(coalesce(p_course ->> 'title', ''));
  v_summary text := btrim(coalesce(p_course ->> 'summary', ''));
  v_audience text := coalesce(p_course ->> 'audience', 'both');
  v_level text := coalesce(p_course ->> 'level', 'beginner');
  v_accent text := coalesce(p_course ->> 'accent', 'sunny');
  v_art text := coalesce(p_course ->> 'art', 'paw');
  v_status text := coalesce(p_course ->> 'status', 'draft');
  v_sort integer;
  v_cover text;
  v_lessons jsonb := coalesce(p_lessons, '[]'::jsonb);
  v_old_status text;
  l jsonb;
  i integer := 0;
  v_lid uuid;
  v_keep uuid[] := '{}';
  v_ltitle text;
  v_lbody text;
  v_lmin integer;
begin
  v_staff := private.require_staff(array['full_admin']);

  if jsonb_typeof(v_lessons) <> 'array' then
    raise exception 'The lessons are not valid' using errcode = '22023';
  end if;
  if char_length(v_title) not between 3 and 80 then
    raise exception 'The title needs 3 to 80 characters' using errcode = '22023';
  end if;
  if char_length(v_summary) not between 3 and 200 then
    raise exception 'The short description needs 3 to 200 characters' using errcode = '22023';
  end if;
  if v_audience not in ('puppy', 'dog', 'both') then
    raise exception 'Choose who the course is for' using errcode = '22023';
  end if;
  if v_level not in ('beginner', 'intermediate', 'advanced') then
    raise exception 'Choose a level' using errcode = '22023';
  end if;
  if v_accent not in ('sunny', 'coral', 'tangerine', 'mint', 'sky', 'grape', 'lime', 'rose') then
    raise exception 'Choose a colour from the list' using errcode = '22023';
  end if;
  if v_art not in ('welcome', 'potty', 'sit', 'leash', 'chew', 'social', 'crate', 'recall', 'tricks', 'health', 'ball', 'paw') then
    raise exception 'Choose an illustration from the list' using errcode = '22023';
  end if;
  if v_status not in ('draft', 'published') then
    raise exception 'Status must be draft or published' using errcode = '22023';
  end if;
  begin
    v_sort := coalesce(nullif(p_course ->> 'sort_order', ''), '100')::integer;
  exception when others then
    raise exception 'The order must be a whole number' using errcode = '22023';
  end;
  if v_sort not between 0 and 9999 then
    raise exception 'The order must be between 0 and 9999' using errcode = '22023';
  end if;
  if jsonb_array_length(v_lessons) > 30 then
    raise exception 'A course can have up to 30 lessons' using errcode = '22023';
  end if;
  if v_status = 'published' and jsonb_array_length(v_lessons) = 0 then
    raise exception 'Add at least one lesson before publishing' using errcode = '22023';
  end if;
  if p_course ? 'cover_path' then
    v_cover := nullif(btrim(p_course ->> 'cover_path'), '');
    if v_cover is not null and (char_length(v_cover) > 300 or v_cover like '%..%' or v_cover like '/%') then
      raise exception 'The cover picture path is not valid' using errcode = '22023';
    end if;
  end if;

  -- Check every lesson before anything is written.
  for l in select * from jsonb_array_elements(v_lessons) loop
    if jsonb_typeof(l) <> 'object' then
      raise exception 'The lessons are not valid' using errcode = '22023';
    end if;
    i := i + 1;
    if char_length(btrim(coalesce(l ->> 'title', ''))) not between 2 and 80 then
      raise exception 'Lesson % needs a title of 2 to 80 characters', i using errcode = '22023';
    end if;
    if char_length(btrim(coalesce(l ->> 'body', ''))) not between 1 and 4000 then
      raise exception 'Lesson % needs text of up to 4000 characters', i using errcode = '22023';
    end if;
    begin
      v_lmin := coalesce(nullif(l ->> 'minutes', ''), '2')::integer;
    exception when others then
      raise exception 'Lesson % has a minutes value that is not a number', i using errcode = '22023';
    end;
    if v_lmin not between 1 and 60 then
      raise exception 'Lesson % must take between 1 and 60 minutes', i using errcode = '22023';
    end if;
  end loop;

  if v_id is null then
    insert into public.courses (slug, title, summary, audience, level, accent, art, cover_path, status, sort_order, created_by)
    values (private.course_slug(v_title), v_title, v_summary, v_audience, v_level, v_accent, v_art, v_cover, v_status, v_sort, v_staff)
    returning id into v_id;
    v_old_status := null;
  else
    select status into v_old_status from public.courses where id = v_id for update;
    if not found then
      raise exception 'Course not found' using errcode = 'P0002';
    end if;
    update public.courses
       set title = v_title, summary = v_summary, audience = v_audience, level = v_level, accent = v_accent,
           art = v_art, status = v_status, sort_order = v_sort,
           cover_path = case when p_course ? 'cover_path' then v_cover else cover_path end
     where id = v_id;
  end if;

  i := 0;
  for l in select * from jsonb_array_elements(v_lessons) loop
    i := i + 1;
    v_lid := private.safe_uuid(l ->> 'id');
    v_ltitle := btrim(l ->> 'title');
    v_lbody := btrim(l ->> 'body');
    v_lmin := coalesce(nullif(l ->> 'minutes', ''), '2')::integer;
    if v_lid is not null and exists (select 1 from public.course_lessons x where x.id = v_lid and x.course_id = v_id) then
      update public.course_lessons set position = i, title = v_ltitle, body = v_lbody, minutes = v_lmin where id = v_lid;
    else
      insert into public.course_lessons (course_id, position, title, body, minutes)
      values (v_id, i, v_ltitle, v_lbody, v_lmin) returning id into v_lid;
    end if;
    v_keep := array_append(v_keep, v_lid);
  end loop;
  delete from public.course_lessons where course_id = v_id and not (id = any (v_keep));

  perform private.write_audit(
    case when p_id is null then 'course.create' else 'course.update' end, 'course', v_id,
    jsonb_build_object('title', v_title, 'status', v_status, 'was', v_old_status, 'lessons', i));
  return v_id;
end;
$$;

create function public.admin_set_course_status(p_id uuid, p_status text) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_old text;
  v_title text;
begin
  perform private.require_staff(array['full_admin']);
  if p_status not in ('draft', 'published') then
    raise exception 'Status must be draft or published' using errcode = '22023';
  end if;
  select status, title into v_old, v_title from public.courses where id = p_id for update;
  if not found then
    raise exception 'Course not found' using errcode = 'P0002';
  end if;
  if p_status = 'published' and not exists (select 1 from public.course_lessons where course_id = p_id) then
    raise exception 'Add at least one lesson before publishing' using errcode = '22023';
  end if;
  update public.courses set status = p_status where id = p_id;
  perform private.write_audit('course.' || case when p_status = 'published' then 'publish' else 'unpublish' end,
    'course', p_id, jsonb_build_object('title', v_title, 'was', v_old));
end;
$$;

-- Deletes the course, its lessons and everyone's ticks for it. Returns the cover picture path (or null) so the
-- console can remove that file too.
create function public.admin_delete_course(p_id uuid) returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  v_title text;
  v_cover text;
  v_lessons integer;
begin
  perform private.require_staff(array['full_admin']);
  select title, cover_path into v_title, v_cover from public.courses where id = p_id for update;
  if not found then
    raise exception 'Course not found' using errcode = 'P0002';
  end if;
  select count(*)::int into v_lessons from public.course_lessons where course_id = p_id;
  delete from public.courses where id = p_id;
  perform private.write_audit('course.delete', 'course', p_id, jsonb_build_object('title', v_title, 'lessons', v_lessons));
  return v_cover;
end;
$$;

revoke all on function public.admin_save_course(uuid, jsonb, jsonb), public.admin_set_course_status(uuid, text),
  public.admin_delete_course(uuid) from public, anon;
grant execute on function public.admin_save_course(uuid, jsonb, jsonb), public.admin_set_course_status(uuid, text),
  public.admin_delete_course(uuid) to authenticated;
revoke all on function private.course_visible(uuid), private.course_learners(uuid), private.course_slug(text)
  from public, anon;
grant execute on function private.course_visible(uuid), private.course_learners(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Cover pictures: anyone can see them (the bucket is public); only full admins add, replace or remove them.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('course-covers', 'course-covers', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "full admins manage course covers" on storage.objects for all to authenticated
  using (bucket_id = 'course-covers' and private.is_staff(array['full_admin']))
  with check (bucket_id = 'course-covers' and private.is_staff(array['full_admin']));

-- ---------------------------------------------------------------------------
-- Deleting an account also removes its course progress.
-- ---------------------------------------------------------------------------
do $$
declare
  d text;
  patched text;
begin
  select pg_get_functiondef('public.erase_account(uuid)'::regprocedure) into d;
  if position('course_progress' in d) = 0 then
    patched := replace(d,
      E'  delete from public.device_tokens where user_id = p_user;\n',
      E'  delete from public.device_tokens where user_id = p_user;\n  delete from public.course_progress where user_id = p_user;\n');
    if patched = d then
      raise exception 'erase_account was not changed: the device token line was not found';
    end if;
    execute patched;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- The ten starter courses (published). Safe to run again: only missing courses and lessons are added.
-- ---------------------------------------------------------------------------
insert into public.courses (slug, title, summary, audience, level, accent, art, status, sort_order)
select v.slug, v.title, v.summary, v.audience, v.level, v.accent, v.art, 'published', v.sort_order
from (values
  ($c$welcome-home$c$, $c$Welcome home, puppy$c$, $c$Get your home, your routine and your heart ready for the first week.$c$, 'puppy', 'beginner', 'sunny', 'welcome', 10),
  ($c$potty-training$c$, $c$Potty training made simple$c$, $c$A calm, step by step plan for a puppy who knows where to go.$c$, 'puppy', 'beginner', 'coral', 'potty', 20),
  ($c$first-commands$c$, $c$Sit, down and stay$c$, $c$Your first three commands, taught with treats, patience and tiny wins.$c$, 'both', 'beginner', 'mint', 'sit', 30),
  ($c$loose-lead$c$, $c$Walking nicely on the lead$c$, $c$Enjoy walks without being pulled down the road.$c$, 'both', 'beginner', 'sky', 'leash', 40),
  ($c$gentle-teeth$c$, $c$Gentle teeth: stop the nipping$c$, $c$Understand puppy biting and chewing, and teach a soft mouth.$c$, 'puppy', 'beginner', 'grape', 'chew', 50),
  ($c$meet-the-world$c$, $c$Meet the world: socialising$c$, $c$Help your puppy grow into a calm, confident dog around people, noises and other dogs.$c$, 'puppy', 'beginner', 'lime', 'social', 60),
  ($c$home-alone$c$, $c$Calm when home alone$c$, $c$Crate comfort and gentle practice so being alone feels safe.$c$, 'both', 'intermediate', 'rose', 'crate', 70),
  ($c$come-when-called$c$, $c$Come when called$c$, $c$A rock solid recall, built with games, treats and a happy voice.$c$, 'dog', 'intermediate', 'tangerine', 'recall', 80),
  ($c$fun-tricks$c$, $c$Tricks for fun$c$, $c$Shake hands, spin and play dead: tricks that make rainy days a party.$c$, 'both', 'beginner', 'coral', 'tricks', 90),
  ($c$happy-and-healthy$c$, $c$Happy and healthy$c$, $c$Vaccines, worms, ticks, food and heat: the basics of a healthy dog in Lagos.$c$, 'both', 'beginner', 'mint', 'health', 100)
) as v(slug, title, summary, audience, level, accent, art, sort_order)
on conflict (slug) do nothing;

insert into public.course_lessons (course_id, position, title, body, minutes)
select c.id, v.position, v.title, v.body, v.minutes
from (values
  ($c$welcome-home$c$, 1, $c$Set up a safe space$c$, $c$A puppy explores with their mouth, so get down on the floor and look at your home from their height.

- Hide or lift cables, shoes, remote controls and anything small enough to swallow.
- Keep chocolate, grapes, onions and medicines high up and shut away.
- Pick one quiet corner for a bed, a water bowl and a few safe toys.

Tip: a baby gate or a playpen gives your puppy room to play while keeping them out of trouble.$c$, 1),
  ($c$welcome-home$c$, 2, $c$The first night$c$, $c$Crying on the first nights is normal. Your puppy has just left their mother and brothers and sisters, and everything smells new.

- Put the bed close to yours so they can hear you breathe.
- Take them out for a toilet trip right before bed.
- Keep night time visits calm and boring: no play, no big hello.

Tip: Lagos nights are warm, so skip heavy blankets. A thin cotton cloth is plenty.$c$, 1),
  ($c$welcome-home$c$, 3, $c$A simple daily routine$c$, $c$Puppies feel safe when the day follows a pattern. Most sleep 18 hours or more, so naps are part of the plan.

- Wake up, toilet, breakfast, toilet.
- Short play, then a nap. Repeat through the day.
- Young puppies usually eat three or four small meals a day. Your vet will tell you the right amount.

Tip: tired puppies bite and whine more. When in doubt, nap time.$c$, 1),
  ($c$welcome-home$c$, 4, $c$Meet your vet early$c$, $c$Book a first visit in the first week, even if your puppy looks perfectly well. The vet checks their health, plans vaccines and worming, and answers your questions.

Bring any papers you were given. Then add every vaccine and treatment to your puppy's OurPawPass passport, so reminders reach you before the next one is due.$c$, 1),
  ($c$welcome-home$c$, 5, $c$Gentle handling and a name$c$, $c$Touch your puppy's paws, ears, mouth and tummy for a few seconds at a time and give a small treat each time. This makes future grooming and vet visits much easier.

Teach their name the same way: say it once in a happy voice and reward them when they look at you. Never use their name to tell them off.$c$, 1),
  ($c$potty-training$c$, 1, $c$Why accidents happen$c$, $c$A young puppy has a tiny bladder and little warning. Accidents are not stubbornness. They are part of growing up.

As a rough guide, a puppy can hold on for about one hour for every month of age, plus one. A three month old may manage around four hours, but not overnight at first.

Your job is to take them out before they need to go.$c$, 1),
  ($c$potty-training$c$, 2, $c$The magic moments$c$, $c$Take your puppy to the same spot straight after these four moments:

- Waking up
- Eating or drinking
- Playing
- Just before bed

Say a cue word like "toilet" while they go, then praise and give a treat within three seconds. Quick rewards teach the lesson best.

Tip: stay outside a little longer. Many puppies get distracted and forget why they came.$c$, 1),
  ($c$potty-training$c$, 3, $c$When there is an accident$c$, $c$Never shout, rub their nose in it or punish afterwards. They will not understand, and they may start hiding to go.

If you catch them in the act, make a small noise to interrupt, then carry them to the right spot and reward them there. Clean the place well with an enzyme cleaner from a pet shop, because puppies return to places that still smell like toilet.$c$, 1),
  ($c$potty-training$c$, 4, $c$Flats, balconies and pee pads$c$, $c$Living on a high floor makes frequent trips outside hard. A pee pad or a patch of grass in one fixed place can work well.

Choose one spot and keep it there. Once your puppy is reliable, move the pad a little closer to the door each day, then outside. Keep going outside for walks so they learn that outside is a toilet too.$c$, 1),
  ($c$potty-training$c$, 5, $c$Getting through the night$c$, $c$Pick up the water bowl about an hour before bed and take your puppy out last thing. Many young puppies need one trip in the night. Keep it quiet and short, then straight back to bed.

Most puppies sleep through by four to five months. Stay consistent and it will come.$c$, 1),
  ($c$first-commands$c$, 1, $c$How dogs learn$c$, $c$Dogs repeat what pays off. When your dog does something you like, reward it within two seconds and they will try it again.

- Keep sessions to five minutes.
- Use small, soft treats so you do not fill them up.
- Finish while they are still keen.

Tip: train before a meal, when your dog is hungry and focused.$c$, 1),
  ($c$first-commands$c$, 2, $c$Teach sit$c$, $c$Hold a treat at your dog's nose and slowly lift it over their head. Their bottom drops as they follow it. The moment it touches the floor, say "yes" and give the treat.

Repeat ten times, then add the word "sit" just before the move. Soon you can say it with no treat in your hand.$c$, 1),
  ($c$first-commands$c$, 3, $c$Down and stay$c$, $c$From a sit, bring a treat down to the floor between their paws. When their elbows touch the ground, say "yes" and reward.

For stay, ask for a sit, show your open palm and wait one second before rewarding. Build up slowly: two seconds, five seconds, then one step back. Return to them to reward. Do not call them out of a stay.$c$, 1),
  ($c$first-commands$c$, 4, $c$Make it stick$c$, $c$Practise in different places: the living room, the compound, a quiet street. Dogs do not automatically know a command works everywhere.

Teach a release word like "okay" so they know when they are free to move. Slowly reward less often, and keep a few big prizes for their best tries.$c$, 1),
  ($c$loose-lead$c$, 1, $c$The right gear$c$, $c$A well fitted flat collar or a harness and a lead about two metres long is all you need.

- Avoid choke chains and prong collars. They can hurt your dog's neck.
- Avoid long retractable leads near roads. You cannot pull your dog back fast enough.

Tip: let your puppy wear the collar indoors for a few days before the first walk so it feels normal.$c$, 1),
  ($c$loose-lead$c$, 2, $c$Be a tree$c$, $c$Dogs pull because it works: pulling gets them where they want to go. Make it stop working.

The moment the lead goes tight, stop and stand still like a tree. When it loosens, even a little, say "yes" and walk on. It feels slow at first, but dogs learn quickly that a loose lead means we move.$c$, 1),
  ($c$loose-lead$c$, 3, $c$Reward the right spot$c$, $c$Decide which side your dog walks on and give treats there, right by your leg. Reward often at the start, every few steps, then less as they get the idea.

Change direction when they drift ahead. A friendly "this way" and a turn teaches them to keep an eye on you.$c$, 1),
  ($c$loose-lead$c$, 4, $c$Safe walks in Lagos$c$, $c$Hot pavement can burn paws. Press the back of your hand to the ground for five seconds. If it is too hot for you, it is too hot for them.

- Walk early in the morning or after sunset.
- Carry water and a small bowl.
- Choose quiet streets or your estate roads, away from fast motorbikes and cars.
- Keep your dog on a lead near roads, always.$c$, 1),
  ($c$gentle-teeth$c$, 1, $c$Why puppies bite$c$, $c$Puppies explore with their mouths, and between about three and six months their baby teeth are being replaced, which makes their gums sore. Chewing feels good.

Nipping is normal. Our job is to teach where teeth are allowed and where they are not.$c$, 1),
  ($c$gentle-teeth$c$, 2, $c$Teach a soft mouth$c$, $c$When teeth touch your skin, say "ouch" in a high voice and go still for a moment. A puppy's littermates do the same thing when play gets too rough.

Then hand them a toy to chew instead. If they keep going, calmly step away for 20 seconds and come back. Never hit or hold their mouth shut.$c$, 1),
  ($c$gentle-teeth$c$, 3, $c$Safe things to chew$c$, $c$Always keep a few good chew toys within reach, and swap them so they stay interesting.

- Rubber toys made for dogs, in the right size.
- A wet cloth, twisted and frozen, for sore gums.
- Avoid cooked bones, which can splinter, and anything hard enough to chip a tooth.

Tip: if you can leave a dent in a toy with your fingernail, it is soft enough for teeth.$c$, 1),
  ($c$gentle-teeth$c$, 4, $c$Save your shoes$c$, $c$Management beats nagging. Put shoes, bags and remote controls out of reach, and close doors to rooms you cannot supervise.

If your puppy picks something up, trade it for a treat rather than chasing. Chasing turns it into a great game. If mouthing is hard, painful or comes with growling and stiffening, ask your vet or a trainer for help.$c$, 1),
  ($c$meet-the-world$c$, 1, $c$Why it matters so much$c$, $c$The first few months are when puppies learn what is normal. Good experiences now mean a relaxed dog later. Bad or missed experiences can lead to fear.

Your puppy does not need to meet everyone. They need calm, positive tastes of the world.$c$, 1),
  ($c$meet-the-world$c$, 2, $c$Vaccines and going out$c$, $c$Until your puppy is fully vaccinated, avoid the ground in public places and dogs you do not know. Ask your vet when it is safe.

In the meantime you can carry your puppy to see the street, sit with them in a quiet corner of a friend's compound, or invite calm, healthy, vaccinated dogs and visitors to your home.$c$, 1),
  ($c$meet-the-world$c$, 3, $c$Sounds and surfaces$c$, $c$Lagos is loud, and that is a good thing to prepare for. Play recordings of generators, horns, thunder and music at a low volume while your puppy eats or plays, and slowly raise it.

Let them walk on tiles, grass, sand, stairs and a wobbly board. Reward every brave step.$c$, 1),
  ($c$meet-the-world$c$, 4, $c$Meeting people and dogs$c$, $c$Let your puppy choose to approach. Ask visitors to stay calm, offer a treat and avoid grabbing or leaning over.

With other dogs, choose gentle, friendly and vaccinated ones. Keep the first meeting short, with loose leads, then walk away together.

Tip: signs of worry include a tucked tail, yawning, lip licking and turning away. Give space when you see them.$c$, 1),
  ($c$meet-the-world$c$, 5, $c$Keep it happy$c$, $c$Short and sweet wins. If your puppy seems unsure, move further away and try again another day.

Every new thing should come with a treat or a play. Aim for a few new, happy experiences every day.$c$, 1),
  ($c$home-alone$c$, 1, $c$The crate as a cosy den$c$, $c$A crate can be a safe, quiet bedroom, never a punishment. Choose one big enough for your dog to stand up, turn around and lie down.

Start with the door open. Toss treats inside, feed meals in there and put a soft cloth in the corner. Close the door for a few seconds at a time and build up slowly.

Tip: never leave a puppy in a crate for longer than they can hold their bladder.$c$, 1),
  ($c$home-alone$c$, 2, $c$Practise short goodbyes$c$, $c$Start with one minute out of sight, then come back and say nothing special. Slowly build to five minutes, ten and longer over days and weeks.

Keep leaving and arriving calm. Big, emotional goodbyes teach your dog that being alone is a big deal.$c$, 1),
  ($c$home-alone$c$, 3, $c$Keep their mind busy$c$, $c$Something to do makes alone time easier.

- A lick mat spread with a little plain yoghurt or mashed banana.
- A hollow rubber toy stuffed with their kibble.
- A short walk and play session before you go, so they are ready to rest.$c$, 1),
  ($c$home-alone$c$, 4, $c$Heat, power cuts and safety$c$, $c$In Lagos, a closed room can become dangerous when the fan or air conditioning stops. Choose a well ventilated spot with shade and fresh water.

Never leave a dog in a parked car, even for a few minutes with the windows open. If your dog howls non stop, damages doors or drools heavily when you leave, speak to your vet or a trainer about separation anxiety.$c$, 1),
  ($c$come-when-called$c$, 1, $c$Pick a happy word$c$, $c$Choose a short word like "here" or a whistle. Only ever use it for good things: treats, games and cuddles.

If you call your dog and then do something unpleasant, such as ending the walk or giving a bath, they will learn to ignore you.$c$, 1),
  ($c$come-when-called$c$, 2, $c$Start inside$c$, $c$Begin in a quiet room. Say the word, then show a treat and step backwards so your dog runs to you. Give them a party: lots of praise and three treats, one at a time.

Practise ten times a day across the house until they come every time, then move to the compound.$c$, 1),
  ($c$come-when-called$c$, 3, $c$Add distance and distractions$c$, $c$Use a long line of five to ten metres in an enclosed space. Call, and gently guide them in if they ignore you. Reward every success.

Make it harder one step at a time: more distance first, then a toy on the ground, then another person. If they fail, go back one step.$c$, 1),
  ($c$come-when-called$c$, 4, $c$Never chase, and stay safe$c$, $c$If your dog runs off, do not chase. Dogs love a chase. Turn and run the other way, crouch down and call in a happy voice, or hide behind something.

Recall is training, not a guarantee. Keep your dog on a lead near roads and in unfamiliar places, however good their recall is.$c$, 1),
  ($c$fun-tricks$c$, 1, $c$Why teach tricks$c$, $c$Tricks are brain games. They tire your dog out, build your bond and help shy dogs feel brave.

They are also the best way to show off. Keep every session short, around five minutes, and finish on something they find easy.$c$, 1),
  ($c$fun-tricks$c$, 2, $c$Shake hands$c$, $c$Ask your dog to sit. Hold a treat in a closed fist near the floor in front of their paw. Most dogs will paw at it. The moment a paw lifts, say "yes" and open your hand for the treat.

After a few tries, add the word "shake" and offer your open palm instead.$c$, 1),
  ($c$fun-tricks$c$, 3, $c$Spin$c$, $c$Hold a treat at your dog's nose and slowly draw a circle around their body. They will follow it in a spin. Reward at the end of the circle.

When it is smooth, add the word "spin" and make the circle smaller until a small hand signal is enough.$c$, 1),
  ($c$fun-tricks$c$, 4, $c$Play dead$c$, $c$From a down, hold a treat by their shoulder and move it toward their back so they roll onto one hip. As they roll, say "yes" and give the treat.

Add the cue "bang" or "play dead" once it is reliable. Go slowly and use a soft surface, especially for older dogs or dogs with sore joints.

Tip: stop when your dog loses interest. Tricks should always feel like play.$c$, 1),
  ($c$happy-and-healthy$c$, 1, $c$Vaccines and rabies$c$, $c$Puppies need a series of vaccines, then regular boosters. Your vet will plan these and protect against dangerous diseases such as distemper and parvovirus, and against rabies, which is deadly and spreads to people.

Keep every vaccine and booster in your pet's OurPawPass passport and turn on reminders, so none are missed.$c$, 1),
  ($c$happy-and-healthy$c$, 2, $c$Worms, ticks and fleas$c$, $c$Worms, ticks and fleas are common in Nigeria. Ticks in particular can spread serious illnesses.

- Deworm and use tick and flea treatment on the schedule your vet gives you.
- Check your dog's ears, paws and skin folds after walks.
- Wash bedding often and tidy long grass around your home.

Tip: use products made for dogs only. Some treatments for other animals are harmful to dogs.$c$, 1),
  ($c$happy-and-healthy$c$, 3, $c$Food and water$c$, $c$Choose a complete food that suits your dog's age and size, and ask your vet how much to give. Keep fresh water out at all times.

Never give chocolate, grapes and raisins, onions, garlic, cooked bones or anything sweetened with xylitol. If your dog eats any of them, call your vet straight away.$c$, 1),
  ($c$happy-and-healthy$c$, 4, $c$Keeping cool in the heat$c$, $c$Dogs cannot sweat like us, so heat can become an emergency fast.

- Always provide shade, airflow and water.
- Walk in the cool of the morning or evening.
- Never leave a dog in a parked car.
- Flat faced breeds such as bulldogs and pugs struggle most.

Heavy panting, drooling, weakness or collapse means heatstroke. Move to shade, wet them with cool, not icy, water and go to a vet immediately.$c$, 1),
  ($c$happy-and-healthy$c$, 5, $c$When to call the vet$c$, $c$Trust your instincts. You know your dog best. Call a vet quickly if you see:

- Repeated vomiting or diarrhoea, or blood in either
- A swollen, hard tummy
- Not eating or drinking for a day
- Trouble breathing, collapse or a seizure
- Pale gums or severe pain

Use Emergency vets in the OurPawPass app to find the nearest clinic. These courses are friendly guides, not a replacement for your vet.$c$, 1)
) as v(slug, position, title, body, minutes)
join public.courses c on c.slug = v.slug
where not exists (select 1 from public.course_lessons x where x.course_id = c.id);
