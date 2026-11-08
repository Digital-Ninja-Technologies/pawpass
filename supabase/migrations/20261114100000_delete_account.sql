-- Deleting an account.
--
-- Payments, bookings, orders, disputes, messages and tickets point at the person with no cascade, so the sign in
-- row cannot simply be deleted. Instead the account is erased in two steps:
--   1. erase_account(user) scrubs or removes everything personal, and keeps only what the law or another
--      person's money needs (amounts and references, with the name replaced by "Deleted user").
--   2. The delete-account edge function then removes the sign in through the Auth API (a soft delete: the
--      email and phone are wiped and the person can never sign in again), and clears their files.
-- Erasing is refused while money or a handover is still in flight (see deletion_blockers). It runs in one
-- transaction, so a failure leaves nothing half done. It is safe to run again.

alter table public.profiles add column deleted_at timestamptz;

-- A plain record that an account was deleted, with no personal details.
create table public.account_deletions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  created_at timestamptz not null default now()
);
alter table public.account_deletions enable row level security;
revoke all on public.account_deletions from anon, authenticated;

-- ---------------------------------------------------------------------------
-- What stops a deletion right now, in words a person can read. Empty means nothing does.
-- ---------------------------------------------------------------------------
create function private.deletion_blockers(p_user uuid) returns text[]
language plpgsql stable security definer
set search_path = ''
as $$
declare
  out text[] := '{}';
  pids uuid[];
begin
  if exists (select 1 from public.staff_members s where s.user_id = p_user) then
    out := out || 'You are on the PawPass team. Ask an admin to remove your access first.';
  end if;

  if exists (select 1 from public.bookings b
              where b.owner_user_id = p_user and b.status in ('confirmed', 'completed_awaiting_owner', 'disputed')) then
    out := out || 'You have a booking that is not finished. Confirm the visit or cancel it first.';
  end if;
  if exists (select 1 from public.puppy_orders o
              where o.buyer_user_id = p_user and o.status in ('deposit_paid', 'balance_paid', 'handed_over', 'disputed')) then
    out := out || 'You have a puppy purchase that is not finished. Wait until it is complete first.';
  end if;
  if exists (select 1 from public.escrow_transactions e
              where e.payer_user_id = p_user and e.status in ('held', 'ready', 'paused')) then
    out := out || 'Some of your payments are still held. They are released or refunded once the visit or sale is settled.';
  end if;
  if exists (select 1 from public.disputes d
              where d.opened_by_user_id = p_user and d.status <> 'decided') then
    out := out || 'You have a problem report that has not been decided yet.';
  end if;
  if exists (select 1 from public.ownership_transfers t
              where t.completed_at is null and (t.from_user_id = p_user or t.to_user_id = p_user)) then
    out := out || 'A pet passport transfer is still waiting to be finished.';
  end if;

  select array_agg(a.id) into pids from public.partner_accounts a where a.owner_user_id = p_user;
  if pids is not null then
    if exists (select 1 from public.escrow_transactions e
                where e.payee_partner_id = any(pids)
                  and (e.status in ('held', 'ready', 'paused') or (e.status = 'released' and e.paid_out_at is null))) then
      out := out || 'Your business is still owed money. Wait for the next payout, then try again.';
    end if;
    if exists (select 1 from public.bookings b
                where b.partner_account_id = any(pids) and b.status in ('confirmed', 'completed_awaiting_owner', 'disputed')) then
      out := out || 'Your business has bookings that are not finished.';
    end if;
    if exists (select 1 from public.puppy_orders o
                where o.partner_account_id = any(pids) and o.status in ('deposit_paid', 'balance_paid', 'handed_over', 'disputed')) then
      out := out || 'Your business has pet sales that are not finished.';
    end if;
  end if;
  return out;
end;
$$;
revoke all on function private.deletion_blockers(uuid) from public, anon, authenticated;

-- The app asks this before it shows the delete button, so a person sees the reasons first.
create function public.my_deletion_blockers() returns text[]
language sql stable security definer
set search_path = ''
as $$
  select case when (select auth.uid()) is null then null else private.deletion_blockers((select auth.uid())) end;
