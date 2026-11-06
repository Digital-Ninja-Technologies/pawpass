-- Adopt and transfer tests (milestone 5): listings, puppy orders and their escrow, handover, passport transfer,
-- the vet check window, problems, adoption applications.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/adopt.test.sql
-- Needs seed.sql. Runs in one transaction that is rolled back. Prints "Adopt tests passed" on success.

\set QUIET on
\set tolu 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set chidi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000003'', true); end $$; set local role authenticated;'
\set ngozi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000004'', true); end $$; set local role authenticated;'
\set kemi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); end $$; set local role authenticated;'
\set admin 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000007'', true); end $$; set local role authenticated;'
\set anon 'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
\set server 'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$;'
\set payments 'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role service_role;'

begin;

create schema test_helpers;
grant usage on schema test_helpers to anon, authenticated, service_role;
create function test_helpers.state(q text) returns text
language plpgsql as $$
begin
  execute q;
  return 'ok';
exception when others then
  return sqlstate;
end;
$$;
grant execute on all functions in schema test_helpers to anon, authenticated, service_role;

-- Seed: Royal Paws Kennels (partner b...02, Chidi u3) lists Duke (c...03, sale 450,000 naira, live).
--       Lagos Paws Rescue (partner b...03, Ngozi u4) lists Biscuit (c...04, adoption, live).
-- Buyers: Tolu u1 and Kemi u5.

:server
select set_config('test.duke', (select id::text from public.listings where pet_id = 'c0000000-0000-0000-0000-000000000003'), true);
select set_config('test.biscuit', (select id::text from public.listings where pet_id = 'c0000000-0000-0000-0000-000000000004'), true);
update public.pets set mother_pet_id = 'c0000000-0000-0000-0000-000000000002', father_pet_id = 'c0000000-0000-0000-0000-000000000001'
 where id = 'c0000000-0000-0000-0000-000000000003';
insert into public.health_records (pet_id, type, name, given_on, given_by_partner_id, verified_by_partner_id, verified_at, added_by_user_id) values
  ('c0000000-0000-0000-0000-000000000003', 'vaccine', 'DHPP', current_date - 14, 'b0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', now(), 'a0000000-0000-0000-0000-000000000002'),
  ('c0000000-0000-0000-0000-000000000003', 'deworming', 'Deworming', current_date - 20, null, null, null, 'a0000000-0000-0000-0000-000000000003'),
  ('c0000000-0000-0000-0000-000000000003', 'weight', 'Weight', current_date - 3, null, null, null, 'a0000000-0000-0000-0000-000000000003');
insert into public.pets (id, owner_user_id, name, species, breed, sex, date_of_birth) values
  ('c0000000-0000-0000-0000-0000000000d1', 'a0000000-0000-0000-0000-000000000003', 'Nala', 'dog', 'German Shepherd', 'female', current_date - 70),
  ('c0000000-0000-0000-0000-0000000000d2', 'a0000000-0000-0000-0000-000000000003', 'Zuri', 'dog', 'Boerboel', 'female', current_date - 60);
