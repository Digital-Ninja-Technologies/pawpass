-- Row Level Security for every table in `public`.
--
-- Model (from CLAUDE.md):
--   * Owners see their own data.
--   * Partners see only data shared with them (passport_shares) or their own business data.
--   * Staff read through role scoped policies. Staff never write through the client:
--     admin actions run in server functions (service role) that also write audit_log.
--   * Money, escrow, disputes, ownership transfers and payouts are written server side only.
--   * Health records stay private from staff; exceptional access goes through audited server code.
--
-- Staff read scopes (full_admin always passes private.is_staff):
--   money     = payouts_disputes, read_only
--   people    = support_reports, read_only
--   kyc       = verifications            (documents contain government ID, so read_only is excluded)
--   everything else operational = any active staff

-- ---------------------------------------------------------------------------
-- Extra helper
-- ---------------------------------------------------------------------------
create function private.owns_approved_vet(p_partner uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.partner_accounts a
    where a.id = p_partner
      and a.owner_user_id = (select auth.uid())
      and a.status = 'approved'
      and a.type = 'vet'
  );
$$;
-- Has the signed in user applied to this listing? A helper (not an inline
-- subquery) so listings and adoption_applications policies do not recurse.
create function private.applied_to_listing(p_listing uuid) returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.adoption_applications ap
    where ap.listing_id = p_listing and ap.applicant_user_id = (select auth.uid())
  );
$$;

revoke all on function private.owns_approved_vet(uuid), private.applied_to_listing(uuid) from public, anon;
grant execute on function private.owns_approved_vet(uuid), private.applied_to_listing(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
create policy "signed in users read settings" on public.settings
  for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
create policy "read own profile or staff" on public.profiles
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff());

create policy "create own profile" on public.profiles
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy "update own profile" on public.profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- What other users may see: never the phone number. This view deliberately runs
-- with the owner's rights so it can read profiles of other people; it exposes
-- only the columns below and hides people who have blocked, or been blocked by, the viewer.
create view public.public_profiles
with (security_invoker = false)
as
select p.user_id, p.first_name, p.last_name, p.area, p.avatar_path
from public.profiles p
where not private.is_blocked_between(p.user_id, (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Partner accounts and documents
-- ---------------------------------------------------------------------------
create policy "read approved partners, own partners, or staff" on public.partner_accounts
  for select to authenticated
  using (
    status = 'approved'
    or owner_user_id = (select auth.uid())
    or private.is_staff()
  );

create policy "create own draft partner" on public.partner_accounts
  for insert to authenticated
  with check (
    owner_user_id = (select auth.uid())
    and status = 'draft'
    and verified_at is null
  );

-- Owners can edit descriptive fields only (column grants below). Status changes
-- go through submit_partner_application() or staff server functions.
create policy "update own partner" on public.partner_accounts
  for update to authenticated
  using (owner_user_id = (select auth.uid()))
  with check (owner_user_id = (select auth.uid()));

create policy "delete own draft partner" on public.partner_accounts
  for delete to authenticated
  using (owner_user_id = (select auth.uid()) and status = 'draft');

create policy "read own partner documents or kyc staff" on public.partner_documents
  for select to authenticated
  using (private.owns_partner(partner_account_id) or private.is_staff(array['verifications']));

create policy "upload own partner document" on public.partner_documents
  for insert to authenticated
  with check (
    private.owns_partner(partner_account_id)
    and status = 'submitted'
    and review_note is null
  );

create policy "remove own unapproved partner document" on public.partner_documents
  for delete to authenticated
  using (private.owns_partner(partner_account_id) and status <> 'approved');

-- ---------------------------------------------------------------------------
-- Staff (read only through the client)
-- ---------------------------------------------------------------------------
create policy "staff read own row, full admin reads all" on public.staff_members
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['full_admin']));

create policy "full admin reads invites" on public.staff_invites
  for select to authenticated
  using (private.is_staff(array['full_admin']));

create policy "full admin reads audit log" on public.audit_log
  for select to authenticated
  using (private.is_staff(array['full_admin']));

