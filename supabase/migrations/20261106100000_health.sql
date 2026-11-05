-- Health (milestone 2): reminders that follow health records, "mark done" that rolls to the next dose,
-- in app notifications, time limited share links for vets, and emergency vet search.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------
-- Free text "given by" for records the owner adds ("Dr. Amina Bello", "added by you" when empty).
alter table public.health_records
  add column given_by_name text check (char_length(given_by_name) <= 80);

-- Where this person wants reminders. Empty means reminders are off. New records follow this setting.
alter table public.profiles
  add column reminder_channels text[] not null default array['push']
    check (reminder_channels <@ array['push', 'email', 'whatsapp', 'sms']);
grant update (reminder_channels) on public.profiles to authenticated;

-- What a clinic lists about itself, for the emergency vet screen. Business details, not personal ones.
alter table public.partner_accounts
  add column phone text,
  add column open_24h boolean not null default false,
  add column opens_at time,
  add column closes_at time,
  add column emergency_care boolean not null default false,
  add column home_visits boolean not null default false;
grant update (phone, open_24h, opens_at, closes_at, emergency_care, home_visits)
  on public.partner_accounts to authenticated;

-- One reminder per record: it is derived from the record's next due date.
delete from public.reminders r
 using public.reminders keep
 where r.health_record_id is not null
   and r.health_record_id = keep.health_record_id
   and r.id > keep.id;
create unique index reminders_one_per_record on public.reminders (health_record_id)
  where health_record_id is not null;

-- ---------------------------------------------------------------------------
-- Reminders are generated from health records
-- ---------------------------------------------------------------------------
create function private.pet_owner(p_pet uuid) returns uuid
language sql stable security definer
set search_path = ''
as $$ select owner_user_id from public.pets where id = p_pet $$;

-- Runs as the table owner: a vet who adds a record through a share must still create the owner's reminder.
create function private.sync_record_reminder() returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare ch text[];
begin
  select p.reminder_channels into ch
    from public.profiles p where p.user_id = private.pet_owner(new.pet_id);

  if new.next_due_on is null or coalesce(cardinality(ch), 0) = 0 then
    delete from public.reminders where health_record_id = new.id and status <> 'done';
    return new;
  end if;

  insert into public.reminders (pet_id, health_record_id, due_on, channels)
  values (new.pet_id, new.id, new.next_due_on, ch)
  on conflict (health_record_id) where health_record_id is not null
  do update set
    due_on = excluded.due_on,
    channels = excluded.channels,
    -- A finished reminder stays finished unless the date moved.
    status = case when public.reminders.due_on is distinct from excluded.due_on
                  then 'scheduled' else public.reminders.status end;
  return new;
end;
$$;

create trigger sync_record_reminder
  after insert or update of next_due_on on public.health_records
  for each row execute function private.sync_record_reminder();

-- Rebuilds the open reminders when the person changes where they want them.
create function private.rebuild_user_reminders() returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  delete from public.reminders r
   using public.pets p
   where r.pet_id = p.id and p.owner_user_id = new.user_id and r.status = 'scheduled';

  if cardinality(new.reminder_channels) > 0 then
    insert into public.reminders (pet_id, health_record_id, due_on, channels)
    select h.pet_id, h.id, h.next_due_on, new.reminder_channels
      from public.health_records h
      join public.pets p on p.id = h.pet_id
     where p.owner_user_id = new.user_id
       and h.next_due_on is not null
       and not exists (select 1 from public.reminders r where r.health_record_id = h.id)
    on conflict (health_record_id) where health_record_id is not null do nothing;
  end if;
  return new;
end;
$$;

create trigger rebuild_reminders_on_channels
  after update of reminder_channels on public.profiles
  for each row
  when (old.reminder_channels is distinct from new.reminder_channels)
  execute function private.rebuild_user_reminders();

