-- Pet removal, tightened (follows 20261120100000_remove_pet.sql).
--
--   * Removing a pet that has a vet verified record failed: the guard on health records refuses to delete a verified
--     record, and deleting the pet cascades to its records. remove_pet now tells the guard which pet is being removed
--     (a setting that lasts only for its own transaction), so that pet's records can go with it, and nothing else can.
--   * A pet with a live listing is refused ("take the listing down first"). Before, the pet row was emptied while the
--     listing stayed live.
--   * A removed (emptied) pet is invisible and read only to everyone but staff: the owner shortcut in the read and edit
--     rules, owns_pet and can_view_pet all stop at removed_at. A public post or an old share can no longer expose it.
--   * The old "delete own pet" rule is dropped, so the only way to remove a pet is remove_pet and its checks.

create or replace function private.owns_pet(p_pet uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pets p
    where p.id = p_pet and p.owner_user_id = (select auth.uid()) and p.removed_at is null
  );
$$;

create or replace function private.can_view_pet(p_pet uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select private.is_staff()
      or (
        exists (select 1 from public.pets p where p.id = p_pet and p.removed_at is null)
        and (
          private.owns_pet(p_pet)
          or private.was_previous_owner(p_pet)
          or private.has_active_share(p_pet)
          or private.has_booking_with_pet(p_pet)
          or private.pet_is_public(p_pet)
        )
      );
$$;

drop policy "view pets you may see" on public.pets;
create policy "view pets you may see" on public.pets
  for select to authenticated
  using ((owner_user_id = (select auth.uid()) and removed_at is null) or private.can_view_pet(id));

drop policy "edit own pet" on public.pets;
create policy "edit own pet" on public.pets
  for update to authenticated
  using (owner_user_id = (select auth.uid()) and removed_at is null)
  with check (owner_user_id = (select auth.uid()) and removed_at is null);

drop policy "delete own pet" on public.pets;
revoke delete on public.pets from authenticated, anon;

create or replace function private.guard_health_record() returns trigger
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
    if old.verified_by_partner_id is not null
       and coalesce(current_setting('private.removing_pet', true), '') is distinct from old.pet_id::text then
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

create or replace function public.remove_pet(p_pet uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Sign in first' using errcode = '28000';
  end if;
  if not exists (select 1 from public.pets p where p.id = p_pet and p.owner_user_id = uid and p.removed_at is null) then
    raise exception 'Pet not found' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.bookings b
              where b.pet_id = p_pet and b.status in ('pending_payment', 'confirmed', 'completed_awaiting_owner', 'disputed')) then
    raise exception 'This pet has a booking that is not finished. Confirm the visit or cancel it first.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.ownership_transfers t where t.pet_id = p_pet and t.completed_at is null) then
    raise exception 'A passport transfer for this pet is still waiting to be finished.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.puppy_orders o
              where o.pet_id = p_pet and o.status in ('deposit_paid', 'balance_paid', 'handed_over', 'disputed')) then
    raise exception 'A puppy purchase for this pet is not finished yet.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.listings l where l.pet_id = p_pet and l.status in ('live', 'reserved')) then
    raise exception 'This pet has a listing that is still live. Take the listing down first.' using errcode = 'P0001';
  end if;

  perform set_config('private.removing_pet', p_pet::text, true);
  update public.passport_shares set revoked_at = now() where revoked_at is null and pet_id = p_pet;
  update public.lost_alerts set status = 'closed' where status = 'active' and pet_id = p_pet;
  delete from public.follows where pet_id = p_pet;

  begin
    delete from public.pets where id = p_pet;
  exception when foreign_key_violation then
    delete from public.health_records where pet_id = p_pet;
    update public.pets
       set name = 'Removed pet', breed = null, date_of_birth = null, colour_markings = null,
           photo_path = null, tag_code = null, mother_pet_id = null, father_pet_id = null, removed_at = now()
     where id = p_pet;
  end;
end;
$$;
revoke all on function public.remove_pet(uuid) from public, anon;
grant execute on function public.remove_pet(uuid) to authenticated;