-- ---------------------------------------------------------------------------
-- Pets and passports
-- ---------------------------------------------------------------------------
create policy "view pets you may see" on public.pets
  for select to authenticated
  using (private.can_view_pet(id));

create policy "add own pet" on public.pets
  for insert to authenticated
  with check (owner_user_id = (select auth.uid()));

-- with check pins the owner, so a pet cannot be handed over from the client.
create policy "edit own pet" on public.pets
  for update to authenticated
  using (owner_user_id = (select auth.uid()))
  with check (owner_user_id = (select auth.uid()));

create policy "delete own pet" on public.pets
  for delete to authenticated
  using (owner_user_id = (select auth.uid()));

create policy "read health records you own or are shared" on public.health_records
  for select to authenticated
  using (private.owns_pet(pet_id) or private.has_active_share(pet_id, 'health'));

create policy "owner adds unverified health record" on public.health_records
  for insert to authenticated
  with check (
    private.owns_pet(pet_id)
    and added_by_user_id = (select auth.uid())
    and verified_by_partner_id is null
    and verified_at is null
  );

-- A partner with a live "write" share can add records. Only an approved vet can
-- mark its own record as verified.
create policy "partner adds record through share" on public.health_records
  for insert to authenticated
  with check (
    given_by_partner_id is not null
    and added_by_user_id = (select auth.uid())
    and private.partner_has_active_share(pet_id, given_by_partner_id, 'write')
    and (
      (verified_by_partner_id is null and verified_at is null)
      or (
        verified_by_partner_id = given_by_partner_id
        and verified_at is not null
        and private.owns_approved_vet(given_by_partner_id)
      )
    )
  );

-- The guard_health_record trigger blocks edits to verified rows.
create policy "owner edits health record" on public.health_records
  for update to authenticated
  using (private.owns_pet(pet_id))
  with check (private.owns_pet(pet_id));

create policy "owner deletes health record" on public.health_records
  for delete to authenticated
  using (private.owns_pet(pet_id));

create policy "owner manages reminders" on public.reminders
  for all to authenticated
  using (private.owns_pet(pet_id))
  with check (private.owns_pet(pet_id));

create policy "owner and shared partner read shares" on public.passport_shares
  for select to authenticated
  using (
    private.owns_pet(pet_id)
    or (
      partner_account_id is not null
      and private.owns_partner(partner_account_id)
      and revoked_at is null
      and expires_at > now()
    )
  );

create policy "owner creates share" on public.passport_shares
  for insert to authenticated
  with check (private.owns_pet(pet_id) and expires_at > now());

create policy "owner updates or revokes share" on public.passport_shares
  for update to authenticated
  using (private.owns_pet(pet_id))
  with check (private.owns_pet(pet_id));

create policy "owner deletes share" on public.passport_shares
  for delete to authenticated
  using (private.owns_pet(pet_id));

-- Handover is written by a server function. Both sides keep a read only record.
create policy "parties read transfer record" on public.ownership_transfers
  for select to authenticated
  using (
    from_user_id = (select auth.uid())
    or to_user_id = (select auth.uid())
    or (from_partner_id is not null and private.owns_partner(from_partner_id))
    or private.is_staff()
  );

-- ---------------------------------------------------------------------------
-- Services and bookings
-- ---------------------------------------------------------------------------
create policy "read active services of approved partners" on public.services
  for select to authenticated
  using (
    private.owns_partner(partner_account_id)
    or private.is_staff()
    or (
      active
      and exists (
        select 1 from public.partner_accounts a
        where a.id = partner_account_id and a.status = 'approved'
      )
    )
  );

create policy "partner manages own services" on public.services
  for all to authenticated
  using (private.owns_partner(partner_account_id))
  with check (private.owns_partner(partner_account_id));

create policy "read availability of approved partners" on public.availability_slots
  for select to authenticated
  using (
    private.owns_partner(partner_account_id)
    or private.is_staff()
    or exists (
      select 1 from public.partner_accounts a
      where a.id = partner_account_id and a.status = 'approved'
    )
  );