revoke all on function private.pet_owner(uuid), private.sync_record_reminder(),
  private.rebuild_user_reminders() from public, anon;
grant execute on function private.pet_owner(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- create_pet_passport: reminders now come from the trigger above, so this only sets the channels.
-- p_channels null leaves the person's setting alone (adding a second pet).
-- ---------------------------------------------------------------------------
drop function public.create_pet_passport(jsonb, jsonb, text[]);

create function public.create_pet_passport(
  p_pet jsonb,
  p_records jsonb default '[]'::jsonb,
  p_channels text[] default null
) returns public.pets
language plpgsql
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  pet public.pets;
  rec jsonb;
  pet_name text := btrim(coalesce(p_pet ->> 'name', ''));
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if char_length(pet_name) not between 1 and 40 then
    raise exception 'Pet name must be 1 to 40 characters' using errcode = '22023';
  end if;
  if jsonb_typeof(p_records) is distinct from 'array' or jsonb_array_length(p_records) > 20 then
    raise exception 'Records must be a list of at most 20' using errcode = '22023';
  end if;

  if p_channels is not null then
    update public.profiles set reminder_channels = p_channels where user_id = me;
  end if;

  insert into public.pets (owner_user_id, name, species, breed, sex, date_of_birth, photo_path, tag_code)
  values (
    me,
    pet_name,
    p_pet ->> 'species',
    nullif(btrim(coalesce(p_pet ->> 'breed', '')), ''),
    coalesce(nullif(p_pet ->> 'sex', ''), 'unknown'),
    nullif(p_pet ->> 'date_of_birth', '')::date,
    nullif(p_pet ->> 'photo_path', ''),
    private.new_tag_code()
  )
  returning * into pet;

  for rec in select * from jsonb_array_elements(p_records) loop
    if (rec ->> 'next_due_on') is not null and (rec ->> 'given_on') is not null
       and (rec ->> 'next_due_on')::date <= (rec ->> 'given_on')::date then
      raise exception 'The next due date must be after the date given' using errcode = '22023';
    end if;

    insert into public.health_records (pet_id, type, name, given_on, next_due_on, added_by_user_id)
    values (
      pet.id,
      rec ->> 'type',
      btrim(rec ->> 'name'),
      nullif(rec ->> 'given_on', '')::date,
      nullif(rec ->> 'next_due_on', '')::date,
      me
    );
  end loop;

  update public.profiles
     set onboarded_at = coalesce(onboarded_at, now())
   where user_id = me;

  return pet;
end;
$$;
revoke all on function public.create_pet_passport(jsonb, jsonb, text[]) from public, anon;
grant execute on function public.create_pet_passport(jsonb, jsonb, text[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Mark a reminder done: the dose was given. Records the dose and schedules the next one, using the same
-- gap as the dose before (a yearly vaccine stays yearly).
-- ---------------------------------------------------------------------------
create function public.complete_reminder(p_reminder uuid, p_given_on date default null)
returns public.health_records
language plpgsql
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  today date := (now() at time zone 'Africa/Lagos')::date;
  r public.reminders;
  h public.health_records;
  d date;
  gap int;
  fresh public.health_records;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;

  select * into r from public.reminders where id = p_reminder;  -- Row Level Security: only the owner finds it
  if not found then
    raise exception 'Reminder not found' using errcode = '42501';
  end if;
  if r.status = 'done' then
    raise exception 'That reminder is already done' using errcode = '22023';
  end if;

  d := coalesce(p_given_on, today);
  if d > today then
    raise exception 'The date given cannot be in the future' using errcode = '22023';
  end if;

  update public.reminders set status = 'done' where id = r.id;
  if r.health_record_id is null then
    return null;
  end if;

  select * into h from public.health_records where id = r.health_record_id;
  if h.given_on is not null and h.next_due_on is not null then
    gap := greatest(1, (extract(year from age(h.next_due_on, h.given_on)) * 12
                      + extract(month from age(h.next_due_on, h.given_on)))::int);
  end if;

  insert into public.health_records (pet_id, type, name, given_on, next_due_on, added_by_user_id)
  values (
    h.pet_id, h.type, h.name, d,
    case when gap is not null then (d + make_interval(months => gap))::date end,
    me
  )
  returning * into fresh;
  return fresh;
end;
$$;
revoke all on function public.complete_reminder(uuid, date) from public, anon;
grant execute on function public.complete_reminder(uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Notifications (in app). Written by the database; people can only read them and mark them read.
-- ---------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('reminder_due', 'record_verified', 'lost_alert', 'booking', 'community')),
  title text not null,
  body text,
  -- App route to open, for example /schedule.
  link text,
  -- Stops the same thing being announced twice.
  dedupe_key text,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);
create index on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;
create policy "read own notifications" on public.notifications
  for select to authenticated using (user_id = (select auth.uid()));
create policy "mark own notifications read" on public.notifications
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.notifications from anon;
revoke insert, delete on public.notifications from authenticated;
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

-- Announces reminders that are due within a week, due today or tomorrow, or overdue. Safe to call as often as
-- you like: each reminder is announced once per stage. The app calls it when it opens; a scheduled job
-- sending push, WhatsApp and email will call the same logic later.
create function public.generate_my_reminder_notifications() returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  today date := (now() at time zone 'Africa/Lagos')::date;
  n integer;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;

  insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
  select
    me,
    'reminder_due',
    case s.stage
      when 'overdue' then s.label || ' is overdue'
      when 'd1' then s.label || case when s.days = 0 then ' is due today' else ' is due tomorrow' end
      else s.label || ' in ' || s.days || ' days'
    end,
    case s.stage
      when 'overdue' then s.pet || ' was due on ' || to_char(s.due_on, 'FMDD Mon') || '.'
      else 'Book a vet for ' || s.pet || ' before ' || to_char(s.due_on, 'FMDD Mon') || '.'
    end,
    '/schedule',
    'reminder:' || s.id || ':' || s.stage
  from (
    select
      r.id, r.due_on, p.name as pet, (r.due_on - today) as days,
      case when h.type = 'vaccine' and h.name !~* '(booster|vaccine)' then h.name || ' booster'
           else coalesce(h.name, 'Reminder') end as label,
      case
        when r.due_on < today then 'overdue'
        when r.due_on - today <= 1 then 'd1'
        when r.due_on - today <= 7 then 'd7'
      end as stage
    from public.reminders r
    join public.pets p on p.id = r.pet_id
    left join public.health_records h on h.id = r.health_record_id
    where p.owner_user_id = me and r.status = 'scheduled'
  ) s
  where s.stage is not null
  on conflict (user_id, dedupe_key) do nothing;

  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.generate_my_reminder_notifications() from public, anon;
grant execute on function public.generate_my_reminder_notifications() to authenticated;

-- A vet verifying a record tells the owner.
create function private.notify_record_verified() returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  owner uuid := private.pet_owner(new.pet_id);
  vet text;
  pet text;
begin
  if new.verified_by_partner_id is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.verified_by_partner_id is not null then
    return new;
  end if;
  select business_name into vet from public.partner_accounts where id = new.verified_by_partner_id;
  select name into pet from public.pets where id = new.pet_id;
  insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
  values (owner, 'record_verified', 'Record verified',
          coalesce(vet, 'A clinic') || ' verified ' || pet || '''s ' || new.name || '.',
          '/passport', 'verified:' || new.id)
  on conflict (user_id, dedupe_key) do nothing;
  return new;
end;
$$;
create trigger notify_record_verified
  after insert or update of verified_by_partner_id on public.health_records
  for each row execute function private.notify_record_verified();
revoke all on function private.notify_record_verified() from public, anon;

-- ---------------------------------------------------------------------------
-- Share a passport with a vet: a link or QR code that expires. The raw token is shown once, to the owner,
-- and only its hash is stored, so a database leak cannot be turned back into working links.
-- ---------------------------------------------------------------------------
create function public.create_passport_share(
  p_pet uuid,
  p_scopes text[] default array['health'],
  p_hours integer default 24
) returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  token text;
  made public.passport_shares;
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if not private.owns_pet(p_pet) then
    raise exception 'Pet not found' using errcode = '42501';
  end if;
  if p_hours is null or p_hours not between 1 and 168 then
    raise exception 'A share lasts from 1 hour to 7 days' using errcode = '22023';
  end if;
  if p_scopes is null or cardinality(p_scopes) < 1 then
    raise exception 'Share at least one thing' using errcode = '22023';
  end if;

  token := encode(extensions.gen_random_bytes(24), 'hex');
  insert into public.passport_shares (pet_id, token_hash, scopes, expires_at)
  values (
    p_pet,
    encode(extensions.digest(token, 'sha256'), 'hex'),
    p_scopes,
    now() + make_interval(hours => p_hours)
  )
  returning * into made;

  return jsonb_build_object(
    'id', made.id,
    'token', token,
    'expires_at', made.expires_at,
    'scopes', to_jsonb(made.scopes)
  );
end;
$$;
revoke all on function public.create_passport_share(uuid, text[], integer) from public, anon;
grant execute on function public.create_passport_share(uuid, text[], integer) to authenticated;

create function public.revoke_passport_share(p_share uuid) returns void
language plpgsql
set search_path = ''
as $$
begin
  update public.passport_shares
     set revoked_at = now()
   where id = p_share and revoked_at is null;   -- Row Level Security limits this to the owner's pets
  if not found then
    raise exception 'Share not found' using errcode = '42501';
  end if;
end;
$$;
revoke all on function public.revoke_passport_share(uuid) from public, anon;
grant execute on function public.revoke_passport_share(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Emergency vets: approved vets that take emergencies, are open round the clock, or visit homes.
-- Open now ones first, then 24 hour ones, then nearest. Pass the person's position for distances.
-- ---------------------------------------------------------------------------
create function public.emergency_vets(
  p_lat double precision default null,
  p_lng double precision default null,
  p_limit integer default 10
) returns table (
  id uuid,
  business_name text,
  area text,
  phone text,
  open_24h boolean,
  closes_at time,
  home_visits boolean,
  open_now boolean,
  distance_m integer,
  lat double precision,
  lng double precision
)
language sql stable
set search_path = ''
as $$
  with clock as (select (now() at time zone 'Africa/Lagos')::time as t),
  v as (
    select
      a.*,
      (a.open_24h or (
         a.opens_at is not null and a.closes_at is not null and
         case when a.opens_at <= a.closes_at
              then c.t between a.opens_at and a.closes_at
              else c.t >= a.opens_at or c.t <= a.closes_at end
       )) as is_open,
      case when p_lat is not null and p_lng is not null and a.point is not null
           then extensions.st_distance(a.point, extensions.st_point(p_lng, p_lat, 4326)::extensions.geography)::integer
      end as dist
    from public.partner_accounts a
    cross join clock c
    where a.type = 'vet' and a.status = 'approved'
      and (a.emergency_care or a.open_24h or a.home_visits)
  )
  select
    v.id, v.business_name, v.area, v.phone, v.open_24h, v.closes_at, v.home_visits,
    v.is_open, v.dist,
    extensions.st_y(v.point::extensions.geometry),
    extensions.st_x(v.point::extensions.geometry)
  from v
  order by v.is_open desc, v.open_24h desc, v.dist asc nulls last, v.business_name
  limit least(greatest(coalesce(p_limit, 10), 1), 25);
$$;
revoke all on function public.emergency_vets(double precision, double precision, integer) from public, anon;
grant execute on function public.emergency_vets(double precision, double precision, integer) to authenticated;
