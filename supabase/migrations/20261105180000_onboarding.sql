-- Onboarding (milestone 1): what the owner picked on "How will you use PawPass?", whether they
-- finished setup, and one function that creates a pet's passport, health history and reminders together.

-- ---------------------------------------------------------------------------
-- Profile: account types and onboarding state
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column account_types text[] not null default array['owner']
    check (
      cardinality(account_types) between 1 and 4
      and account_types <@ array['owner', 'provider', 'breeder', 'shelter']
    ),
  add column onboarded_at timestamptz;

-- `account_types` records intent only. Providers, breeders and shelters still apply and pass
-- verification (partner_accounts) before anything goes live.
grant update (account_types, onboarded_at) on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- Pets: let owners read their own row directly. The old policy looked the pet up again by id inside a
-- helper, which cannot see a row that is still being inserted, so `insert ... returning` (what the app
-- and create_pet_passport do) was refused. Who can see what is unchanged.
-- ---------------------------------------------------------------------------
drop policy "view pets you may see" on public.pets;
create policy "view pets you may see" on public.pets
  for select to authenticated
  using (owner_user_id = (select auth.uid()) or private.can_view_pet(id));

-- ---------------------------------------------------------------------------
-- Tag code, like PP-4821-LK (four digits and two letters, no I or O so they are not mistaken for 1 and 0)
-- ---------------------------------------------------------------------------
create function private.new_tag_code() returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  letters constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  n bigint;
  code text;
begin
  loop
    n := ('x' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))::bit(32)::bigint;
    code := 'PP-' || lpad((n % 10000)::text, 4, '0') || '-'
         || substr(letters, 1 + ((n / 10000) % 24)::int, 1)
         || substr(letters, 1 + ((n / 240000) % 24)::int, 1);
    exit when not exists (select 1 from public.pets where tag_code = code);
  end loop;
  return code;
end;
$$;
revoke all on function private.new_tag_code() from public, anon;
grant execute on function private.new_tag_code() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- create_pet_passport: one pet, its past records and the reminders for what is due next.
-- Runs as the caller, so Row Level Security still decides what may be written, and it is a single
-- transaction: either everything is saved or nothing is.
--
--   p_pet      {name, species, breed?, sex?, date_of_birth?, photo_path?}
--   p_records  [{type, name, given_on, next_due_on?}]  (what the owner ticked or scanned)
--   p_channels subset of push, email, whatsapp, sms (empty: no reminders are created)
--
-- The reminder dates come from the app (it owns the vaccine schedule rules); the database checks them.
-- ---------------------------------------------------------------------------
create function public.create_pet_passport(
  p_pet jsonb,
  p_records jsonb default '[]'::jsonb,
  p_channels text[] default array['push']
) returns public.pets
language plpgsql
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  pet public.pets;
  rec jsonb;
  rec_id uuid;
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
    )
    returning id into rec_id;

    if cardinality(p_channels) > 0 and (rec ->> 'next_due_on') is not null then
      insert into public.reminders (pet_id, health_record_id, due_on, channels)
      values (pet.id, rec_id, (rec ->> 'next_due_on')::date, p_channels);
    end if;
  end loop;

  update public.profiles
     set onboarded_at = coalesce(onboarded_at, now())
   where user_id = me;

  return pet;
end;
$$;
revoke all on function public.create_pet_passport(jsonb, jsonb, text[]) from public, anon;
grant execute on function public.create_pet_passport(jsonb, jsonb, text[]) to authenticated;