create policy "partner manages own availability" on public.availability_slots
  for all to authenticated
  using (private.owns_partner(partner_account_id))
  with check (private.owns_partner(partner_account_id));

create policy "read own bookings, partner bookings, or staff" on public.bookings
  for select to authenticated
  using (
    owner_user_id = (select auth.uid())
    or private.owns_partner(partner_account_id)
    or private.is_staff(array['support_reports', 'payouts_disputes', 'read_only'])
  );

-- Bookings start unpaid. Payment, confirmation, cancellation and disputes move
-- the status server side (the escrow state machine).
create policy "owner creates pending booking" on public.bookings
  for insert to authenticated
  with check (
    owner_user_id = (select auth.uid())
    and status = 'pending_payment'
    and escrow_transaction_id is null
    and passport_share_id is null
    and private.owns_pet(pet_id)
    and exists (
      select 1
      from public.services s
      join public.partner_accounts a on a.id = s.partner_account_id
      where s.id = service_id
        and s.partner_account_id = partner_account_id
        and s.active
        and a.status = 'approved'
    )
  );

create policy "read published reviews and own booking reviews" on public.reviews
  for select to authenticated
  using (
    status = 'published'
    or private.is_staff()
    or exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.owner_user_id = (select auth.uid()) or private.owns_partner(b.partner_account_id))
    )
  );

create policy "owner reviews a completed booking" on public.reviews
  for insert to authenticated
  with check (
    status = 'published'
    and exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and b.owner_user_id = (select auth.uid())
        and b.status = 'completed'
    )
  );

-- ---------------------------------------------------------------------------
-- Listings and adoption
-- ---------------------------------------------------------------------------
create policy "read live listings, own listings, or applied" on public.listings
  for select to authenticated
  using (
    status in ('live', 'reserved')
    or private.owns_partner(partner_account_id)
    or private.is_staff()
    or private.applied_to_listing(id)
  );

-- Only approved breeders and shelters can go live. Sold and adopted are set by
-- the handover server function.
create policy "partner creates listing" on public.listings
  for insert to authenticated
  with check (
    private.owns_partner(partner_account_id)
    and status in ('draft', 'live')
    and (status = 'draft' or private.owns_approved_partner(partner_account_id))
    and exists (
      select 1 from public.partner_accounts a
      where a.id = partner_account_id and a.type in ('breeder', 'shelter')
    )
    and exists (
      select 1 from public.pets p
      where p.id = pet_id and p.owner_user_id = (select auth.uid())
    )
  );

create policy "partner edits listing" on public.listings
  for update to authenticated
  using (private.owns_partner(partner_account_id) and status in ('draft', 'live', 'reserved', 'removed'))
  with check (
    private.owns_partner(partner_account_id)
    and status in ('draft', 'live', 'reserved', 'removed')
    and (status in ('draft', 'removed') or private.owns_approved_partner(partner_account_id))
  );

create policy "partner deletes draft listing" on public.listings
  for delete to authenticated
  using (private.owns_partner(partner_account_id) and status = 'draft');

create policy "read own or received applications" on public.adoption_applications
  for select to authenticated
  using (
    applicant_user_id = (select auth.uid())
    or private.is_staff()
    or exists (
      select 1 from public.listings l
      where l.id = listing_id and private.owns_partner(l.partner_account_id)
    )
  );

create policy "apply to a live adoption listing" on public.adoption_applications
  for insert to authenticated
  with check (
    applicant_user_id = (select auth.uid())
    and status = 'submitted'
    and exists (
      select 1 from public.listings l
      where l.id = listing_id and l.kind = 'adoption' and l.status = 'live'
    )
  );

-- Shelters move applications along; column grants limit this to `status`.
create policy "shelter decides application" on public.adoption_applications
  for update to authenticated
  using (
    exists (
      select 1 from public.listings l
      where l.id = listing_id and private.owns_partner(l.partner_account_id)
    )
  )
  with check (status in ('submitted', 'home_visit', 'approved', 'declined'));