$$;
revoke all on function public.my_deletion_blockers() from public, anon;
grant execute on function public.my_deletion_blockers() to authenticated;

-- ---------------------------------------------------------------------------
-- The erasing. Server side only (the edge function calls it with the service role).
-- ---------------------------------------------------------------------------
create function public.erase_account(p_user uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  blockers text[];
  pids uuid[];
  pet record;
begin
  if p_user is null or not exists (select 1 from auth.users u where u.id = p_user) then
    raise exception 'Account not found' using errcode = 'P0002';
  end if;
  blockers := private.deletion_blockers(p_user);
  if coalesce(array_length(blockers, 1), 0) > 0 then
    raise exception '%', array_to_string(blockers, ' ') using errcode = 'P0001';
  end if;

  select coalesce(array_agg(a.id), '{}') into pids from public.partner_accounts a where a.owner_user_id = p_user;

  -- What the person posted and who they followed.
  delete from public.posts where author_user_id = p_user;
  delete from public.post_comments where author_user_id = p_user;
  delete from public.post_likes where user_id = p_user;
  delete from public.comment_likes where user_id = p_user;
  delete from public.follows where follower_user_id = p_user;
  delete from public.blocks where user_id = p_user or blocked_user_id = p_user;
  delete from public.notifications where user_id = p_user;
  delete from public.analytics_events where user_id = p_user;

  -- Chats: the other person keeps their half, but nothing this person wrote.
  update public.messages
     set body = 'This message was deleted', attachment_path = null, location = null
   where sender_user_id = p_user;
  update public.direct_requests set status = 'declined', decided_at = now()
   where (requester_user_id = p_user or recipient_user_id = p_user) and status = 'pending';

  -- Support, applications, sightings, tag deliveries: the record stays, the personal words do not.
  update public.support_messages set body = 'This message was deleted' where author_user_id = p_user;
  update public.support_tickets set subject = 'Deleted' where user_id = p_user;
  update public.adoption_applications set answers = '{}'::jsonb where applicant_user_id = p_user;
  update public.sightings set note = null where reporter_user_id = p_user;
  update public.qr_tag_orders set address = '', area = '' where user_id = p_user;

  -- Pets: removed if nothing else depends on them, otherwise emptied of everything about them.
  update public.passport_shares set revoked_at = now()
   where revoked_at is null and pet_id in (select p.id from public.pets p where p.owner_user_id = p_user);
  update public.lost_alerts set status = 'closed'
   where status = 'active' and pet_id in (select p.id from public.pets p where p.owner_user_id = p_user);
  for pet in select p.id from public.pets p where p.owner_user_id = p_user loop
    begin
      delete from public.pets where id = pet.id;
    exception when foreign_key_violation then
      delete from public.health_records where pet_id = pet.id;
      delete from public.follows where pet_id = pet.id;
      update public.pets
         set name = 'Deleted pet', breed = null, date_of_birth = null, colour_markings = null,
             photo_path = null, mother_pet_id = null, father_pet_id = null
       where id = pet.id;
    end;
  end loop;

  -- A business: bank details and documents go, the record stays suspended so settled sales keep their history.
  update public.listings set status = 'removed'
   where partner_account_id = any(pids) and status in ('draft', 'live', 'reserved');
  delete from public.partner_payout_accounts where partner_account_id = any(pids);
  delete from public.partner_documents where partner_account_id = any(pids);
  update public.partner_accounts
     set status = 'suspended', business_name = 'Deleted business', phone = null, address = null, point = null
   where owner_user_id = p_user;

  -- The person.
  update public.profiles
     set first_name = 'Deleted', last_name = 'user', area = null, phone = null, avatar_path = null,
         last_point = null, last_point_at = null, deleted_at = coalesce(deleted_at, now()),
         suspended_at = coalesce(suspended_at, now()),
         suspension_reason = coalesce(suspension_reason, 'Account deleted')
   where user_id = p_user;

  if not exists (select 1 from public.account_deletions d where d.user_id = p_user) then
    insert into public.account_deletions (user_id) values (p_user);
  end if;
end;
$$;
revoke all on function public.erase_account(uuid) from public, anon, authenticated;
grant execute on function public.erase_account(uuid) to service_role;
