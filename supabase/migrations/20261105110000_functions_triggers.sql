-- Helper functions for RLS and triggers.
-- Functions in schema `private` are SECURITY DEFINER so policies can look at other
-- tables without recursing through RLS. They always pin search_path.

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------
create function private.touch_updated_at() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

do $$
declare t text;
begin
  for t in
    select c.table_name
    from information_schema.columns c
    join information_schema.tables tb
      on tb.table_schema = c.table_schema and tb.table_name = c.table_name and tb.table_type = 'BASE TABLE'
    where c.table_schema = 'public' and c.column_name = 'updated_at'
  loop
    execute format(
      'create trigger touch_updated_at before update on public.%I
         for each row execute function private.touch_updated_at()', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Staff and ownership helpers
-- ---------------------------------------------------------------------------
-- True for an active staff member. With `roles`, they must hold one of those
-- roles (full_admin always passes).
create function private.is_staff(roles text[] default null) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.staff_members s
    where s.user_id = (select auth.uid())
      and s.status = 'active'
      and (roles is null or s.role = 'full_admin' or s.role = any (roles))
  );
$$;

create function private.owns_partner(p_partner uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.partner_accounts a
    where a.id = p_partner and a.owner_user_id = (select auth.uid())
  );
$$;

create function private.owns_approved_partner(p_partner uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.partner_accounts a
    where a.id = p_partner and a.owner_user_id = (select auth.uid()) and a.status = 'approved'
  );
$$;

create function private.owns_pet(p_pet uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pets p
    where p.id = p_pet and p.owner_user_id = (select auth.uid())
  );
$$;

-- The previous owner keeps a read only record after a handover.
create function private.was_previous_owner(p_pet uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.ownership_transfers t
    where t.pet_id = p_pet and t.from_user_id = (select auth.uid()) and t.completed_at is not null
  );
$$;

-- A partner I own holds a live (not revoked, not expired) share for this pet.
-- Pass null scope to accept any scope.
create function private.has_active_share(p_pet uuid, p_scope text default null) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.passport_shares s
    join public.partner_accounts a on a.id = s.partner_account_id
    where s.pet_id = p_pet
      and a.owner_user_id = (select auth.uid())
      and a.status = 'approved'
      and s.revoked_at is null
      and s.expires_at > now()
      and (p_scope is null or p_scope = any (s.scopes))
  );
$$;

-- Same, for one named partner (used when a partner writes a record).
create function private.partner_has_active_share(p_pet uuid, p_partner uuid, p_scope text) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.passport_shares s
    join public.partner_accounts a on a.id = s.partner_account_id
    where s.pet_id = p_pet
      and s.partner_account_id = p_partner
      and a.owner_user_id = (select auth.uid())
      and a.status = 'approved'
      and s.revoked_at is null
      and s.expires_at > now()
      and p_scope = any (s.scopes)
  );
$$;

create function private.has_booking_with_pet(p_pet uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.bookings b
    join public.partner_accounts a on a.id = b.partner_account_id
    where b.pet_id = p_pet
      and a.owner_user_id = (select auth.uid())
      and b.status <> 'cancelled'
  );
$$;

