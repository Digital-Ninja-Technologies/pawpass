-- Services and escrow (milestone 3): browse and book care, pay through Paystack into escrow, confirm the visit,
-- review it, cancel, or open a dispute. All money moves are checked here, in one place.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------
alter table public.settings
  add column dispute_decision_hours integer not null default 72 check (dispute_decision_hours > 0),
  add column booking_auto_release_hours integer not null default 72 check (booking_auto_release_hours > 0),
  add column booking_hold_minutes integer not null default 20 check (booking_hold_minutes between 5 and 120);

alter table public.services
  add column category text not null default 'vet' check (category in ('vet', 'grooming', 'training', 'boarding')),
  add column description text check (char_length(description) <= 300);
grant update (category, description) on public.services to authenticated;

alter table public.partner_accounts add column address text;
grant update (address) on public.partner_accounts to authenticated;

-- Price, fee and service name are copied onto the booking when it is made, so later edits to the service
-- never change what was agreed.
alter table public.bookings
  add column service_name text,
  add column amount_kobo bigint check (amount_kobo > 0),
  add column fee_kobo bigint check (fee_kobo >= 0),
  add column paystack_reference text unique,
  add column partner_done_at timestamptz,
  add column owner_confirmed_at timestamptz,
  add column cancelled_at timestamptz,
  add column cancel_reason text;

alter table public.escrow_transactions
  add column refund_kobo bigint not null default 0 check (refund_kobo >= 0 and refund_kobo <= amount_kobo),
  add column refund_status text check (refund_status in ('pending', 'processing', 'sent', 'failed')),
  add column refund_reference text,
  add column refund_error text,
  add column refund_attempted_at timestamptz,
  add column paid_out_at timestamptz;

-- Rows written before this milestone: make them consistent with the new columns.
update public.escrow_transactions set refund_kobo = amount_kobo, refund_status = 'sent'
 where status = 'refunded' and refund_kobo = 0;
update public.escrow_transactions set refund_kobo = amount_kobo / 2
 where status = 'partially_refunded' and refund_kobo = 0;
update public.escrow_transactions set paid_out_at = coalesce(paid_out_at, updated_at) where status = 'released';

-- ---------------------------------------------------------------------------
-- Escrow state machine
--
--   held      payment received, waiting for the visit
--   ready     the owner confirmed (or the window passed): goes out in the next payout run
--   paused    a dispute is open: nothing moves until staff decide
--   released  paid out to the partner
--   refunded / partially_refunded   money went back to the owner
--
--   held   -> ready | paused | refunded
--   ready  -> paused | released
--   paused -> ready | refunded | partially_refunded
--
-- Anything else is refused, whoever asks (the app, an edge function, or the admin console).
-- ---------------------------------------------------------------------------
create function private.escrow_can_move(p_from text, p_to text) returns boolean
language sql immutable
as $$
  select (p_from, p_to) in (
    ('held', 'ready'), ('held', 'paused'), ('held', 'refunded'),
    ('ready', 'paused'), ('ready', 'released'),
    ('paused', 'ready'), ('paused', 'refunded'), ('paused', 'partially_refunded')
  );
$$;

create function private.guard_escrow() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.amount_kobo is distinct from old.amount_kobo
     or new.fee_kobo is distinct from old.fee_kobo
     or new.payer_user_id is distinct from old.payer_user_id
     or new.payee_partner_id is distinct from old.payee_partner_id
     or new.kind is distinct from old.kind
     or new.paystack_reference is distinct from old.paystack_reference then
    raise exception 'The money details of an escrow payment cannot be changed' using errcode = 'P0001';
  end if;

  if new.status is distinct from old.status then
    if not private.escrow_can_move(old.status, new.status) then
      raise exception 'Escrow cannot move from % to %', old.status, new.status using errcode = 'P0001';
    end if;
    if new.status = 'refunded' then
      new.refund_kobo := new.amount_kobo;
    end if;
    if new.status = 'partially_refunded'
       and (new.refund_kobo <= 0 or new.refund_kobo >= new.amount_kobo) then
      raise exception 'A split needs a refund above zero and below the full amount' using errcode = 'P0001';
    end if;
    if new.status in ('refunded', 'partially_refunded')
       and new.paystack_reference is not null and new.refund_status is null then
      new.refund_status := 'pending';
    end if;
    if new.status = 'released' then
      new.paid_out_at := coalesce(new.paid_out_at, now());
    end if;
  elsif new.refund_kobo is distinct from old.refund_kobo then
    raise exception 'A refund amount can only be set when the status changes' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger guard_escrow
  before update on public.escrow_transactions
  for each row execute function private.guard_escrow();

create function private.booking_can_move(p_from text, p_to text) returns boolean
language sql immutable
as $$
  select (p_from, p_to) in (
    ('pending_payment', 'confirmed'), ('pending_payment', 'cancelled'),
    ('confirmed', 'completed_awaiting_owner'), ('confirmed', 'completed'),
    ('confirmed', 'cancelled'), ('confirmed', 'disputed'),
    ('completed_awaiting_owner', 'completed'), ('completed_awaiting_owner', 'disputed'),
    ('completed', 'disputed'),
    ('disputed', 'completed'), ('disputed', 'cancelled')
  );