create policy "applicant withdraws application" on public.adoption_applications
  for delete to authenticated
  using (applicant_user_id = (select auth.uid()) and status = 'submitted');

-- ---------------------------------------------------------------------------
-- Money: read only from the client
-- ---------------------------------------------------------------------------
create policy "read own payments, partner payments, or finance staff" on public.escrow_transactions
  for select to authenticated
  using (
    payer_user_id = (select auth.uid())
    or private.owns_partner(payee_partner_id)
    or private.is_staff(array['payouts_disputes', 'read_only'])
  );

create policy "read own disputes or finance staff" on public.disputes
  for select to authenticated
  using (
    opened_by_user_id = (select auth.uid())
    or private.is_staff(array['payouts_disputes', 'read_only'])
    or exists (
      select 1 from public.escrow_transactions e
      where e.id = escrow_transaction_id and private.owns_partner(e.payee_partner_id)
    )
  );

create policy "finance staff read payout runs" on public.payout_runs
  for select to authenticated
  using (private.is_staff(array['payouts_disputes', 'read_only']));

create policy "partner or finance staff read payout items" on public.payout_items
  for select to authenticated
  using (
    private.owns_partner(partner_account_id)
    or private.is_staff(array['payouts_disputes', 'read_only'])
  );

-- ---------------------------------------------------------------------------
-- Community
-- ---------------------------------------------------------------------------
create policy "read posts you are allowed to see" on public.posts
  for select to authenticated
  using (
    author_user_id = (select auth.uid())
    or private.is_staff(array['support_reports', 'read_only'])
    or (
      status = 'published'
      and not private.is_blocked_between(author_user_id, (select auth.uid()))
      and (
        visibility = 'everyone'
        or (visibility = 'nearby' and area is not null and area = private.my_area())
        or (visibility = 'followers' and pet_id is not null and private.follows_pet(pet_id))
      )
    )
  );

create policy "write own post" on public.posts
  for insert to authenticated
  with check (
    author_user_id = (select auth.uid())
    and status = 'published'
    and (pet_id is null or private.owns_pet(pet_id))
  );

-- Column grants stop authors changing `status` (moderation) or `author_user_id`.
create policy "edit own published post" on public.posts
  for update to authenticated
  using (author_user_id = (select auth.uid()) and status = 'published')
  with check (author_user_id = (select auth.uid()) and (pet_id is null or private.owns_pet(pet_id)));

create policy "delete own post" on public.posts
  for delete to authenticated
  using (author_user_id = (select auth.uid()));

create policy "read own follows and followers of own pets" on public.follows
  for select to authenticated
  using (follower_user_id = (select auth.uid()) or private.owns_pet(pet_id));

create policy "follow a pet" on public.follows
  for insert to authenticated
  with check (follower_user_id = (select auth.uid()) and not private.owns_pet(pet_id));

create policy "unfollow a pet" on public.follows
  for delete to authenticated
  using (follower_user_id = (select auth.uid()));

-- Lost alerts never carry contact details. Finders reach the owner through chat.
create policy "read active alerts, own alerts, or staff" on public.lost_alerts
  for select to authenticated
  using (
    status = 'active'
    or private.owns_pet(pet_id)
    or private.is_staff(array['support_reports', 'read_only'])
  );

create policy "owner raises alert" on public.lost_alerts
  for insert to authenticated
  with check (private.owns_pet(pet_id) and status = 'active');

create policy "owner updates alert" on public.lost_alerts
  for update to authenticated
  using (private.owns_pet(pet_id))
  with check (private.owns_pet(pet_id));

create policy "read own sightings, sightings on own alert, or staff" on public.sightings
  for select to authenticated
  using (
    reporter_user_id = (select auth.uid())
    or private.owns_lost_alert(lost_alert_id)
    or private.is_staff(array['support_reports', 'read_only'])
  );

create policy "report a sighting on an active alert" on public.sightings
  for insert to authenticated
  with check (
    reporter_user_id = (select auth.uid())
    and exists (select 1 from public.lost_alerts l where l.id = lost_alert_id and l.status = 'active')
  );

