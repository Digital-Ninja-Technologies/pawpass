-- Owners can remove a pet from their account. The pet disappears from the app straight away.
-- If nothing else depends on it the row is deleted. If it is tied to a booking, a sale, a transfer or a
-- tag order, the record stays (those people keep their history) but everything about the pet is emptied.

alter table public.pets add column removed_at timestamptz;

create function public.remove_pet(p_pet uuid) returns void
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

  update public.passport_shares set revoked_at = now() where revoked_at is null and pet_id = p_pet;
  update public.lost_alerts set status = 'closed' where status = 'active' and pet_id = p_pet;

  begin
    delete from public.pets where id = p_pet;
  exception when foreign_key_violation then
    delete from public.health_records where pet_id = p_pet;
    delete from public.follows where pet_id = p_pet;
    update public.pets
       set name = 'Removed pet', breed = null, date_of_birth = null, colour_markings = null,
           photo_path = null, tag_code = null, mother_pet_id = null, father_pet_id = null, removed_at = now()
     where id = p_pet;
  end;
end;
$$;
revoke all on function public.remove_pet(uuid) from public, anon;
grant execute on function public.remove_pet(uuid) to authenticated;