$$;

create function private.guard_booking() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.amount_kobo is not null and (
       new.amount_kobo is distinct from old.amount_kobo
       or new.fee_kobo is distinct from old.fee_kobo
       or new.paystack_reference is distinct from old.paystack_reference) then
    raise exception 'The price of a booking cannot be changed' using errcode = 'P0001';
  end if;
  if new.owner_user_id is distinct from old.owner_user_id
     or new.partner_account_id is distinct from old.partner_account_id
     or new.service_id is distinct from old.service_id
     or new.pet_id is distinct from old.pet_id then
    raise exception 'Who and what was booked cannot be changed' using errcode = 'P0001';
  end if;
  if new.status is distinct from old.status and not private.booking_can_move(old.status, new.status) then
    raise exception 'A booking cannot move from % to %', old.status, new.status using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger guard_booking
  before update on public.bookings
  for each row execute function private.guard_booking();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- "Thu 5 Nov at 4:30pm" in Lagos time.
create function private.lagos_when(p_at timestamptz) returns text
language sql stable
set search_path = ''
as $$
  select to_char(p_at at time zone 'Africa/Lagos', 'Dy FMDD Mon') || ' at '
      || lower(to_char(p_at at time zone 'Africa/Lagos', 'FMHH12:MIAM'));
$$;

create function private.notify(p_user uuid, p_kind text, p_title text, p_body text, p_link text, p_key text)
returns void
language sql security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
  values (p_user, p_kind, p_title, p_body, p_link, p_key)
  on conflict (user_id, dedupe_key) do nothing;
$$;

-- How many bookings occupy a slot right now. Unpaid ones count only while their hold lasts.
create function private.slot_taken(p_partner uuid, p_starts timestamptz, p_except uuid default null) returns integer
language sql stable security definer
set search_path = ''
as $$
  select count(*)::integer
    from public.bookings b
   where b.partner_account_id = p_partner
     and b.starts_at = p_starts
     and b.id is distinct from p_except
     and (
       b.status in ('confirmed', 'completed_awaiting_owner', 'completed', 'disputed')
       or (b.status = 'pending_payment'
           and b.created_at > now() - make_interval(mins => (select booking_hold_minutes from public.settings limit 1)))
     );
$$;

revoke all on function private.escrow_can_move(text, text), private.booking_can_move(text, text),
  private.lagos_when(timestamptz), private.notify(uuid, text, text, text, text, text),
  private.slot_taken(uuid, timestamptz, uuid), private.guard_escrow(), private.guard_booking() from public, anon;
grant execute on function private.escrow_can_move(text, text), private.booking_can_move(text, text),
  private.lagos_when(timestamptz), private.slot_taken(uuid, timestamptz, uuid) to authenticated, service_role;

-- When a dispute is decided the booking follows the money.
create function private.escrow_follow_up() returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  b public.bookings;
  partner_owner uuid;
  outcome text;
begin
  if old.status = 'paused' and new.status in ('ready', 'refunded', 'partially_refunded') then
    select * into b from public.bookings where escrow_transaction_id = new.id;
    if found and b.status = 'disputed' then
      update public.bookings
         set status = case when new.status = 'refunded' then 'cancelled' else 'completed' end,
             cancelled_at = case when new.status = 'refunded' then now() else cancelled_at end,
             cancel_reason = case when new.status = 'refunded' then 'dispute_refund' else cancel_reason end
       where id = b.id;
      select owner_user_id into partner_owner from public.partner_accounts where id = b.partner_account_id;
      outcome := case new.status
        when 'refunded' then 'Your payment is being refunded in full.'
        when 'partially_refunded' then 'Part of your payment is being refunded.'
        else 'The payment goes to the provider.' end;
      perform private.notify(b.owner_user_id, 'booking', 'PawPass decided your report', outcome, '/bookings', 'dispute-decided:' || new.id);
      perform private.notify(partner_owner, 'booking', 'A reported booking was decided', outcome, '/bookings', 'dispute-decided-p:' || new.id);
    end if;
  end if;
  return new;
end;
$$;
create trigger escrow_follow_up
  after update of status on public.escrow_transactions
  for each row execute function private.escrow_follow_up();
revoke all on function private.escrow_follow_up() from public, anon;

-- ---------------------------------------------------------------------------
-- Bookings are made through create_booking only: it checks the slot, copies the price, and shares the pet's
-- passport with the provider. Direct inserts from the app are closed.
-- ---------------------------------------------------------------------------
drop policy "owner creates pending booking" on public.bookings;
revoke insert on public.bookings from authenticated;

