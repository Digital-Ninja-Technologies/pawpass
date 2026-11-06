-- Services and escrow tests (milestone 3): the escrow state machine, booking and payment functions,
-- cancellation, disputes, the refund queue, and finding care.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/services.test.sql
-- Needs seed.sql. Runs in one transaction that is rolled back. Prints "Services tests passed" on success.

\set QUIET on
\set tolu  'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set amina 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000002'', true); end $$; set local role authenticated;'
\set kemi  'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); end $$; set local role authenticated;'
\set bola  'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000006'', true); end $$; set local role authenticated;'
\set admin 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000007'', true); end $$; set local role authenticated;'
\set anon  'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
\set server 'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$;'
-- The payments function runs as the service role.
\set payments 'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role service_role;'

begin;

create schema test_helpers;
grant usage on schema test_helpers to anon, authenticated, service_role;

-- 'ok' when the statement works, otherwise its SQLSTATE.
create function test_helpers.state(q text) returns text
language plpgsql as $$
begin
  execute q;
  return 'ok';
exception when others then
  return sqlstate;
end;
$$;

-- Named times, so a slot made by the server can be booked by a test user at exactly that time.
create table test_helpers.slots (k text primary key, ts timestamptz not null);
grant select on test_helpers.slots to anon, authenticated, service_role;
create function test_helpers.slot(k text) returns timestamptz language sql stable as $$ select ts from test_helpers.slots where test_helpers.slots.k = $1 $$;
create function test_helpers.mk_slot(k text, partner uuid, at_ timestamptz, cap int default 1) returns timestamptz
language plpgsql as $$
begin
  insert into public.availability_slots (partner_account_id, starts_at, ends_at, capacity) values (partner, at_, at_ + interval '30 minutes', cap);
  insert into test_helpers.slots values (k, at_);
  return at_;
end;
$$;
grant execute on all functions in schema test_helpers to anon, authenticated, service_role;

-- Bingo is c...01 and Mimi c...02 (Tolu), Luna c...05 (Kemi). Amina owns the vet clinics b...01 and b...a1.

-- ---------------------------------------------------------------------------
-- The escrow state machine: every move, allowed or not
-- ---------------------------------------------------------------------------
do $$
declare
  states text[] := array['held', 'ready', 'paused', 'released', 'refunded', 'partially_refunded'];
  allowed text[] := array['held>ready', 'held>paused', 'held>refunded', 'ready>paused', 'ready>released',
                          'paused>ready', 'paused>refunded', 'paused>partially_refunded'];
  f text; t text; n int := 0;
begin
  foreach f in array states loop
    foreach t in array states loop
      assert private.escrow_can_move(f, t) = ((f || '>' || t) = any (allowed)),
        'escrow move ' || f || ' to ' || t || ' is ' || case when (f || '>' || t) = any (allowed) then 'allowed' else 'refused' end;
      n := n + 1;
    end loop;
  end loop;
  assert n = 36, 'all 36 pairs were checked';
  assert not private.escrow_can_move('released', 'refunded'), 'money paid out cannot be refunded';
  assert not private.escrow_can_move('refunded', 'ready'), 'refunded money cannot come back';
  assert not private.escrow_can_move('held', 'released'), 'nothing is paid out before it is ready';
end $$;

:server
insert into public.escrow_transactions (id, payer_user_id, payee_partner_id, kind, amount_kobo, fee_kobo, status, paystack_reference) values
  ('e1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking', 1000000, 120000, 'held', 'ref-sm-1'),
  ('e1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking', 1000000, 120000, 'held', 'ref-sm-2'),
  ('e1000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking', 1000000, 120000, 'held', null);
do $$ begin
  assert test_helpers.state($q$ update public.escrow_transactions set status = 'released' where id = 'e1000000-0000-0000-0000-000000000001' $q$) = 'P0001', 'held cannot be released';
  assert test_helpers.state($q$ update public.escrow_transactions set amount_kobo = 1 where id = 'e1000000-0000-0000-0000-000000000001' $q$) = 'P0001', 'the amount is fixed';
  assert test_helpers.state($q$ update public.escrow_transactions set fee_kobo = 0 where id = 'e1000000-0000-0000-0000-000000000001' $q$) = 'P0001', 'the fee is fixed';
  assert test_helpers.state($q$ update public.escrow_transactions set payee_partner_id = 'b0000000-0000-0000-0000-000000000002' where id = 'e1000000-0000-0000-0000-000000000001' $q$) = 'P0001', 'the payee is fixed';
  assert test_helpers.state($q$ update public.escrow_transactions set refund_kobo = 5 where id = 'e1000000-0000-0000-0000-000000000001' $q$) = 'P0001', 'a refund amount only goes with a status change';

  update public.escrow_transactions set status = 'ready' where id = 'e1000000-0000-0000-0000-000000000001';
  assert test_helpers.state($q$ update public.escrow_transactions set status = 'held' where id = 'e1000000-0000-0000-0000-000000000001' $q$) = 'P0001', 'ready cannot go back to held';
  update public.escrow_transactions set status = 'released' where id = 'e1000000-0000-0000-0000-000000000001';
  assert (select paid_out_at from public.escrow_transactions where id = 'e1000000-0000-0000-0000-000000000001') is not null, 'released records when it was paid out';
  assert test_helpers.state($q$ update public.escrow_transactions set status = 'refunded' where id = 'e1000000-0000-0000-0000-000000000001' $q$) = 'P0001', 'paid out money cannot be refunded';

  update public.escrow_transactions set status = 'refunded' where id = 'e1000000-0000-0000-0000-000000000002';
  assert (select refund_kobo from public.escrow_transactions where id = 'e1000000-0000-0000-0000-000000000002') = 1000000, 'a refund returns the whole amount';
  assert (select refund_status from public.escrow_transactions where id = 'e1000000-0000-0000-0000-000000000002') = 'pending', 'and queues the refund with Paystack';

  update public.escrow_transactions set status = 'refunded' where id = 'e1000000-0000-0000-0000-000000000003';
  assert (select refund_status from public.escrow_transactions where id = 'e1000000-0000-0000-0000-000000000003') is null, 'no Paystack reference, nothing to refund through it';