-- Conversations are created server side (they add both members at once).
create policy "members read conversation" on public.conversations
  for select to authenticated
  using (private.in_conversation(id));

create policy "members see who is in the conversation" on public.conversation_members
  for select to authenticated
  using (private.in_conversation(conversation_id));

create policy "member updates own read marker" on public.conversation_members
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "members read messages" on public.messages
  for select to authenticated
  using (private.in_conversation(conversation_id));

create policy "members send messages" on public.messages
  for insert to authenticated
  with check (
    sender_user_id = (select auth.uid())
    and private.in_conversation(conversation_id)
    and not exists (
      select 1 from public.conversation_members m
      where m.conversation_id = messages.conversation_id
        and m.user_id <> (select auth.uid())
        and private.is_blocked_between(m.user_id, (select auth.uid()))
    )
  );

create policy "file a report" on public.reports
  for insert to authenticated
  with check (reporter_user_id = (select auth.uid()) and status = 'open' and action is null);

create policy "read own reports or support staff" on public.reports
  for select to authenticated
  using (
    reporter_user_id = (select auth.uid())
    or private.is_staff(array['support_reports', 'read_only'])
  );

create policy "manage own blocks" on public.blocks
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Tag orders are created server side after payment is confirmed.
create policy "read own tag orders or support staff" on public.qr_tag_orders
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.is_staff(array['support_reports', 'read_only'])
  );

-- ---------------------------------------------------------------------------
-- Support
-- ---------------------------------------------------------------------------
create policy "read own tickets or support staff" on public.support_tickets
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.is_staff(array['support_reports', 'read_only'])
  );

create policy "open a ticket" on public.support_tickets
  for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'open');

create policy "close own ticket" on public.support_tickets
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and status in ('open', 'closed'));

create policy "read ticket messages without internal notes" on public.support_messages
  for select to authenticated
  using (
    private.is_staff(array['support_reports', 'read_only'])
    or (
      not internal
      and exists (
        select 1 from public.support_tickets t
        where t.id = ticket_id and t.user_id = (select auth.uid())
      )
    )
  );

create policy "reply on own ticket" on public.support_messages
  for insert to authenticated
  with check (
    author_user_id = (select auth.uid())
    and author_staff_id is null
    and not internal
    and exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and t.user_id = (select auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- Table privileges (defence in depth on top of RLS)
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke truncate, references, trigger on all tables in schema public from authenticated;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on functions from anon;

grant select on public.public_profiles to authenticated;

-- Partners can edit descriptive fields only, never status or verified_at.
revoke update on public.partner_accounts from authenticated;
grant update (business_name, area, point) on public.partner_accounts to authenticated;

-- Shelters can only change an application's status.
revoke update on public.adoption_applications from authenticated;
grant update (status) on public.adoption_applications to authenticated;

-- Authors cannot change moderation status or reassign authorship.
revoke update on public.posts from authenticated;
grant update (body, media_paths, visibility, area, pet_id) on public.posts to authenticated;

-- Owners can update the alert details and close it, not the radius or expiry.
revoke update on public.lost_alerts from authenticated;
grant update (description, status, last_seen_at, last_seen_point) on public.lost_alerts to authenticated;

revoke update on public.conversation_members from authenticated;
grant update (last_read_at) on public.conversation_members to authenticated;

revoke update on public.support_tickets from authenticated;
grant update (status) on public.support_tickets to authenticated;

-- Immutable once created.
revoke update, delete on public.reviews, public.messages, public.sightings from authenticated;

-- ---------------------------------------------------------------------------
-- Safety net: fail the migration if any table was left without RLS.
-- ---------------------------------------------------------------------------
do $$
declare missing text;
begin
  select string_agg(tablename, ', ') into missing
  from pg_tables
  where schemaname = 'public' and not rowsecurity;
  if missing is not null then
    raise exception 'RLS is not enabled on: %', missing;
  end if;
end;
$$;