-- Pets that are visible to the community: an active lost alert, a live listing
-- or a published public post. Only pet identity is exposed this way, never health.
create function private.pet_is_public(p_pet uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (select 1 from public.lost_alerts l where l.pet_id = p_pet and l.status = 'active')
      or exists (select 1 from public.listings l where l.pet_id = p_pet and l.status in ('live', 'reserved'))
      or exists (
        select 1 from public.posts po
        where po.pet_id = p_pet and po.status = 'published' and po.visibility = 'everyone'
      );
$$;

create function private.can_view_pet(p_pet uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select private.owns_pet(p_pet)
      or private.was_previous_owner(p_pet)
      or private.is_staff()
      or private.has_active_share(p_pet)
      or private.has_booking_with_pet(p_pet)
      or private.pet_is_public(p_pet);
$$;

-- ---------------------------------------------------------------------------
-- Community helpers
-- ---------------------------------------------------------------------------
create function private.is_blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks k
    where (k.user_id = a and k.blocked_user_id = b)
       or (k.user_id = b and k.blocked_user_id = a)
  );
$$;

create function private.in_conversation(p_conversation uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.conversation_members m
    where m.conversation_id = p_conversation and m.user_id = (select auth.uid())
  );
$$;

create function private.my_area() returns text
language sql stable security definer
set search_path = ''
as $$
  select p.area from public.profiles p where p.user_id = (select auth.uid());
$$;

create function private.follows_pet(p_pet uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.follows f
    where f.pet_id = p_pet and f.follower_user_id = (select auth.uid())
  );
$$;

-- Owner of the lost alert's pet, or a user who reported a sighting on it.
create function private.owns_lost_alert(p_alert uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.lost_alerts l
    join public.pets p on p.id = l.pet_id
    where l.id = p_alert and p.owner_user_id = (select auth.uid())
  );
$$;

-- Callers: policies run as the signed in role, so it needs execute. Nobody else.
revoke all on all functions in schema private from public, anon;
grant usage on schema private to authenticated, service_role;
grant execute on all functions in schema private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- New auth user -> empty profile, so the app can always update it.
create function private.handle_new_user() returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id, first_name, last_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', '')
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- Vet verified records cannot be edited or deleted by app users, and nobody can
-- forge the verification fields through the client. Server side code (service
-- role, where auth.uid() is null) is not blocked: vet verification is written there.
create function private.guard_health_record() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.verified_by_partner_id is not null then
      raise exception 'Vet verified records cannot be deleted' using errcode = '42501';
    end if;
    return old;
  end if;

  if old.verified_by_partner_id is not null then
    raise exception 'Vet verified records cannot be changed' using errcode = '42501';
  end if;
  if new.verified_by_partner_id is distinct from old.verified_by_partner_id
     or new.verified_at is distinct from old.verified_at
     or new.given_by_partner_id is distinct from old.given_by_partner_id
     or new.added_by_user_id is distinct from old.added_by_user_id then
    raise exception 'Verification fields cannot be changed' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger guard_health_record
  before update or delete on public.health_records
  for each row execute function private.guard_health_record();

-- Lost alert radius and auto close date come from settings (not hard coded).
create function private.lost_alert_defaults() returns trigger
language plpgsql
set search_path = ''
as $$
declare s public.settings;
begin
  select * into s from public.settings limit 1;
  new.radius_m := coalesce(new.radius_m, s.lost_radius_m);
  new.closes_at := coalesce(new.closes_at, now() + make_interval(days => s.lost_autoclose_days));
  return new;
end;
$$;

create trigger lost_alert_defaults
  before insert on public.lost_alerts
  for each row execute function private.lost_alert_defaults();

-- Closes alerts past closes_at. Schedule this (pg_cron or an edge function cron).
create function private.close_expired_lost_alerts() returns integer
language plpgsql security definer
set search_path = ''
as $$
declare n integer;
begin
  update public.lost_alerts
     set status = 'closed'
   where status = 'active' and closes_at <= now();
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke execute on function private.close_expired_lost_alerts() from authenticated;

-- audit_log is append only.
create function private.audit_log_append_only() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit_log is append only' using errcode = '42501';
end;
$$;

create trigger audit_log_no_change
  before update or delete on public.audit_log
  for each row execute function private.audit_log_append_only();

create trigger audit_log_no_truncate
  before truncate on public.audit_log
  for each statement execute function private.audit_log_append_only();

-- A partner submits their application through this function, so the client never
-- needs write access to `status`.
create function public.submit_partner_application(p_partner uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.partner_accounts
     set status = 'submitted'
   where id = p_partner
     and owner_user_id = (select auth.uid())
     and status in ('draft', 'needs_info');
  if not found then
    raise exception 'Application not found or cannot be submitted' using errcode = '42501';
  end if;
end;
$$;
revoke execute on function public.submit_partner_application(uuid) from public, anon;
grant execute on function public.submit_partner_application(uuid) to authenticated;