insert into public.listings (id, partner_account_id, pet_id, kind, price_kobo, status) values
  ('d0000000-0000-0000-0000-0000000000d1', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-0000000000d1', 'sale', 38000000, 'live'),
  ('d0000000-0000-0000-0000-0000000000d2', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-0000000000d2', 'sale', 20000000, 'live');

-- ---------------------------------------------------------------------------
-- Browsing a listing
-- ---------------------------------------------------------------------------
:tolu
do $$
declare d jsonb; r record;
begin
  assert (select count(*) from public.adopt_listings()) >= 4, 'listings are visible to signed in people';
  assert (select count(*) from public.adopt_listings('adoption')) = 1, 'filter by adoption';
  assert (select pet_name from public.adopt_listings('adoption')) = 'Biscuit', 'that is Biscuit';
  assert not exists (select 1 from public.adopt_listings('sale') where kind <> 'sale'), 'filter by sale';
  assert exists (select 1 from public.adopt_listings(null, 'dog', 'duke') where pet_name = 'Duke'), 'search by name';
  assert not exists (select 1 from public.adopt_listings(null, 'cat')), 'species filter';
  select * into r from public.adopt_listings() where pet_name = 'Duke';
  assert r.price_kobo = 45000000 and r.partner_name = 'Royal Paws Kennels' and r.partner_type = 'breeder' and not r.reserved, 'Duke row';

  d := public.listing_detail(current_setting('test.duke')::uuid);
  assert (d ->> 'price_kobo')::bigint = 45000000, 'price';
  assert (d ->> 'deposit_kobo')::bigint = 15000000, 'deposit is a third (150,000 naira)';
  assert (d ->> 'protection_fee_kobo')::bigint = 750000, 'protection fee is 5% of the deposit (7,500 naira)';
  assert (d ->> 'due_today_kobo')::bigint = 15750000, 'pay today 157,500 naira';
  assert (d ->> 'balance_kobo')::bigint = 30000000, 'balance 300,000 naira';
  assert d -> 'partner' ->> 'name' = 'Royal Paws Kennels' and (d -> 'partner' ->> 'verified')::boolean, 'a verified breeder';
  assert d ->> 'mother_name' = 'Mimi' and d ->> 'father_name' = 'Bingo', 'parents';
  assert jsonb_array_length(d -> 'records') = 2, 'vaccines and deworming are shown, weight is not';
  assert (select (x ->> 'verified')::boolean from jsonb_array_elements(d -> 'records') x where x ->> 'name' = 'DHPP'), 'the vet verified vaccine says so';
  assert not (d ? 'phone') and not (d -> 'partner' ? 'phone'), 'no phone numbers';
  assert d ->> 'my_order_id' is null and d ->> 'my_application_id' is null, 'nothing yet';
  assert test_helpers.state($q$ select public.listing_detail(gen_random_uuid()) $q$) = 'P0002', 'unknown listing';
end $$;
:anon
do $$ begin
  assert test_helpers.state($q$ select * from public.adopt_listings() $q$) = '42501', 'signed out people cannot browse';
end $$;

-- Message the seller
:tolu
do $$
declare c1 uuid; c2 uuid;
begin
  c1 := public.open_listing_chat(current_setting('test.duke')::uuid);
  c2 := public.open_listing_chat(current_setting('test.duke')::uuid);
  assert c1 = c2, 'one chat per buyer and listing';
  assert (select context_label from public.my_conversations() where conversation_id = c1) = 'Listing · Duke', 'the inbox names it after the pet';
  assert (select other_name from public.my_conversations() where conversation_id = c1) = 'Chidi', 'with the seller';
end $$;
:chidi
do $$ begin
  assert test_helpers.state(format($q$ select public.open_listing_chat(%L) $q$, current_setting('test.duke'))) = '22023', 'not on your own listing';
end $$;

-- ---------------------------------------------------------------------------
-- Buying Duke: deposit
-- ---------------------------------------------------------------------------
:chidi
do $$ begin
  assert test_helpers.state(format($q$ select public.create_puppy_order(%L) $q$, current_setting('test.duke'))) = '22023', 'cannot buy your own listing';
end $$;
:tolu
do $$
declare o jsonb; again jsonb;
begin
  assert test_helpers.state(format($q$ select public.create_puppy_order(%L) $q$, current_setting('test.biscuit'))) = '22023', 'an adoption is not bought';
  o := public.create_puppy_order(current_setting('test.duke')::uuid);
  again := public.create_puppy_order(current_setting('test.duke')::uuid);
  assert (o ->> 'order_id') = (again ->> 'order_id') and (o ->> 'reference') = (again ->> 'reference'), 'paying twice reuses the unpaid order';
  assert (o ->> 'reference') ~ '^pd_[0-9a-f]{32}$', 'reference shape';
  assert (o ->> 'amount_kobo')::bigint = 15750000, 'to pay today';
  perform set_config('test.tolu_order', o ->> 'order_id', true);
  perform set_config('test.tolu_ref', o ->> 'reference', true);
  assert (select count(*) from public.puppy_orders) = 1, 'the buyer sees their order only';
end $$;
:kemi
do $$ declare o jsonb; begin
  o := public.create_puppy_order(current_setting('test.duke')::uuid);
  perform set_config('test.kemi_order', o ->> 'order_id', true);
  perform set_config('test.kemi_ref', o ->> 'reference', true);
  assert (select count(*) from public.puppy_orders) = 1, 'Kemi sees only hers';
  assert test_helpers.state(format($q$ select public.create_balance_payment(%L) $q$, current_setting('test.tolu_order'))) = '42501', 'not someone else''s order';
  assert test_helpers.state(format($q$ select public.create_balance_payment(%L) $q$, current_setting('test.kemi_order'))) = 'P0001', 'balance only after the deposit';
  assert test_helpers.state($q$ select public.confirm_order_payment('x', 1) $q$) <> 'ok', 'only the payments function confirms';
end $$;

:payments
do $$
declare r jsonb; e record; ref text := current_setting('test.tolu_ref');
begin
  assert test_helpers.state(format($q$ select public.confirm_order_payment(%L, 15749999) $q$, ref)) = 'P0001', 'the wrong amount is refused';
  assert test_helpers.state($q$ select public.confirm_order_payment('pd_unknown', 1) $q$) = 'P0002', 'unknown reference';
  r := public.confirm_order_payment(ref, 15750000);
  assert r ->> 'result' = 'confirmed' and r ->> 'order_status' = 'deposit_paid', 'deposit confirmed';
  assert (public.confirm_order_payment(ref, 15750000) ->> 'result') = 'already_confirmed', 'idempotent';
  select * into e from public.escrow_transactions where paystack_reference = ref;
  assert e.kind = 'puppy_deposit' and e.status = 'held' and e.amount_kobo = 15750000 and e.fee_kobo = 750000
    and e.payee_partner_id = 'b0000000-0000-0000-0000-000000000002', 'deposit held, fee recorded';
  assert (select status from public.listings where id = current_setting('test.duke')::uuid) = 'reserved', 'the listing is reserved';
  assert (select count(*) from public.notifications where dedupe_key in ('order-deposit:' || current_setting('test.tolu_order'), 'order-deposit-p:' || current_setting('test.tolu_order'))) = 2, 'both sides are told';

  r := public.confirm_order_payment(current_setting('test.kemi_ref'), 15750000);
  assert r ->> 'result' = 'refunded' and r ->> 'order_status' = 'cancelled', 'a late payment is refunded';
  select * into e from public.escrow_transactions where paystack_reference = current_setting('test.kemi_ref');
  assert e.status = 'refunded' and e.refund_kobo = e.amount_kobo and e.refund_status = 'pending', 'queued for Paystack';
end $$;

:tolu
do $$ begin
  assert (select reserved from public.adopt_listings() where pet_name = 'Duke'), 'Duke shows as reserved';
  assert test_helpers.state(format($q$ select public.create_puppy_order(%L) $q$, current_setting('test.duke'))) = 'P0001', 'nobody else can order a reserved pet';
  assert (public.listing_detail(current_setting('test.duke')::uuid) ->> 'my_order_status') = 'deposit_paid', 'the listing knows my order';
  assert test_helpers.state(format($q$ select public.cancel_unpaid_order(%L) $q$, current_setting('test.tolu_order'))) = 'P0001', 'a paid order is not cancelled by the buyer';
end $$;

-- Balance, at pick up
:tolu
do $$
declare b jsonb; again jsonb;
begin
  b := public.create_balance_payment(current_setting('test.tolu_order')::uuid);
  again := public.create_balance_payment(current_setting('test.tolu_order')::uuid);
  assert b ->> 'reference' = again ->> 'reference' and b ->> 'reference' ~ '^pb_[0-9a-f]{32}$', 'one balance reference';
  assert (b ->> 'amount_kobo')::bigint = 30000000, 'the balance';
  perform set_config('test.tolu_bal', b ->> 'reference', true);
end $$;
:payments
do $$
declare r jsonb; e record;
begin
  assert test_helpers.state(format($q$ select public.confirm_order_payment(%L, 1) $q$, current_setting('test.tolu_bal'))) = 'P0001', 'wrong balance amount';
  r := public.confirm_order_payment(current_setting('test.tolu_bal'), 30000000);
  assert r ->> 'order_status' = 'balance_paid', 'balance confirmed';
  select * into e from public.escrow_transactions where paystack_reference = current_setting('test.tolu_bal');
  assert e.kind = 'puppy_balance' and e.status = 'held' and e.fee_kobo = 0, 'balance held';
end $$;
:tolu
do $$ begin
  assert test_helpers.state(format($q$ select public.create_balance_payment(%L) $q$, current_setting('test.tolu_order'))) = 'P0001', 'the balance is paid once';
end $$;

-- ---------------------------------------------------------------------------
-- Handover, passport transfer, the vet check window
-- ---------------------------------------------------------------------------
:server
insert into public.passport_shares (pet_id, partner_account_id, token_hash, scopes, expires_at)
values ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'hash-duke', array['health'], now() + interval '1 day');

:tolu
do $$ begin
  assert test_helpers.state(format($q$ select public.partner_confirm_handover(%L) $q$, current_setting('test.tolu_order'))) = '42501', 'the buyer cannot confirm the handover';
end $$;
:kemi
do $$ begin
  assert test_helpers.state(format($q$ select public.partner_confirm_handover(%L) $q$, current_setting('test.tolu_order'))) = '42501', 'nor can a stranger';
end $$;
:chidi
do $$
declare t uuid; o record;
begin
  t := public.partner_confirm_handover(current_setting('test.tolu_order')::uuid);
  perform set_config('test.duke_transfer', t::text, true);
  select * into o from public.puppy_orders where id = current_setting('test.tolu_order')::uuid;
  assert o.status = 'handed_over' and o.handed_over_at is not null, 'handed over';
  assert o.vet_check_ends_at between now() + interval '71 hours 59 minutes' and now() + interval '72 hours 1 minute', '72 hour window';
  assert (select status from public.listings where id = current_setting('test.duke')::uuid) = 'sold', 'sold';
  assert (select completed_at from public.ownership_transfers where id = t) is null, 'the passport has not moved yet';
  assert test_helpers.state(format($q$ select public.partner_confirm_handover(%L) $q$, current_setting('test.tolu_order'))) = 'P0001', 'only once';
  assert test_helpers.state(format($q$ select public.partner_cancel_order(%L) $q$, current_setting('test.tolu_order'))) = 'P0001', 'no cancelling after handover';
end $$;
:server
do $$ begin
  assert (select owner_user_id from public.pets where id = 'c0000000-0000-0000-0000-000000000003') = 'a0000000-0000-0000-0000-000000000003', 'Duke is still Chidi''s until accepted';
end $$;
:kemi
do $$ begin
  assert test_helpers.state(format($q$ select public.accept_passport(%L) $q$, current_setting('test.duke_transfer'))) = '42501', 'only the receiver accepts';
end $$;
:tolu
do $$
declare d jsonb;
begin
  d := public.puppy_order_detail(current_setting('test.tolu_order')::uuid);
  assert d ->> 'status' = 'handed_over' and (d ->> 'deposit_paid')::boolean and (d ->> 'balance_paid')::boolean and d ->> 'transfer_id' = current_setting('test.duke_transfer'), 'the order screen has what it needs';
  assert not (d ? 'phone') and (d ->> 'is_buyer')::boolean, 'no contact details';
  perform public.accept_passport(current_setting('test.duke_transfer')::uuid);
  assert (select owner_user_id from public.pets where id = 'c0000000-0000-0000-0000-000000000003') = 'a0000000-0000-0000-0000-000000000001', 'Duke is now Tolu''s';
  assert (select count(*) from public.health_records where pet_id = 'c0000000-0000-0000-0000-000000000003') = 3, 'with the whole record';
  assert test_helpers.state(format($q$ select public.accept_passport(%L) $q$, current_setting('test.duke_transfer'))) = 'P0001', 'accepting twice is refused';
end $$;
:server
do $$ begin
  assert (select revoked_at from public.passport_shares where token_hash = 'hash-duke') is not null, 'the seller''s vet links stop working';
  assert (select completed_at from public.ownership_transfers where id = current_setting('test.duke_transfer')::uuid) is not null, 'transfer complete';
end $$;
:chidi
do $$ begin
  assert exists (select 1 from public.pets where id = 'c0000000-0000-0000-0000-000000000003'), 'the seller keeps a record of the pet';
  assert (select count(*) from public.ownership_transfers) = 1, 'and of the transfer';
  assert (select owner_user_id from public.pets where id = 'c0000000-0000-0000-0000-000000000003') <> 'a0000000-0000-0000-0000-000000000003', 'but it is not theirs';
end $$;

-- A problem inside the window holds both payments until staff decide.
:tolu
do $$ begin
  assert test_helpers.state(format($q$ select public.open_order_dispute(%L, 'nonsense') $q$, current_setting('test.tolu_order'))) = '22023', 'choose a listed reason';
  perform public.open_order_dispute(current_setting('test.tolu_order')::uuid, 'health_problem', 'The vet found parvo.');
  assert (select status from public.puppy_orders where id = current_setting('test.tolu_order')::uuid) = 'disputed', 'disputed';
  assert not exists (select 1 from public.escrow_transactions e join public.puppy_orders o on e.id in (o.deposit_escrow_id, o.balance_escrow_id)
                      where o.id = current_setting('test.tolu_order')::uuid and e.status <> 'paused'), 'both payments are paused';
  assert test_helpers.state(format($q$ select public.open_order_dispute(%L, 'other') $q$, current_setting('test.tolu_order'))) = 'P0001', 'one report at a time';
  assert (public.puppy_order_detail(current_setting('test.tolu_order')::uuid) ->> 'dispute_status') = 'open', 'the order shows the report';
end $$;
:chidi
do $$ begin
  assert (select count(*) from public.notifications where dedupe_key = 'order-disputed-p:' || current_setting('test.tolu_order')) = 1, 'the seller is told';
end $$;
:admin
do $$
declare d uuid;
begin
  select x.id into d from public.disputes x join public.puppy_orders o on x.escrow_transaction_id in (o.deposit_escrow_id, o.balance_escrow_id) where o.id = current_setting('test.tolu_order')::uuid;
  assert test_helpers.state(format($q$ select public.admin_decide_dispute(%L, 'split', 500000) $q$, d)) = '22023', 'puppy sales have no split';
  perform public.admin_decide_dispute(d, 'refund', null, 'Vet report seen');
end $$;
:server
do $$ begin
  assert (select status from public.puppy_orders where id = current_setting('test.tolu_order')::uuid) = 'cancelled', 'the order is cancelled';
  assert (select count(*) from public.escrow_transactions e join public.puppy_orders o on e.id in (o.deposit_escrow_id, o.balance_escrow_id)
           where o.id = current_setting('test.tolu_order')::uuid and e.status = 'refunded' and e.refund_status = 'pending') = 2, 'both payments are refunded and queued';
  assert (select sum(e.refund_kobo) from public.escrow_transactions e join public.puppy_orders o on e.id in (o.deposit_escrow_id, o.balance_escrow_id)
           where o.id = current_setting('test.tolu_order')::uuid) = 45750000, 'the buyer gets back everything including the protection fee';
  assert (select count(*) from public.notifications where dedupe_key = 'order-decided:' || current_setting('test.tolu_order')) = 1, 'the buyer is told';
end $$;

-- ---------------------------------------------------------------------------
-- Nala: a clean sale, released after the window
-- ---------------------------------------------------------------------------
:kemi
do $$ declare o jsonb; begin
  o := public.create_puppy_order('d0000000-0000-0000-0000-0000000000d1');
  perform set_config('test.nala_order', o ->> 'order_id', true);
  perform set_config('test.nala_ref', o ->> 'reference', true);
  assert (o ->> 'deposit_kobo')::bigint = 12666667 and (o ->> 'protection_fee_kobo')::bigint = 633333 and (o ->> 'balance_kobo')::bigint = 25333333, 'deposit rounds up, balance is the rest';
  assert (o ->> 'deposit_kobo')::bigint + (o ->> 'balance_kobo')::bigint = 38000000, 'deposit and balance add up to the price';
end $$;
:payments
select public.confirm_order_payment(current_setting('test.nala_ref'), 13300000);
:kemi
do $$ declare b jsonb; begin
  b := public.create_balance_payment(current_setting('test.nala_order')::uuid);
  perform set_config('test.nala_bal', b ->> 'reference', true);
end $$;
:payments
select public.confirm_order_payment(current_setting('test.nala_bal'), 25333333);
:chidi
select public.partner_confirm_handover(current_setting('test.nala_order')::uuid);
:payments
do $$ begin
  assert public.release_due_orders() = 0, 'nothing is released inside the window';
  update public.puppy_orders set vet_check_ends_at = now() - interval '1 minute' where id = current_setting('test.nala_order')::uuid;
end $$;
:kemi
do $$ begin
  assert test_helpers.state(format($q$ select public.open_order_dispute(%L, 'other') $q$, current_setting('test.nala_order'))) = 'P0001', 'too late to report once the window has ended';
end $$;
:payments
do $$ begin
  assert public.release_due_orders() = 1, 'released after the window';
  assert public.release_due_orders() = 0, 'once';
  assert (select status from public.puppy_orders where id = current_setting('test.nala_order')::uuid) = 'completed', 'complete';
  assert (select count(*) from public.escrow_transactions e join public.puppy_orders o on e.id in (o.deposit_escrow_id, o.balance_escrow_id)
           where o.id = current_setting('test.nala_order')::uuid and e.status = 'ready') = 2, 'both payments are ready for payout';
  assert (select owner_user_id from public.pets where id = 'c0000000-0000-0000-0000-0000000000d1') = 'a0000000-0000-0000-0000-000000000005', 'the buyer owns the pet even if they never tapped accept';
end $$;
:admin
do $$ declare r uuid; begin
  r := public.admin_prepare_payout_run(current_date + 40);
  assert (select amount_kobo from public.payout_items where payout_run_id = r and partner_account_id = 'b0000000-0000-0000-0000-000000000002')
       = (select sum(amount_kobo - fee_kobo) from public.escrow_transactions where payee_partner_id = 'b0000000-0000-0000-0000-000000000002' and status = 'ready'),
    'the breeder is paid the ready money net of fees';
  assert (select sum(e.amount_kobo - e.fee_kobo) from public.escrow_transactions e join public.puppy_orders o on e.id in (o.deposit_escrow_id, o.balance_escrow_id) where o.id = current_setting('test.nala_order')::uuid) = 38000000, 'Nala nets exactly the price: the protection fee stays with PawPass';
end $$;

-- ---------------------------------------------------------------------------
-- Zuri: seller cancels, unpaid orders
-- ---------------------------------------------------------------------------
:tolu
do $$ declare o jsonb; begin
  o := public.create_puppy_order('d0000000-0000-0000-0000-0000000000d2');
  perform public.cancel_unpaid_order((o ->> 'order_id')::uuid);
  assert (select status from public.puppy_orders where id = (o ->> 'order_id')::uuid) = 'cancelled', 'an unpaid order can be dropped';
  o := public.create_puppy_order('d0000000-0000-0000-0000-0000000000d2');
  perform set_config('test.zuri_order', o ->> 'order_id', true);
  perform set_config('test.zuri_ref', o ->> 'reference', true);
  assert (o ->> 'amount_kobo')::bigint = 7000000, 'Zuri''s deposit and fee';
end $$;
:payments
select public.confirm_order_payment(current_setting('test.zuri_ref'), 7000000);
:kemi
do $$ begin
  assert test_helpers.state(format($q$ select public.partner_cancel_order(%L) $q$, current_setting('test.zuri_order'))) = '42501', 'a buyer cannot cancel as the seller';
end $$;
:chidi
do $$ begin
  perform public.partner_cancel_order(current_setting('test.zuri_order')::uuid, 'Puppy is unwell');
  assert (select status from public.puppy_orders where id = current_setting('test.zuri_order')::uuid) = 'cancelled', 'cancelled';
  assert (select status from public.listings where id = 'd0000000-0000-0000-0000-0000000000d2') = 'live', 'back on the market';
  assert test_helpers.state(format($q$ select public.partner_cancel_order(%L) $q$, current_setting('test.zuri_order'))) = 'P0001', 'once';
end $$;
:server
do $$ begin
  assert (select e.status || '/' || e.refund_kobo || '/' || e.refund_status from public.escrow_transactions e where e.paystack_reference = current_setting('test.zuri_ref')) = 'refunded/7000000/pending', 'the buyer is refunded in full and it is queued';
  assert (select count(*) from public.notifications where dedupe_key = 'order-cancelled:' || current_setting('test.zuri_order')) = 1, 'the buyer is told';
end $$;

-- Orders cannot be written from the app
:tolu
do $$ begin
  assert test_helpers.state($q$ update public.puppy_orders set status = 'completed' $q$) <> 'ok' or (select count(*) from public.puppy_orders where status = 'completed' and buyer_user_id = 'a0000000-0000-0000-0000-000000000001') = 0, 'no direct updates';
  assert test_helpers.state($q$ insert into public.puppy_orders (listing_id, buyer_user_id, partner_account_id, pet_id, price_kobo, deposit_kobo, protection_fee_kobo, balance_kobo, deposit_reference) values (gen_random_uuid(), 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 1, 1, 0, 0, 'x') $q$) <> 'ok', 'no direct inserts';
end $$;

-- ---------------------------------------------------------------------------
-- Adoption
-- ---------------------------------------------------------------------------
:tolu
do $$
declare app uuid;
  good jsonb := '{"home_type":"house","other_pets":"Bingo and Mimi","daytime":"I work from home","why":"Bingo needs a calm companion and Biscuit looks perfect.","agree_visit":true}';
begin
  assert test_helpers.state(format($q$ select public.apply_to_adopt(%L, '{"why":"A long enough reason to adopt","agree_visit":true}') $q$, current_setting('test.biscuit'))) = '22023', 'tell us about your home';
  assert test_helpers.state(format($q$ select public.apply_to_adopt(%L, '{"home_type":"flat","why":"short","agree_visit":true}') $q$, current_setting('test.biscuit'))) = '22023', 'why needs a few words';
  assert test_helpers.state(format($q$ select public.apply_to_adopt(%L, '{"home_type":"flat","why":"A long enough reason to adopt","agree_visit":false}') $q$, current_setting('test.biscuit'))) = '22023', 'the home visit must be agreed';
  assert test_helpers.state(format($q$ select public.apply_to_adopt(%L, %L) $q$, current_setting('test.duke'), good::text)) = 'P0001', 'sale listings take no applications';
  app := public.apply_to_adopt(current_setting('test.biscuit')::uuid, good);
  perform set_config('test.tolu_app', app::text, true);
  assert test_helpers.state(format($q$ select public.apply_to_adopt(%L, %L) $q$, current_setting('test.biscuit'), good::text)) = 'P0001', 'one application per pet';
  assert (select status from public.my_applications() where application_id = app) = 'submitted', 'listed with its status';
  assert (public.listing_detail(current_setting('test.biscuit')::uuid) ->> 'my_application_status') = 'submitted', 'the listing knows';
  assert (select answers ->> 'why' from public.adoption_applications where id = app) like 'Bingo needs a calm%', 'answers are stored';
end $$;
:kemi
do $$ declare app uuid; begin
  app := public.apply_to_adopt(current_setting('test.biscuit')::uuid, '{"home_type":"flat","why":"A quiet flat and lots of time","agree_visit":true}');
  perform set_config('test.kemi_app', app::text, true);
  assert (select count(*) from public.my_applications()) = 1, 'Kemi sees only hers';
end $$;
:ngozi
do $$ begin
  assert test_helpers.state(format($q$ select public.apply_to_adopt(%L, '{"home_type":"flat","why":"A long enough reason","agree_visit":true}') $q$, current_setting('test.biscuit'))) = '22023', 'not on your own listing';
  assert (select count(*) from public.adoption_applications) = 2, 'the shelter sees both';
  assert (select count(*) from public.notifications where kind = 'booking' and title = 'New application for Biscuit') = 2, 'and was told';
  assert test_helpers.state(format($q$ select public.shelter_complete_adoption(%L) $q$, current_setting('test.tolu_app'))) = 'P0001', 'approve before handing over';
  update public.adoption_applications set status = 'home_visit' where id = current_setting('test.tolu_app')::uuid;
  update public.adoption_applications set status = 'approved' where id = current_setting('test.tolu_app')::uuid;
end $$;
:tolu
do $$ begin
  assert test_helpers.state(format($q$ select public.shelter_complete_adoption(%L) $q$, current_setting('test.tolu_app'))) = '42501', 'the adopter cannot hand over';
end $$;
:ngozi
do $$
declare t uuid;
begin
  t := public.shelter_complete_adoption(current_setting('test.tolu_app')::uuid);
  perform set_config('test.adopt_transfer', t::text, true);
  assert (select status from public.listings where id = current_setting('test.biscuit')::uuid) = 'adopted', 'adopted';
  assert (select status from public.adoption_applications where id = current_setting('test.kemi_app')::uuid) = 'declined', 'the others are declined';
  assert test_helpers.state(format($q$ select public.shelter_complete_adoption(%L) $q$, current_setting('test.tolu_app'))) = 'P0001', 'once';
end $$;
:kemi
do $$ begin
  assert test_helpers.state(format($q$ select public.transfer_detail(%L) $q$, current_setting('test.adopt_transfer'))) = 'P0002', 'not Kemi''s transfer';
  assert (select status from public.my_applications()) = 'declined', 'Kemi sees she was declined';
end $$;
:tolu
do $$
declare d jsonb;
begin
  d := public.transfer_detail(current_setting('test.adopt_transfer')::uuid);
  assert d ->> 'kind' = 'adoption' and d ->> 'pet_name' = 'Biscuit' and d ->> 'partner_name' = 'Lagos Paws Rescue' and (d ->> 'is_receiver')::boolean, 'the adopter sees the transfer';
  assert (select my_transfer_id from (select (public.listing_detail(current_setting('test.biscuit')::uuid) ->> 'my_transfer_id') as my_transfer_id) x) = current_setting('test.adopt_transfer'), 'the listing links to it';
  perform public.accept_passport(current_setting('test.adopt_transfer')::uuid);
  assert (select owner_user_id from public.pets where id = 'c0000000-0000-0000-0000-000000000004') = 'a0000000-0000-0000-0000-000000000001', 'Biscuit is Tolu''s';
  assert (public.transfer_detail(current_setting('test.adopt_transfer')::uuid) ->> 'completed_at') is not null, 'complete';
end $$;

reset role;
rollback;
\echo Adopt tests passed