create function public.create_booking(p_service uuid, p_pet uuid, p_starts_at timestamptz) returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  s public.services;
  a public.partner_accounts;
  st public.settings;
  b public.bookings;
  cap integer;
  fee bigint;
  share_id uuid;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if not private.owns_pet(p_pet) then
    raise exception 'Pet not found' using errcode = '42501';
  end if;

  select * into s from public.services where id = p_service and active;
  if not found then
    raise exception 'That service is not available' using errcode = '22023';
  end if;
  select * into a from public.partner_accounts where id = s.partner_account_id and status = 'approved';
  if not found then
    raise exception 'That provider is not taking bookings' using errcode = '22023';
  end if;
  if a.owner_user_id = me then
    raise exception 'You cannot book your own service' using errcode = '22023';
  end if;
  if s.price_kobo <= 0 then
    raise exception 'This service has no price yet' using errcode = '22023';
  end if;
  if p_starts_at <= now() then
    raise exception 'That time has passed' using errcode = '22023';
  end if;
  select * into st from public.settings limit 1;

  select sl.capacity into cap from public.availability_slots sl
   where sl.partner_account_id = a.id and sl.starts_at = p_starts_at;
  if not found then
    raise exception 'That time is not available' using errcode = '22023';
  end if;

  -- Tapping Pay twice, or coming back to it, reuses the unpaid booking while its hold lasts.
  select * into b from public.bookings
   where owner_user_id = me and service_id = p_service and pet_id = p_pet and starts_at = p_starts_at
     and status = 'pending_payment'
     and created_at > now() - make_interval(mins => st.booking_hold_minutes)
   order by created_at desc limit 1;

  if not found then
    if private.slot_taken(a.id, p_starts_at) >= cap then
      raise exception 'That time was just taken. Pick another.' using errcode = '22023';
    end if;

    fee := round(s.price_kobo * st.booking_commission_bps / 10000.0)::bigint;
    insert into public.bookings
      (owner_user_id, pet_id, partner_account_id, service_id, starts_at, service_name, amount_kobo, fee_kobo, paystack_reference)
    values
      (me, p_pet, a.id, s.id, p_starts_at, s.name, s.price_kobo, fee, 'pp_' || replace(gen_random_uuid()::text, '-', ''))
    returning * into b;

    -- The provider can see the pet's health records (and add one) from now until the visit is over.
    insert into public.passport_shares (pet_id, partner_account_id, token_hash, scopes, expires_at)
    values (p_pet, a.id, encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'),
            array['health', 'write'], p_starts_at + interval '6 hours')
    returning id into share_id;
    update public.bookings set passport_share_id = share_id where id = b.id;
  end if;

  return jsonb_build_object(
    'booking_id', b.id,
    'reference', b.paystack_reference,
    'amount_kobo', b.amount_kobo,
    'fee_kobo', b.fee_kobo,
    'service_name', b.service_name,
    'partner_name', a.business_name,
    'starts_at', b.starts_at
  );
end;
$$;
revoke all on function public.create_booking(uuid, uuid, timestamptz) from public, anon;
grant execute on function public.create_booking(uuid, uuid, timestamptz) to authenticated;

-- ---------------------------------------------------------------------------
-- Payment received. Called only by the payments function, after it has checked the signature and asked
-- Paystack to confirm the amount. Safe to call twice for the same reference.
-- ---------------------------------------------------------------------------
create function public.confirm_booking_payment(p_reference text, p_amount_kobo bigint)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  b public.bookings;
  a public.partner_accounts;
  esc public.escrow_transactions;
  cap integer;
  slot_full boolean;
begin
  select * into b from public.bookings where paystack_reference = p_reference for update;
  if not found then
    raise exception 'Unknown payment reference' using errcode = 'P0002';
  end if;
  if b.escrow_transaction_id is not null then
    return jsonb_build_object('result', 'already_confirmed', 'booking_id', b.id, 'booking_status', b.status);
  end if;
  if p_amount_kobo is distinct from b.amount_kobo then
    raise exception 'The amount paid does not match the booking' using errcode = 'P0001';
  end if;

  select * into a from public.partner_accounts where id = b.partner_account_id;
  select sl.capacity into cap from public.availability_slots sl
   where sl.partner_account_id = b.partner_account_id and sl.starts_at = b.starts_at;
  -- Is there still room once everyone else's bookings are counted?
  slot_full := b.status = 'cancelled'
            or coalesce(cap, 0) <= private.slot_taken(b.partner_account_id, b.starts_at, b.id);

  insert into public.escrow_transactions (payer_user_id, payee_partner_id, kind, amount_kobo, fee_kobo, status, paystack_reference)
  values (b.owner_user_id, b.partner_account_id, 'booking', b.amount_kobo, b.fee_kobo, 'held', p_reference)
  returning * into esc;

  if slot_full then
    -- Paid for a time that is no longer free: keep the record, send the money straight back.
    update public.escrow_transactions set status = 'refunded' where id = esc.id;
    update public.bookings
       set status = 'cancelled', escrow_transaction_id = esc.id, cancelled_at = coalesce(cancelled_at, now()),
           cancel_reason = coalesce(cancel_reason, 'slot_unavailable')
     where id = b.id;
    perform private.notify(b.owner_user_id, 'booking', 'We could not keep your booking',
      'That time was taken while you were paying. Your payment is being refunded in full.', '/bookings', 'booking-refund:' || b.id);
    return jsonb_build_object('result', 'refunded', 'booking_id', b.id, 'booking_status', 'cancelled');
  end if;

  update public.bookings set status = 'confirmed', escrow_transaction_id = esc.id where id = b.id;
  perform private.notify(b.owner_user_id, 'booking', 'You''re booked',
    b.service_name || ' at ' || a.business_name || ', ' || private.lagos_when(b.starts_at) || '.', '/bookings', 'booked:' || b.id);
  perform private.notify(a.owner_user_id, 'booking', 'New booking',
    b.service_name || ', ' || private.lagos_when(b.starts_at) || '.', '/bookings', 'booked-p:' || b.id);
  return jsonb_build_object('result', 'confirmed', 'booking_id', b.id, 'booking_status', 'confirmed');