end $$;
-- paused -> partially_refunded needs a believable refund
insert into public.escrow_transactions (id, payer_user_id, payee_partner_id, kind, amount_kobo, fee_kobo, status, paystack_reference)
  values ('e1000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking', 1000000, 120000, 'paused', 'ref-sm-4');
do $$ begin
  assert test_helpers.state($q$ update public.escrow_transactions set status = 'partially_refunded' where id = 'e1000000-0000-0000-0000-000000000004' $q$) = 'P0001', 'a split with no amount is refused';
  assert test_helpers.state($q$ update public.escrow_transactions set status = 'partially_refunded', refund_kobo = 1000000 where id = 'e1000000-0000-0000-0000-000000000004' $q$) = 'P0001', 'a split cannot refund everything';
  update public.escrow_transactions set status = 'partially_refunded', refund_kobo = 400000 where id = 'e1000000-0000-0000-0000-000000000004';
  assert (select refund_status from public.escrow_transactions where id = 'e1000000-0000-0000-0000-000000000004') = 'pending', 'a split queues its refund';
end $$;

-- Clients can never touch money rows.
:tolu
do $$ begin
  assert test_helpers.state($q$ update public.escrow_transactions set status = 'ready' $q$) <> 'ok'
         or (select count(*) from public.escrow_transactions where status = 'ready' and payer_user_id = 'a0000000-0000-0000-0000-000000000001') = 0,
    'an owner cannot release their own payment';
  assert test_helpers.state($q$ insert into public.escrow_transactions (payer_user_id, payee_partner_id, kind, amount_kobo) values ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking', 1) $q$) <> 'ok', 'cannot create money rows';
end $$;


-- ---------------------------------------------------------------------------
-- Making a booking
-- ---------------------------------------------------------------------------
:server
-- Paws & Claws (b...01): a vaccination at 1,500,000 and a one place slot tomorrow. Lekki hospital (b...a1): a groom.
insert into public.services (id, partner_account_id, name, price_kobo, duration_min, category, active) values
  ('51000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Test vaccination', 1500000, 20, 'vet', true),
  ('51000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'Retired service', 500000, 20, 'vet', false),
  ('51000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'Free chat', 0, 15, 'vet', true),
  ('51000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-0000000000a1', 'Test groom', 800000, 60, 'grooming', true),
  ('51000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000004', 'Unapproved groom', 800000, 60, 'grooming', true);
select test_helpers.mk_slot('a', 'b0000000-0000-0000-0000-000000000001', now() + interval '1 day');
select test_helpers.mk_slot('b', 'b0000000-0000-0000-0000-000000000001', now() + interval '2 days', 2);
select test_helpers.mk_slot('c', 'b0000000-0000-0000-0000-000000000001', now() + interval '3 days');
select test_helpers.mk_slot('d', 'b0000000-0000-0000-0000-000000000001', now() + interval '4 days');
select test_helpers.mk_slot('far', 'b0000000-0000-0000-0000-000000000001', now() + interval '5 days');
select test_helpers.mk_slot('g', 'b0000000-0000-0000-0000-0000000000a1', now() + interval '1 day 2 hours');
select test_helpers.mk_slot('unapproved', 'b0000000-0000-0000-0000-000000000004', now() + interval '1 day');

:tolu
do $$
declare r jsonb; r2 jsonb; b public.bookings;
begin
  r := public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', test_helpers.slot('a'));
  assert (r ->> 'amount_kobo')::bigint = 1500000, 'the price comes from the service';
  assert (r ->> 'fee_kobo')::bigint = 180000, '12 percent commission is worked out and kept';
  assert (r ->> 'reference') like 'pp_%' and length(r ->> 'reference') = 35, 'a payment reference is made';
  assert r ->> 'service_name' = 'Test vaccination' and r ->> 'partner_name' = 'Paws & Claws Vet Clinic', 'names are copied';

  select * into b from public.bookings where id = (r ->> 'booking_id')::uuid;
  assert b.status = 'pending_payment' and b.escrow_transaction_id is null, 'it starts unpaid';
  assert b.service_name = 'Test vaccination' and b.amount_kobo = 1500000, 'the price is copied onto the booking';
  assert (select partner_account_id from public.passport_shares where id = b.passport_share_id) = 'b0000000-0000-0000-0000-000000000001', 'the passport is shared with the clinic';
  assert (select scopes from public.passport_shares where id = b.passport_share_id) = array['health', 'write'], 'it can read health and add a record';
  assert (select expires_at from public.passport_shares where id = b.passport_share_id) = test_helpers.slot('a') + interval '6 hours', 'and lapses after the visit';

  -- Tapping Pay again reuses the same unpaid booking.
  r2 := public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', test_helpers.slot('a'));
  assert r2 ->> 'booking_id' = r ->> 'booking_id' and r2 ->> 'reference' = r ->> 'reference', 'the same booking comes back';
  assert (select count(*) from public.bookings where owner_user_id = 'a0000000-0000-0000-0000-000000000001') = 1, 'no duplicate';

  assert test_helpers.state($q$ select public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000005', test_helpers.slot('c')) $q$) = '42501', 'not with a pet you do not own';
  assert test_helpers.state($q$ select public.create_booking('51000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', test_helpers.slot('c')) $q$) = '22023', 'not a retired service';
  assert test_helpers.state($q$ select public.create_booking('51000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', test_helpers.slot('c')) $q$) = '22023', 'not a service with no price';
  assert test_helpers.state($q$ select public.create_booking('51000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000001', test_helpers.slot('unapproved')) $q$) = '22023', 'not an unapproved provider';
  assert test_helpers.state($q$ select public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', now() + interval '10 days') $q$) = '22023', 'not a time that is not offered';
  assert test_helpers.state($q$ select public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', now() - interval '1 day') $q$) = '22023', 'not a time in the past';
end $$;
do $$ declare refused boolean := false; begin
  begin
    insert into public.bookings (owner_user_id, pet_id, partner_account_id, service_id, starts_at)
    values ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
            'b0000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', now());
  exception when others then refused := true;
  end;
  assert refused, 'no direct inserts';
end $$;

:amina
do $$ begin
  assert test_helpers.state($q$ select public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', test_helpers.slot('c')) $q$) = '42501', 'a provider cannot book for a pet that is not hers';
end $$;
:anon
do $$ begin
  assert test_helpers.state($q$ select public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', test_helpers.slot('c')) $q$) <> 'ok', 'anon cannot book';
end $$;

-- The one place slot is held for the first person while they pay.
:kemi
do $$ begin
  assert test_helpers.state($q$ select public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000005', test_helpers.slot('a')) $q$) = '22023',
    'the held slot cannot be booked by someone else';
end $$;
-- ...until the hold runs out.
:server
update public.bookings set created_at = now() - interval '1 hour' where owner_user_id = 'a0000000-0000-0000-0000-000000000001';
:kemi
do $$ declare r jsonb; begin
  r := public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000005', test_helpers.slot('a'));
  assert r ->> 'booking_id' is not null, 'once the hold ran out the slot is free again';
  perform set_config('test.kemi_ref_a', r ->> 'reference', true);
end $$;

-- ---------------------------------------------------------------------------
-- Payment received (only the payments function may say so)
-- ---------------------------------------------------------------------------
:tolu
do $$ begin
  assert test_helpers.state($q$ select public.confirm_booking_payment('x', 1) $q$) <> 'ok', 'an owner cannot confirm their own payment';
end $$;
:anon
do $$ begin
  assert test_helpers.state($q$ select public.confirm_booking_payment('x', 1) $q$) <> 'ok', 'anon cannot either';
end $$;

-- Kemi pays for slot a. Tolu's unpaid booking for slot a had lapsed.
:payments
do $$
declare r jsonb; ref text := current_setting('test.kemi_ref_a'); e public.escrow_transactions;
begin
  assert test_helpers.state(format($q$ select public.confirm_booking_payment(%L, 1499999) $q$, ref)) = 'P0001', 'the wrong amount is refused';
  assert test_helpers.state($q$ select public.confirm_booking_payment('pp_nothing', 1500000) $q$) = 'P0002', 'an unknown reference is refused';

  r := public.confirm_booking_payment(ref, 1500000);
  assert r ->> 'result' = 'confirmed' and r ->> 'booking_status' = 'confirmed', 'paid and confirmed';
  select * into e from public.escrow_transactions where paystack_reference = ref;
  assert e.status = 'held' and e.amount_kobo = 1500000 and e.fee_kobo = 180000 and e.kind = 'booking', 'the money is held in escrow, fee set aside';
  assert e.payer_user_id = 'a0000000-0000-0000-0000-000000000005' and e.payee_partner_id = 'b0000000-0000-0000-0000-000000000001', 'from the owner, to the provider';
  assert (select escrow_transaction_id from public.bookings where paystack_reference = ref) = e.id, 'the booking points at its escrow';

  -- Paystack can send the same event twice.
  r := public.confirm_booking_payment(ref, 1500000);
  assert r ->> 'result' = 'already_confirmed', 'a repeat does nothing';
  assert (select count(*) from public.escrow_transactions where paystack_reference = ref) = 1, 'and makes no second payment';
end $$;
:server
do $$ begin
  assert (select count(*) from public.notifications where dedupe_key like 'booked:%' and user_id = 'a0000000-0000-0000-0000-000000000005' and title = 'You''re booked') = 1, 'the owner is told';
  assert (select body from public.notifications where dedupe_key like 'booked:%' and user_id = 'a0000000-0000-0000-0000-000000000005') like 'Test vaccination at Paws & Claws Vet Clinic, % at %m.', 'with what, where and when';
  assert (select count(*) from public.notifications where dedupe_key like 'booked-p:%' and user_id = 'a0000000-0000-0000-0000-000000000002') = 1, 'and so is the provider';
end $$;

-- Tolu's booking for slot a had lapsed, and Kemi has the slot now. If Tolu's payment arrives late she is refunded.
:tolu
do $$ declare r jsonb; begin
  perform set_config('test.tolu_ref_a', (select paystack_reference from public.bookings where owner_user_id = 'a0000000-0000-0000-0000-000000000001' limit 1), true);
end $$;
:payments
do $$
declare r jsonb; ref text := current_setting('test.tolu_ref_a');
begin
  r := public.confirm_booking_payment(ref, 1500000);
  assert r ->> 'result' = 'refunded' and r ->> 'booking_status' = 'cancelled', 'paying for a time that was taken refunds it';
  assert (select status from public.escrow_transactions where paystack_reference = ref) = 'refunded', 'the escrow is refunded';
  assert (select refund_status from public.escrow_transactions where paystack_reference = ref) = 'pending', 'and the refund is queued';
  assert (select cancel_reason from public.bookings where paystack_reference = ref) = 'slot_unavailable', 'with the reason recorded';
end $$;
:server
do $$ begin
  assert (select count(*) from public.notifications where dedupe_key like 'booking-refund:%' and user_id = 'a0000000-0000-0000-0000-000000000001') = 1, 'Tolu is told why';
end $$;


-- ---------------------------------------------------------------------------
-- The visit: provider marks it done, owner confirms and rates, money becomes ready
-- ---------------------------------------------------------------------------
:server
-- Books and pays as the given owner, the way the app and the payments function do between them.
create function test_helpers.book_paid(owner uuid, svc uuid, pet uuid, slot_k text) returns uuid
language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', owner::text, true);
  r := public.create_booking(svc, pet, test_helpers.slot(slot_k));
  perform set_config('request.jwt.claim.sub', '', true);
  perform public.confirm_booking_payment(r ->> 'reference', (r ->> 'amount_kobo')::bigint);
  return (r ->> 'booking_id')::uuid;
end;
$$;
grant execute on function test_helpers.book_paid(uuid, uuid, uuid, text) to authenticated, service_role;
select test_helpers.mk_slot('h', 'b0000000-0000-0000-0000-0000000000a1', now() + interval '6 days');
select test_helpers.mk_slot('i', 'b0000000-0000-0000-0000-0000000000a1', now() + interval '7 days');
select test_helpers.mk_slot('j', 'b0000000-0000-0000-0000-0000000000a1', now() + interval '8 days');
select test_helpers.mk_slot('k', 'b0000000-0000-0000-0000-0000000000a1', now() + interval '9 days');

do $$
declare x uuid; y uuid;
begin
  x := test_helpers.book_paid('a0000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b');
  y := test_helpers.book_paid('a0000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'b');
  perform set_config('test.x', x::text, true);
  perform set_config('test.y', y::text, true);
  assert (select count(*) from public.bookings where starts_at = test_helpers.slot('b') and status = 'confirmed') = 2, 'a two place slot takes two bookings';
  assert test_helpers.state($q$ select test_helpers.book_paid('a0000000-0000-0000-0000-000000000005', '51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000005', 'b') $q$) = '22023', 'and then it is full';
end $$;

:tolu
do $$ begin
  assert test_helpers.state(format($q$ select public.confirm_visit(%L) $q$, current_setting('test.x'))) = 'P0001', 'cannot confirm a visit that has not started';
end $$;
:amina
do $$ begin
  assert test_helpers.state(format($q$ select public.partner_complete_visit(%L) $q$, current_setting('test.x'))) = 'P0001', 'cannot mark a visit done before it starts';
end $$;
:server
update public.bookings set starts_at = now() - interval '1 hour' where id in (current_setting('test.x')::uuid, current_setting('test.y')::uuid);

:bola
do $$ begin
  assert test_helpers.state(format($q$ select public.partner_complete_visit(%L) $q$, current_setting('test.x'))) = '42501', 'a stranger cannot mark it done';
end $$;
:tolu
do $$ begin
  assert test_helpers.state(format($q$ select public.partner_complete_visit(%L) $q$, current_setting('test.x'))) = '42501', 'nor can the owner';
end $$;
:amina
do $$ begin
  perform public.partner_complete_visit(current_setting('test.x')::uuid);
  assert (select status from public.bookings where id = current_setting('test.x')::uuid) = 'completed_awaiting_owner', 'the visit is done, waiting for the owner';
  assert test_helpers.state(format($q$ select public.partner_complete_visit(%L) $q$, current_setting('test.x'))) = 'P0001', 'only once';
end $$;
:server
do $$ begin
  assert (select count(*) from public.notifications where dedupe_key = 'visit-done:' || current_setting('test.x') and title = 'How was Bingo''s visit?') = 1, 'the owner is asked how it went';
end $$;

:kemi
do $$ begin
  assert test_helpers.state(format($q$ select public.confirm_visit(%L, 5::smallint) $q$, current_setting('test.x'))) = '42501', 'someone else cannot confirm it';
end $$;
:tolu
do $$ begin
  assert test_helpers.state(format($q$ select public.confirm_visit(%L, 6::smallint) $q$, current_setting('test.x'))) = '22023', 'ratings go from 1 to 5';
  assert test_helpers.state(format($q$ select public.confirm_visit(%L, 4::smallint, array['a','b','c','d','e','f']) $q$, current_setting('test.x'))) = '22023', 'at most five tags';
  assert (select e.status from public.escrow_transactions e join public.bookings b on b.escrow_transaction_id = e.id where b.id = current_setting('test.x')::uuid) = 'held', 'nothing moved while those were refused';

  perform public.confirm_visit(current_setting('test.x')::uuid, 4::smallint, array['On time', 'Gentle'], 'Great visit, Bingo was calm.');
  assert (select status from public.bookings where id = current_setting('test.x')::uuid) = 'completed', 'the booking is complete';
  assert (select e.status from public.escrow_transactions e join public.bookings b on b.escrow_transaction_id = e.id where b.id = current_setting('test.x')::uuid) = 'ready', 'the money is ready to pay out';
  assert (select rating from public.reviews where booking_id = current_setting('test.x')::uuid) = 4, 'the review is saved';
  assert (select tags from public.reviews where booking_id = current_setting('test.x')::uuid) = array['On time', 'Gentle'], 'with its tags';
  assert test_helpers.state(format($q$ select public.confirm_visit(%L) $q$, current_setting('test.x'))) = 'P0001', 'it cannot be confirmed twice';
end $$;
:server
do $$ begin
  assert (select count(*) from public.notifications where dedupe_key = 'confirmed-p:' || current_setting('test.x')) = 1, 'the provider hears the payment is on its way';
end $$;

-- A visit the owner never confirms is released after the window.
:amina
do $$ begin perform public.partner_complete_visit(current_setting('test.y')::uuid); end $$;
:tolu
do $$ begin
  assert test_helpers.state($q$ select public.release_due_bookings() $q$) <> 'ok', 'an owner cannot run the release';
end $$;
:payments
do $$ begin
  assert public.release_due_bookings() = 0, 'a visit finished a moment ago is not released yet';
  update public.bookings set partner_done_at = now() - interval '4 days' where id = current_setting('test.y')::uuid;
  assert public.release_due_bookings() = 1, 'after the window the payment is released';
  assert (select e.status from public.escrow_transactions e join public.bookings b on b.escrow_transaction_id = e.id where b.id = current_setting('test.y')::uuid) = 'ready', 'to ready';
  assert (select status from public.bookings where id = current_setting('test.y')::uuid) = 'completed', 'and the booking is complete';
  assert not exists (select 1 from public.reviews where booking_id = current_setting('test.y')::uuid), 'with no review, because the owner did not write one';
  assert public.release_due_bookings() = 0, 'and only once';
end $$;

-- ---------------------------------------------------------------------------
-- Cancelling: free until the cut off, then not
-- ---------------------------------------------------------------------------
:server
do $$
declare z uuid;
begin
  z := test_helpers.book_paid('a0000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'c');
  perform set_config('test.z', z::text, true);
  update public.bookings set starts_at = now() + interval '1 hour' where id = z;
end $$;
:kemi
do $$ begin
  assert test_helpers.state(format($q$ select public.cancel_booking(%L) $q$, current_setting('test.z'))) = '42501', 'someone else cannot cancel it';
end $$;
:tolu
do $$ declare msg text; begin
  begin perform public.cancel_booking(current_setting('test.z')::uuid); exception when others then msg := sqlerrm; end;
  assert msg like 'Free cancellation ended 2 hours before the visit.%', 'inside the cut off it is refused, and says why (' || coalesce(msg, 'no error') || ')';
end $$;
:server
update public.bookings set starts_at = now() + interval '5 hours' where id = current_setting('test.z')::uuid;
:tolu
do $$ declare z uuid := current_setting('test.z')::uuid; begin
  perform public.cancel_booking(z, 'Plans changed');
  assert (select status from public.bookings where id = z) = 'cancelled', 'cancelled';
  assert (select cancel_reason from public.bookings where id = z) = 'Plans changed', 'with the reason';
  assert (select e.status || '/' || e.refund_status from public.escrow_transactions e join public.bookings b on b.escrow_transaction_id = e.id where b.id = z) = 'refunded/pending', 'the money goes back in full';
  assert (select revoked_at from public.passport_shares s join public.bookings b on b.passport_share_id = s.id where b.id = z) is not null, 'the clinic loses sight of the passport';
  assert test_helpers.state(format($q$ select public.cancel_booking(%L) $q$, z)) = 'P0001', 'cancelling twice is refused';
end $$;
:server
do $$ begin
  assert (select count(*) from public.notifications where dedupe_key = 'cancelled-p:' || current_setting('test.z')) = 1, 'the provider is told';
end $$;

-- An unpaid booking can be dropped with nothing to refund.
:tolu
do $$ declare r jsonb; begin
  r := public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', test_helpers.slot('d'));
  perform public.cancel_booking((r ->> 'booking_id')::uuid);
  assert (select status from public.bookings where id = (r ->> 'booking_id')::uuid) = 'cancelled', 'an unpaid booking cancels';
  assert (select count(*) from public.escrow_transactions where paystack_reference = r ->> 'reference') = 0, 'with no payment to return';
end $$;

-- A provider can cancel at any time and the owner is always refunded.
:server
do $$
declare q uuid;
begin
  q := test_helpers.book_paid('a0000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'far');
  perform set_config('test.q', q::text, true);
  update public.bookings set starts_at = now() + interval '30 minutes' where id = q;
end $$;
:bola
do $$ begin
  assert test_helpers.state(format($q$ select public.partner_cancel_booking(%L) $q$, current_setting('test.q'))) = '42501', 'a stranger cannot cancel for a provider';
end $$;
:amina
do $$ declare q uuid := current_setting('test.q')::uuid; begin
  assert test_helpers.state(format($q$ select public.partner_cancel_booking(%L) $q$, current_setting('test.x'))) = 'P0001', 'a completed booking cannot be cancelled';
  perform public.partner_cancel_booking(q, 'Vet unwell');
  assert (select status from public.bookings where id = q) = 'cancelled', 'the provider cancelled';
  assert (select e.status from public.escrow_transactions e join public.bookings b on b.escrow_transaction_id = e.id where b.id = q) = 'refunded', 'even inside the free window the owner is refunded';
end $$;
:server
do $$ begin
  assert (select count(*) from public.notifications where dedupe_key = 'cancelled-o:' || current_setting('test.q')) = 1, 'the owner is told';
end $$;

-- ---------------------------------------------------------------------------
-- Disputes: "something went wrong" holds the money until staff decide
-- ---------------------------------------------------------------------------
:server
do $$
declare d1 uuid; d2 uuid; d3 uuid; d4 uuid;
begin
  d1 := test_helpers.book_paid('a0000000-0000-0000-0000-000000000005', '51000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000005', 'g');
  d2 := test_helpers.book_paid('a0000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'h');
  d3 := test_helpers.book_paid('a0000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000002', 'i');
  d4 := test_helpers.book_paid('a0000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'j');
  perform set_config('test.d1', d1::text, true);
  perform set_config('test.d2', d2::text, true);
  perform set_config('test.d3', d3::text, true);
  perform set_config('test.d4', d4::text, true);
end $$;
:kemi
do $$ begin
  assert test_helpers.state(format($q$ select public.open_dispute(%L, 'hurt_or_sick') $q$, current_setting('test.d1'))) = 'P0001', 'a problem cannot be reported before the visit starts';
end $$;
:server
update public.bookings set starts_at = now() - interval '2 hours' where id in (current_setting('test.d1')::uuid, current_setting('test.d2')::uuid, current_setting('test.d3')::uuid);
-- the fourth is paid out already
update public.bookings set starts_at = now() - interval '2 hours', status = 'completed' where id = current_setting('test.d4')::uuid;
update public.escrow_transactions set status = 'ready' where id = (select escrow_transaction_id from public.bookings where id = current_setting('test.d4')::uuid);
update public.escrow_transactions set status = 'released' where id = (select escrow_transaction_id from public.bookings where id = current_setting('test.d4')::uuid);

:kemi
do $$ declare d uuid; esc public.escrow_transactions; begin
  assert test_helpers.state(format($q$ select public.open_dispute(%L, 'nonsense') $q$, current_setting('test.d1'))) = '22023', 'the reason must be one of the choices';
  assert test_helpers.state(format($q$ select public.open_dispute(%L, 'other', null, array['a0000000-0000-0000-0000-000000000001/photo.jpg']) $q$, current_setting('test.d1'))) = '22023', 'evidence must be in your own folder';
  assert test_helpers.state(format($q$ select public.open_dispute(%L, 'other', null, array['1','2','3','4','5','6']) $q$, current_setting('test.d1'))) = '22023', 'at most five files';

  d := public.open_dispute(current_setting('test.d1')::uuid, 'hurt_or_sick', 'Luna has a small cut near her ear.',
                           array['a0000000-0000-0000-0000-000000000005/cut.jpg']);
  assert (select reason from public.disputes where id = d) = 'My pet was hurt or got sick', 'the reason is stored as it was shown';
  assert (select due_at from public.disputes where id = d) between now() + interval '71 hours 59 minutes' and now() + interval '72 hours 1 minute', 'staff have 72 hours';
  assert (select evidence_paths from public.disputes where id = d) = array['a0000000-0000-0000-0000-000000000005/cut.jpg'], 'evidence is attached';
  select e.* into esc from public.escrow_transactions e join public.bookings b on b.escrow_transaction_id = e.id where b.id = current_setting('test.d1')::uuid;
  assert esc.status = 'paused', 'the money is on hold';
  assert (select status from public.bookings where id = current_setting('test.d1')::uuid) = 'disputed', 'the booking is disputed';
  assert test_helpers.state(format($q$ select public.open_dispute(%L, 'other') $q$, current_setting('test.d1'))) = 'P0001', 'one open report per booking';
  assert test_helpers.state(format($q$ select public.confirm_visit(%L) $q$, current_setting('test.d1'))) = 'P0001', 'a disputed visit cannot be confirmed';
  assert test_helpers.state(format($q$ select public.cancel_booking(%L) $q$, current_setting('test.d1'))) = 'P0001', 'or cancelled';
end $$;
:tolu
do $$ begin
  assert test_helpers.state(format($q$ select public.open_dispute(%L, 'other') $q$, current_setting('test.d1'))) = '42501', 'someone else cannot report it';
  assert test_helpers.state(format($q$ select public.open_dispute(%L, 'other') $q$, current_setting('test.d4'))) = 'P0001', 'money already paid out cannot be disputed';
  perform public.open_dispute(current_setting('test.d2')::uuid, 'not_done');
  perform public.open_dispute(current_setting('test.d3')::uuid, 'not_as_promised', 'Not what was advertised.');
end $$;
:server
do $$ begin
  assert (select count(*) from public.notifications where dedupe_key = 'disputed-p:' || current_setting('test.d1')) = 1, 'the provider is told';
  assert (select body from public.notifications where dedupe_key = 'disputed-o:' || current_setting('test.d1')) = 'The payment stays on hold. PawPass decides within 72 hours.', 'the owner is told what happens next';
end $$;

-- Staff decide. Each outcome moves the money and the booking together.
:admin
do $$ begin
  perform public.admin_decide_dispute((select id from public.disputes where escrow_transaction_id = (select escrow_transaction_id from public.bookings where id = current_setting('test.d1')::uuid)), 'split', 300000, 'Part refund');
  perform public.admin_decide_dispute((select id from public.disputes where escrow_transaction_id = (select escrow_transaction_id from public.bookings where id = current_setting('test.d2')::uuid)), 'refund', null, 'Full refund');
  perform public.admin_decide_dispute((select id from public.disputes where escrow_transaction_id = (select escrow_transaction_id from public.bookings where id = current_setting('test.d3')::uuid)), 'release', null, 'Service was fine');
end $$;
:server
do $$ begin
  assert (select e.status || '/' || e.refund_kobo from public.escrow_transactions e join public.bookings b on b.escrow_transaction_id = e.id where b.id = current_setting('test.d1')::uuid) = 'partially_refunded/300000', 'a split records what goes back';
  assert (select status from public.bookings where id = current_setting('test.d1')::uuid) = 'completed', 'and the booking is complete';
  assert (select e.status || '/' || e.refund_kobo || '/' || e.refund_status from public.escrow_transactions e join public.bookings b on b.escrow_transaction_id = e.id where b.id = current_setting('test.d2')::uuid) = 'refunded/800000/pending', 'a refund returns everything and queues it';
  assert (select status || '/' || cancel_reason from public.bookings where id = current_setting('test.d2')::uuid) = 'cancelled/dispute_refund', 'and the booking is cancelled';
  assert (select e.status from public.escrow_transactions e join public.bookings b on b.escrow_transaction_id = e.id where b.id = current_setting('test.d3')::uuid) = 'ready', 'a release makes the money ready for payout';
  assert (select status from public.bookings where id = current_setting('test.d3')::uuid) = 'completed', 'and the booking complete';
  assert (select count(*) from public.notifications where dedupe_key like 'dispute-decided:%' and user_id in ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000005')) = 3, 'owners are told each outcome';
  assert (select count(*) from public.notifications where dedupe_key like 'dispute-decided-p:%') = 3, 'and so is the provider';
end $$;

-- ---------------------------------------------------------------------------
-- The refund queue: the payments function claims refunds, sends them to Paystack, and reports back
-- ---------------------------------------------------------------------------
:tolu
do $$ begin
  assert test_helpers.state($q$ select * from public.claim_pending_refunds(5) $q$) <> 'ok', 'an owner cannot claim refunds';
  assert test_helpers.state($q$ select public.finish_refund('00000000-0000-0000-0000-000000000000', true) $q$) <> 'ok', 'nor finish them';
end $$;
:payments
do $$
declare n int; rec record; first_id uuid; second_id uuid;
begin
  select count(*) into n from public.escrow_transactions where refund_status = 'pending';
  assert n = 7, 'seven refunds are waiting: earlier late payments and part refunds, the cancellations, the dispute refund and the split (' || n || ')';

  n := 0;
  for rec in select * from public.claim_pending_refunds(100) order by refund_kobo loop
    n := n + 1;
    assert rec.paystack_reference is not null and rec.refund_kobo > 0, 'each claimed refund has a reference and an amount';
    if n = 1 then first_id := rec.escrow_id; end if;
    if n = 2 then second_id := rec.escrow_id; end if;
  end loop;
  assert n = 7, 'all seven are claimed';
  assert (select count(*) from public.claim_pending_refunds(100)) = 0, 'and a second claim finds nothing, so no refund is sent twice';
  assert (select count(*) from public.escrow_transactions where refund_status = 'processing') = 7, 'they are marked as being processed';

  perform public.finish_refund(first_id, true, 'rf_123');
  assert (select refund_status || '/' || refund_reference from public.escrow_transactions where id = first_id) = 'sent/rf_123', 'a sent refund is recorded with Paystack''s reference';
  perform public.finish_refund(second_id, false, null, 'Paystack said no');
  assert (select refund_status || '/' || refund_error from public.escrow_transactions where id = second_id) = 'failed/Paystack said no', 'a failed one keeps the reason';
  assert test_helpers.state(format($q$ select public.finish_refund(%L, true) $q$, first_id)) = 'P0001', 'a finished refund cannot be finished again';

  -- A claim that was never finished (the function crashed) is picked up again after a while.
  update public.escrow_transactions set refund_attempted_at = now() - interval '20 minutes'
   where refund_status = 'processing' and id = (select id from public.escrow_transactions where refund_status = 'processing' limit 1);
  assert (select count(*) from public.claim_pending_refunds(100)) = 1, 'an abandoned claim is retried';
end $$;

-- The provider's share of the split is paid in the next payout run.
:admin
do $$ declare r uuid; begin
  r := public.admin_prepare_payout_run(current_date + 30);
  -- ready: the confirmed visit (x) 1,500,000 - 180,000; the auto released one (y) the same; the released dispute (d3) 800,000 - 96,000.
  -- plus the split (d1): 800,000 - 300,000 = 500,000 less 500,000/800,000 of the 96,000 fee = 60,000.
  assert (select amount_kobo from public.payout_items where payout_run_id = r and partner_account_id = 'b0000000-0000-0000-0000-000000000001')
    = (1500000 - 180000) * 2 + 528000, 'Paws and Claws gets the two confirmed visits and the earlier ready booking (528,000)';
  assert (select amount_kobo from public.payout_items where payout_run_id = r and partner_account_id = 'b0000000-0000-0000-0000-0000000000a1')
    = (800000 - 96000) + (500000 - 60000), 'the hospital gets the released dispute and its share of the split';
end $$;


-- ---------------------------------------------------------------------------
-- Finding services: search, one provider, slots, reviews, my bookings
-- ---------------------------------------------------------------------------
:server
select test_helpers.mk_slot('full', 'b0000000-0000-0000-0000-0000000000a1', now() + interval '10 days', 1);
select test_helpers.book_paid('a0000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'full');
:tolu
do $$
declare n int; r record; prev int; d jsonb;
begin
  select count(*) into n from public.search_services();
  assert n >= 2, 'search returns the approved providers (' || n || ')';
  assert not exists (select 1 from public.search_services() where partner_id not in (select id from public.partner_accounts where status = 'approved')), 'only approved providers appear';

  assert (select count(*) from public.search_services('grooming')) >= 1, 'filter by category';
  assert not exists (select 1 from public.search_services('grooming') where not ('grooming' = any(categories))), 'and only that category';
  assert (select count(*) from public.search_services(null, 'lekki')) >= 1, 'search by name or area';
  assert (select count(*) from public.search_services(null, 'zzzz-no-such')) = 0, 'nothing matches nonsense';
  assert (select count(*) from public.search_services('wrestling')) = 0, 'an unknown category matches nothing';
  assert (select count(*) from public.search_services(null, null, null, null, 1)) = 1, 'limit is respected';

  -- distance orders nearest first and is filled in only when a location is given
  assert (select distance_m from public.search_services() limit 1) is null, 'no distance without a location';
  prev := -1;
  for r in select * from public.search_services(null, null, 6.4500, 3.4700) loop
    assert r.distance_m is not null and r.distance_m >= prev, 'nearest first';
    prev := r.distance_m;
  end loop;

  -- next_slot skips slots that are already full
  assert (select next_slot from public.search_services() where partner_id = 'b0000000-0000-0000-0000-0000000000a1') > now(), 'there is a next slot in the future';
  assert (select from_price_kobo from public.search_services() where partner_id = 'b0000000-0000-0000-0000-000000000001') = 0, 'from price is the cheapest active service (the free chat)';
  assert (select from_price_kobo from public.search_services() where partner_id = 'b0000000-0000-0000-0000-0000000000a1') = 800000, 'and for the hospital the groom';

  d := public.provider_detail('b0000000-0000-0000-0000-0000000000a1');
  assert d ->> 'name' is not null and jsonb_typeof(d -> 'services') = 'array', 'detail has the name and services';
  assert jsonb_array_length(d -> 'services') >= 1, 'with at least one service';
  assert test_helpers.state($q$ select public.provider_detail('00000000-0000-0000-0000-00000000dead') $q$) = 'P0002', 'unknown provider';
  assert (select count(*) from public.provider_slots('b0000000-0000-0000-0000-0000000000a1', 14)) >= 1, 'slots are listed';
  assert not exists (select 1 from public.provider_slots('b0000000-0000-0000-0000-0000000000a1', 14) where starts_at <= now()), 'only future slots';
  assert not exists (select 1 from public.provider_slots('b0000000-0000-0000-0000-0000000000a1', 14) where free < 0), 'free places are never negative';
  assert (select free from public.provider_slots('b0000000-0000-0000-0000-0000000000a1', 60) where starts_at = test_helpers.slot('full')) = 0, 'a full slot shows no free places';
end $$;

-- Reviews show a first name only, and only published ones.
:tolu
do $$ declare r record; begin
  select * into r from public.provider_reviews('b0000000-0000-0000-0000-000000000001') limit 1;
  assert r.rating = 4 and r.service_name is not null, 'the confirmed visit review is listed';
  assert r.reviewer is null or position(' ' in r.reviewer) = 0, 'first name only';
  assert (select rating_count from public.search_services() where partner_id = 'b0000000-0000-0000-0000-000000000001') >= 1, 'it counts towards the provider rating';
end $$;

-- My bookings: only my own, with the escrow and dispute status that drive the buttons.
:tolu
do $$ begin
  assert (select count(*) from public.my_bookings()) >= 5, 'the owner sees their bookings';
  assert not exists (select 1 from public.my_bookings() where pet_id not in (select id from public.pets where owner_user_id = 'a0000000-0000-0000-0000-000000000001')), 'only their own pets';
  assert (select escrow_status from public.my_bookings() where booking_id = current_setting('test.x')::uuid) = 'ready', 'confirmed visit shows ready';
  assert (select rating from public.my_bookings() where booking_id = current_setting('test.x')::uuid) = 4, 'with their rating';
  assert (select can_cancel_until from public.my_bookings() where booking_id = current_setting('test.q')::uuid) is not null, 'cancel cut off is shown';
end $$;
:kemi
do $$ begin
  assert not exists (select 1 from public.my_bookings() where booking_id = current_setting('test.x')::uuid), 'someone else does not see them';
  assert (select count(*) from public.my_bookings() where booking_id = current_setting('test.d1')::uuid) = 1, 'but sees their own dispute';
  assert (select dispute_status from public.my_bookings() where booking_id = current_setting('test.d1')::uuid) is not null, 'with the dispute status';
end $$;
:anon
do $$ begin
  assert test_helpers.state($q$ select * from public.my_bookings() $q$) <> 'ok', 'signed out cannot list bookings';
  assert test_helpers.state($q$ select public.create_booking('51000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', now() + interval '3 days') $q$) <> 'ok', 'or book';
end $$;

-- Row level security: nobody edits money, bookings or reviews directly (no grant, or no row visible to change).
reset role;
create function test_helpers.cannot_change(q text) returns boolean
language plpgsql as $$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  return n = 0;
exception when insufficient_privilege or check_violation or foreign_key_violation or others then
  return true;
end;
$$;
grant execute on function test_helpers.cannot_change(text) to authenticated, service_role;
grant usage on schema test_helpers to authenticated, service_role;
:tolu
do $$ begin
  assert test_helpers.cannot_change(format($q$ update public.bookings set status = 'completed' where id = %L $q$, current_setting('test.z'))), 'an owner cannot change a booking directly';
  assert test_helpers.cannot_change(format($q$ update public.escrow_transactions set status = 'released' where id = (select escrow_transaction_id from public.bookings where id = %L) $q$, current_setting('test.x'))), 'or release money';
  assert test_helpers.cannot_change(format($q$ update public.reviews set rating = 1 where booking_id = %L $q$, current_setting('test.x'))), 'or rewrite a review';
  assert test_helpers.cannot_change($q$ insert into public.reviews (booking_id, rating) values (gen_random_uuid(), 5) $q$), 'or post one';
  assert test_helpers.cannot_change($q$ insert into public.escrow_transactions (booking_id, amount_kobo, fee_kobo, status) values (gen_random_uuid(), 1, 0, 'held') $q$), 'or create money';
end $$;
:amina
do $$ begin
  assert test_helpers.cannot_change(format($q$ update public.bookings set status = 'completed' where id = %L $q$, current_setting('test.y'))), 'a provider cannot change a booking directly either';
end $$;

reset role;
rollback;
\echo Services tests passed