end;
$$;
revoke all on function public.confirm_booking_payment(text, bigint) from public, anon, authenticated;
grant execute on function public.confirm_booking_payment(text, bigint) to service_role;

-- ---------------------------------------------------------------------------
-- The visit
-- ---------------------------------------------------------------------------
create function public.partner_complete_visit(p_booking uuid) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  b public.bookings;
begin
  select * into b from public.bookings where id = p_booking for update;
  if not found or not private.owns_partner(b.partner_account_id) then
    raise exception 'Booking not found' using errcode = '42501';
  end if;
  if b.status <> 'confirmed' then
    raise exception 'Only a confirmed booking can be marked done' using errcode = 'P0001';
  end if;
  if b.starts_at > now() then
    raise exception 'A visit can be marked done once it has started' using errcode = 'P0001';
  end if;
  update public.bookings set status = 'completed_awaiting_owner', partner_done_at = now() where id = b.id;
  perform private.notify(b.owner_user_id, 'booking', 'How was ' || (select name from public.pets where id = b.pet_id) || '''s visit?',
    'Confirm the visit and rate ' || (select business_name from public.partner_accounts where id = b.partner_account_id) || ' to release payment.',
    '/bookings', 'visit-done:' || b.id);
end;
$$;
revoke all on function public.partner_complete_visit(uuid) from public, anon;
grant execute on function public.partner_complete_visit(uuid) to authenticated;

-- The owner confirms the visit (and may rate it): the money becomes ready to pay out.
create function public.confirm_visit(
  p_booking uuid,
  p_rating smallint default null,
  p_tags text[] default '{}',
  p_body text default null
) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  b public.bookings;
  a public.partner_accounts;
  esc public.escrow_transactions;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into b from public.bookings where id = p_booking and owner_user_id = me for update;
  if not found then
    raise exception 'Booking not found' using errcode = '42501';
  end if;
  if b.status not in ('confirmed', 'completed_awaiting_owner') then
    raise exception 'This booking cannot be confirmed' using errcode = 'P0001';
  end if;
  if b.status = 'confirmed' and b.starts_at > now() then
    raise exception 'You can confirm once the visit has started' using errcode = 'P0001';
  end if;
  if p_rating is not null and p_rating not between 1 and 5 then
    raise exception 'A rating is from 1 to 5 stars' using errcode = '22023';
  end if;
  if coalesce(cardinality(p_tags), 0) > 5 or char_length(coalesce(p_body, '')) > 600 then
    raise exception 'That review is too long' using errcode = '22023';
  end if;

  select * into esc from public.escrow_transactions where id = b.escrow_transaction_id for update;
  if not found or esc.status <> 'held' then
    raise exception 'The payment for this booking is not waiting for your confirmation' using errcode = 'P0001';
  end if;

  update public.escrow_transactions set status = 'ready' where id = esc.id;
  update public.bookings set status = 'completed', owner_confirmed_at = now() where id = b.id;

  if p_rating is not null then
    insert into public.reviews (booking_id, rating, tags, body)
    values (b.id, p_rating, coalesce(p_tags, '{}'), nullif(btrim(p_body), ''))
    on conflict (booking_id) do nothing;
  end if;

  select * into a from public.partner_accounts where id = b.partner_account_id;
  perform private.notify(a.owner_user_id, 'booking', 'Visit confirmed',
    b.service_name || ' was confirmed. The payment goes out in the next payout run.', '/bookings', 'confirmed-p:' || b.id);
end;
$$;
revoke all on function public.confirm_visit(uuid, smallint, text[], text) from public, anon;
grant execute on function public.confirm_visit(uuid, smallint, text[], text) to authenticated;

-- Free cancellation up to settings.free_cancel_hours before the visit. The money goes back in full.
create function public.cancel_booking(p_booking uuid, p_reason text default null) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  b public.bookings;
  st public.settings;
  a public.partner_accounts;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select * into b from public.bookings where id = p_booking and owner_user_id = me for update;
  if not found then
    raise exception 'Booking not found' using errcode = '42501';
  end if;
  select * into st from public.settings limit 1;

  if b.status = 'pending_payment' then
    update public.bookings set status = 'cancelled', cancelled_at = now(), cancel_reason = coalesce(nullif(btrim(p_reason), ''), 'owner') where id = b.id;
  elsif b.status = 'confirmed' then
    if b.starts_at - now() < make_interval(hours => st.free_cancel_hours) then
      raise exception 'Free cancellation ended % hours before the visit. Contact the provider, or report a problem after the visit.', st.free_cancel_hours
        using errcode = 'P0001';
    end if;
    update public.escrow_transactions set status = 'refunded' where id = b.escrow_transaction_id;
    update public.bookings set status = 'cancelled', cancelled_at = now(), cancel_reason = coalesce(nullif(btrim(p_reason), ''), 'owner') where id = b.id;
    select * into a from public.partner_accounts where id = b.partner_account_id;
    perform private.notify(a.owner_user_id, 'booking', 'Booking cancelled',
      b.service_name || ', ' || private.lagos_when(b.starts_at) || ', was cancelled by the owner.', '/bookings', 'cancelled-p:' || b.id);
  else
    raise exception 'This booking can no longer be cancelled' using errcode = 'P0001';
  end if;

  update public.passport_shares set revoked_at = now() where id = b.passport_share_id and revoked_at is null;
end;
$$;
revoke all on function public.cancel_booking(uuid, text) from public, anon;
grant execute on function public.cancel_booking(uuid, text) to authenticated;

-- A provider can cancel at any time: the owner is always refunded in full.
create function public.partner_cancel_booking(p_booking uuid, p_reason text default null) returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  b public.bookings;
begin
  select * into b from public.bookings where id = p_booking for update;
  if not found or not private.owns_partner(b.partner_account_id) then
    raise exception 'Booking not found' using errcode = '42501';
  end if;
  if b.status not in ('pending_payment', 'confirmed') then
    raise exception 'This booking can no longer be cancelled' using errcode = 'P0001';
  end if;
  if b.status = 'confirmed' then
    update public.escrow_transactions set status = 'refunded' where id = b.escrow_transaction_id;
  end if;
  update public.bookings set status = 'cancelled', cancelled_at = now(), cancel_reason = coalesce(nullif(btrim(p_reason), ''), 'provider') where id = b.id;
  update public.passport_shares set revoked_at = now() where id = b.passport_share_id and revoked_at is null;
  perform private.notify(b.owner_user_id, 'booking', 'Your booking was cancelled',
    'The provider cancelled ' || b.service_name || '. Your payment is being refunded in full.', '/bookings', 'cancelled-o:' || b.id);
end;
$$;
revoke all on function public.partner_cancel_booking(uuid, text) from public, anon;
grant execute on function public.partner_cancel_booking(uuid, text) to authenticated;

-- "Something went wrong": the money stays on hold and staff decide (see admin_decide_dispute).
create function public.open_dispute(
  p_booking uuid,
  p_reason text,
  p_details text default null,
  p_evidence text[] default '{}'
) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  b public.bookings;
  esc public.escrow_transactions;
  st public.settings;
  a public.partner_accounts;
  label text;
  d uuid;
  path text;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  label := case p_reason
    when 'not_done' then 'Service did not happen'
    when 'hurt_or_sick' then 'My pet was hurt or got sick'
    when 'not_as_promised' then 'Not what was promised'
    when 'other' then 'Something else'
  end;
  if label is null then
    raise exception 'Choose what went wrong' using errcode = '22023';
  end if;
  if char_length(coalesce(p_details, '')) > 2000 or coalesce(cardinality(p_evidence), 0) > 5 then
    raise exception 'That report is too long' using errcode = '22023';
  end if;
  foreach path in array coalesce(p_evidence, '{}') loop
    if path not like me::text || '/%' then
      raise exception 'Evidence must be uploaded to your own folder' using errcode = '22023';
    end if;
  end loop;

  select * into b from public.bookings where id = p_booking and owner_user_id = me for update;
  if not found then
    raise exception 'Booking not found' using errcode = '42501';
  end if;
  if b.status not in ('confirmed', 'completed_awaiting_owner', 'completed') then
    raise exception 'A problem can be reported once the booking has started' using errcode = 'P0001';
  end if;
  if b.status = 'confirmed' and b.starts_at > now() then
    raise exception 'A problem can be reported once the visit has started' using errcode = 'P0001';
  end if;

  select * into esc from public.escrow_transactions where id = b.escrow_transaction_id for update;
  if not found or esc.status not in ('held', 'ready') then
    raise exception 'This payment has already been paid out or refunded' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.disputes where escrow_transaction_id = esc.id and status <> 'decided') then
    raise exception 'A report is already open for this booking' using errcode = 'P0001';
  end if;

  select * into st from public.settings limit 1;
  insert into public.disputes (escrow_transaction_id, opened_by_user_id, reason, details, evidence_paths, status, due_at)
  values (esc.id, me, label, nullif(btrim(p_details), ''), coalesce(p_evidence, '{}'), 'open',
          now() + make_interval(hours => st.dispute_decision_hours))
  returning id into d;

  update public.escrow_transactions set status = 'paused' where id = esc.id;
  update public.bookings set status = 'disputed' where id = b.id;

  select * into a from public.partner_accounts where id = b.partner_account_id;
  perform private.notify(a.owner_user_id, 'booking', 'A problem was reported',
    b.service_name || ' was reported. The payment is on hold while PawPass reviews both sides.', '/bookings', 'disputed-p:' || b.id);
  perform private.notify(me, 'booking', 'We got your report',
    'The payment stays on hold. PawPass decides within ' || st.dispute_decision_hours || ' hours.', '/bookings', 'disputed-o:' || b.id);
  return d;
end;
$$;
revoke all on function public.open_dispute(uuid, text, text, text[]) from public, anon;
grant execute on function public.open_dispute(uuid, text, text, text[]) to authenticated;

-- Visits the owner never confirmed: after booking_auto_release_hours the payment becomes ready. Run by a
-- scheduled job (not scheduled yet; the payments functions can call it).
create function public.release_due_bookings() returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  st public.settings;
  b public.bookings;
  n integer := 0;
begin
  select * into st from public.settings limit 1;
  for b in
    select * from public.bookings
     where status = 'completed_awaiting_owner'
       and partner_done_at < now() - make_interval(hours => st.booking_auto_release_hours)
     for update skip locked
  loop
    update public.escrow_transactions set status = 'ready' where id = b.escrow_transaction_id and status = 'held';
    if found then
      update public.bookings set status = 'completed' where id = b.id;
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.release_due_bookings() from public, anon, authenticated;
grant execute on function public.release_due_bookings() to service_role;

-- ---------------------------------------------------------------------------
-- Refunds are paid back by the payments function, which works through this queue.
-- ---------------------------------------------------------------------------
create function public.claim_pending_refunds(p_limit integer default 20)
returns table (escrow_id uuid, paystack_reference text, refund_kobo bigint)
language plpgsql security definer
set search_path = ''
as $$
begin
  return query
  with picked as (
    select e.id from public.escrow_transactions e
     where e.paystack_reference is not null
       and (e.refund_status = 'pending'
            or (e.refund_status = 'processing' and e.refund_attempted_at < now() - interval '15 minutes'))
     order by e.updated_at
     limit least(greatest(p_limit, 1), 100)
     for update skip locked
  )
  update public.escrow_transactions e
     set refund_status = 'processing', refund_attempted_at = now()
    from picked
   where e.id = picked.id
  returning e.id, e.paystack_reference, e.refund_kobo;
end;
$$;

create function public.finish_refund(p_escrow uuid, p_ok boolean, p_refund_reference text default null, p_error text default null)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.escrow_transactions
     set refund_status = case when p_ok then 'sent' else 'failed' end,
         refund_reference = coalesce(p_refund_reference, refund_reference),
         refund_error = case when p_ok then null else left(p_error, 500) end
   where id = p_escrow and refund_status = 'processing';
  if not found then
    raise exception 'That refund is not being processed' using errcode = 'P0001';
  end if;
end;
$$;
revoke all on function public.claim_pending_refunds(integer), public.finish_refund(uuid, boolean, text, text) from public, anon, authenticated;
grant execute on function public.claim_pending_refunds(integer), public.finish_refund(uuid, boolean, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- Dispute decisions now record the refund amount, and a split pays the remainder to the provider.
-- ---------------------------------------------------------------------------
create or replace function public.admin_decide_dispute(p_dispute uuid, p_decision text, p_refund_kobo bigint default null, p_note text default null)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  d public.disputes;
  e public.escrow_transactions;
  v_refund bigint;
begin
  perform private.require_staff(array['payouts_disputes']);
  if p_decision not in ('refund', 'split', 'release') then
    raise exception 'Unknown decision' using errcode = '22023';
  end if;

  select * into d from public.disputes where id = p_dispute for update;
  if not found then
    raise exception 'Dispute not found' using errcode = 'P0002';
  end if;
  if d.status = 'decided' then
    raise exception 'This dispute has already been decided' using errcode = 'P0001';
  end if;
  select * into e from public.escrow_transactions where id = d.escrow_transaction_id for update;

  v_refund := case p_decision
    when 'refund' then e.amount_kobo
    when 'release' then 0
    else p_refund_kobo
  end;
  if p_decision = 'split' and (v_refund is null or v_refund <= 0 or v_refund >= e.amount_kobo) then
    raise exception 'For a split, enter a refund above zero and below the full amount' using errcode = '22023';
  end if;

  update public.disputes
     set status = 'decided',
         decision = p_decision,
         decision_refund_kobo = v_refund,
         decision_note = nullif(btrim(p_note), ''),
         decided_by_staff_id = private.current_staff_id(),
         decided_at = now()
   where id = p_dispute;

  -- The state machine checks the move. Refunds are paid back by the payments function;
  -- a release (and the rest of a split) goes out in the next payout run.
  update public.escrow_transactions
     set status = case p_decision when 'refund' then 'refunded' when 'split' then 'partially_refunded' else 'ready' end,
         refund_kobo = case when p_decision = 'split' then v_refund else refund_kobo end
   where id = e.id;

  perform private.write_audit('dispute.' || p_decision, 'dispute', p_dispute,
    jsonb_build_object('escrow_id', e.id, 'amount_kobo', e.amount_kobo, 'refund_kobo', v_refund,
                       'note', nullif(btrim(p_note), '')));
end;
$$;

-- Payout runs pick up what is ready, plus the provider's share of a split decision that has not been paid yet.
create or replace function public.admin_prepare_payout_run(p_run_on date) returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_run uuid;
  v_status text;
  v_total bigint;
begin
  perform private.require_staff(array['payouts_disputes']);

  select id, status into v_run, v_status from public.payout_runs where run_on = p_run_on;
  if v_run is not null and v_status <> 'draft' then
    raise exception 'The payout run for this date has already been %', v_status using errcode = 'P0001';
  end if;
  if v_run is null then
    insert into public.payout_runs (run_on) values (p_run_on) returning id into v_run;
  else
    delete from public.payout_items where payout_run_id = v_run;
  end if;

  -- Ready money, net of fees, per partner. Paused (disputed) money is excluded because its status is 'paused'.
  -- A split keeps its share of the fee in proportion to what the provider receives.
  insert into public.payout_items (payout_run_id, partner_account_id, amount_kobo)
  select v_run, x.payee_partner_id, sum(x.net)
    from (
      select e.payee_partner_id, e.amount_kobo - e.fee_kobo as net
        from public.escrow_transactions e
       where e.status = 'ready'
      union all
      select e.payee_partner_id,
             (e.amount_kobo - e.refund_kobo)
               - round(e.fee_kobo * (e.amount_kobo - e.refund_kobo)::numeric / e.amount_kobo)::bigint as net
        from public.escrow_transactions e
       where e.status = 'partially_refunded' and e.paid_out_at is null
    ) x
   group by x.payee_partner_id
  having sum(x.net) > 0;

  select coalesce(sum(amount_kobo), 0) into v_total from public.payout_items where payout_run_id = v_run;
  update public.payout_runs set total_kobo = v_total where id = v_run;

  perform private.write_audit('payout_run.prepare', 'payout_run', v_run, jsonb_build_object('run_on', p_run_on, 'total_kobo', v_total));
  return v_run;
end;
$$;

-- ---------------------------------------------------------------------------
-- Finding care
-- ---------------------------------------------------------------------------
create function private.partner_rating(p_partner uuid) returns table (avg numeric, n integer)
language sql stable security definer
set search_path = ''
as $$
  select round(avg(r.rating)::numeric, 1), count(*)::integer
    from public.reviews r
    join public.bookings b on b.id = r.booking_id
   where b.partner_account_id = p_partner and r.status = 'published';
$$;
revoke all on function private.partner_rating(uuid) from public, anon;
grant execute on function private.partner_rating(uuid) to authenticated, service_role;

create function public.search_services(
  p_category text default null,
  p_query text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_limit integer default 30
) returns table (
  partner_id uuid,
  name text,
  area text,
  address text,
  categories text[],
  rating_avg numeric,
  rating_count integer,
  from_price_kobo bigint,
  next_slot timestamptz,
  distance_m integer,
  open_now boolean,
  open_24h boolean,
  closes_at time,
  home_visits boolean,
  lat double precision,
  lng double precision
)
language sql stable security definer
set search_path = ''
as $$
  with clock as (select (now() at time zone 'Africa/Lagos')::time as t),
  found as (
    select
      a.id, a.business_name, a.area, a.address, a.point, a.open_24h, a.opens_at, a.closes_at, a.home_visits,
      array_agg(distinct s.category) as cats,
      min(s.price_kobo) as from_price
    from public.partner_accounts a
    join public.services s on s.partner_account_id = a.id and s.active
    where a.status = 'approved'
      and (p_category is null or s.category = p_category)
      and (p_query is null or btrim(p_query) = ''
           or a.business_name ilike '%' || btrim(p_query) || '%'
           or s.name ilike '%' || btrim(p_query) || '%')
    group by a.id
  )
  select
    f.id, f.business_name, f.area, f.address, f.cats,
    (select avg from private.partner_rating(f.id)),
    (select n from private.partner_rating(f.id)),
    f.from_price,
    (select min(sl.starts_at) from public.availability_slots sl
      where sl.partner_account_id = f.id and sl.starts_at > now()
        and sl.capacity > private.slot_taken(f.id, sl.starts_at)),
    case when p_lat is not null and p_lng is not null and f.point is not null
         then extensions.st_distance(f.point, extensions.st_point(p_lng, p_lat, 4326)::extensions.geography)::integer end,
    (f.open_24h or (f.opens_at is not null and f.closes_at is not null and
       case when f.opens_at <= f.closes_at then c.t between f.opens_at and f.closes_at
            else c.t >= f.opens_at or c.t <= f.closes_at end)),
    f.open_24h, f.closes_at, f.home_visits,
    extensions.st_y(f.point::extensions.geometry),
    extensions.st_x(f.point::extensions.geometry)
  from found f cross join clock c
  order by
    case when p_lat is not null and p_lng is not null and f.point is not null
         then extensions.st_distance(f.point, extensions.st_point(p_lng, p_lat, 4326)::extensions.geography) end asc nulls last,
    (select avg from private.partner_rating(f.id)) desc nulls last,
    f.business_name
  limit least(greatest(coalesce(p_limit, 30), 1), 60);
$$;

create function public.provider_detail(
  p_partner uuid,
  p_lat double precision default null,
  p_lng double precision default null
) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  a public.partner_accounts;
  r record;
begin
  select * into a from public.partner_accounts where id = p_partner and status = 'approved';
  if not found then
    raise exception 'Provider not found' using errcode = 'P0002';
  end if;
  select * into r from private.partner_rating(a.id);
  return jsonb_build_object(
    'id', a.id,
    'name', a.business_name,
    'type', a.type,
    'area', a.area,
    'address', a.address,
    'verified', a.verified_at is not null,
    'home_visits', a.home_visits,
    'open_24h', a.open_24h,
    'closes_at', a.closes_at,
    'rating_avg', r.avg,
    'rating_count', r.n,
    'lat', extensions.st_y(a.point::extensions.geometry),
    'lng', extensions.st_x(a.point::extensions.geometry),
    'distance_m', case when p_lat is not null and p_lng is not null and a.point is not null
      then extensions.st_distance(a.point, extensions.st_point(p_lng, p_lat, 4326)::extensions.geography)::integer end,
    'services', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'name', s.name, 'price_kobo', s.price_kobo, 'duration_min', s.duration_min,
        'category', s.category, 'description', s.description) order by s.price_kobo, s.name)
        from public.services s where s.partner_account_id = a.id and s.active
    ), '[]'::jsonb)
  );
end;
$$;

-- Bookable times for the next days, with how many places are left (0 shows as taken).
create function public.provider_slots(p_partner uuid, p_days integer default 14)
returns table (starts_at timestamptz, ends_at timestamptz, free integer)
language sql stable security definer
set search_path = ''
as $$
  select sl.starts_at, sl.ends_at, greatest(sl.capacity - private.slot_taken(sl.partner_account_id, sl.starts_at), 0)
    from public.availability_slots sl
    join public.partner_accounts a on a.id = sl.partner_account_id and a.status = 'approved'
   where sl.partner_account_id = p_partner
     and sl.starts_at > now()
     and sl.starts_at < now() + make_interval(days => least(greatest(coalesce(p_days, 14), 1), 60))
   order by sl.starts_at;
$$;

-- Public reviews, with the reviewer's first name only.
create function public.provider_reviews(p_partner uuid, p_limit integer default 20)
returns table (rating smallint, tags text[], body text, created_at timestamptz, reviewer text, service_name text)
language sql stable security definer
set search_path = ''
as $$
  select r.rating, r.tags, r.body, r.created_at,
         nullif(btrim(pr.first_name), ''), b.service_name
    from public.reviews r
    join public.bookings b on b.id = r.booking_id
    left join public.profiles pr on pr.user_id = b.owner_user_id
   where b.partner_account_id = p_partner and r.status = 'published'
   order by r.created_at desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

-- The signed in person's own bookings with what they need to show: runs as them, so only their rows appear.
create function public.my_bookings()
returns table (
  booking_id uuid,
  status text,
  starts_at timestamptz,
  service_name text,
  amount_kobo bigint,
  partner_id uuid,
  partner_name text,
  partner_address text,
  partner_lat double precision,
  partner_lng double precision,
  pet_id uuid,
  pet_name text,
  escrow_status text,
  rating smallint,
  partner_done_at timestamptz,
  dispute_status text,
  dispute_due_at timestamptz,
  can_cancel_until timestamptz
)
language sql stable
set search_path = ''
as $$
  select
    b.id, b.status, b.starts_at,
    coalesce(b.service_name, s.name),
    coalesce(b.amount_kobo, e.amount_kobo, s.price_kobo),
    b.partner_account_id, a.business_name, a.address,
    extensions.st_y(a.point::extensions.geometry), extensions.st_x(a.point::extensions.geometry),
    b.pet_id, p.name,
    e.status,
    r.rating,
    b.partner_done_at,
    d.status, d.due_at,
    b.starts_at - make_interval(hours => (select free_cancel_hours from public.settings limit 1))
  from public.bookings b
  join public.services s on s.id = b.service_id
  join public.partner_accounts a on a.id = b.partner_account_id
  join public.pets p on p.id = b.pet_id
  left join public.escrow_transactions e on e.id = b.escrow_transaction_id
  left join public.reviews r on r.booking_id = b.id
  left join lateral (
    select d1.status, d1.due_at from public.disputes d1
     where d1.escrow_transaction_id = b.escrow_transaction_id
     order by d1.created_at desc limit 1
  ) d on true
  where b.owner_user_id = (select auth.uid())
    and b.status <> 'pending_payment'
  order by b.starts_at desc;
$$;

revoke all on function public.search_services(text, text, double precision, double precision, integer),
  public.provider_detail(uuid, double precision, double precision), public.provider_slots(uuid, integer),
  public.provider_reviews(uuid, integer), public.my_bookings() from public, anon;
grant execute on function public.search_services(text, text, double precision, double precision, integer),
  public.provider_detail(uuid, double precision, double precision), public.provider_slots(uuid, integer),
  public.provider_reviews(uuid, integer), public.my_bookings() to authenticated;
