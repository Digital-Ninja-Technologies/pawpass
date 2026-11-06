-- Payout sending tests (milestone 7): what a run pays, the order of release, retries, and who may send.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/payout.test.sql
-- Needs seed.sql. Runs in one transaction that is rolled back. Prints "Payout tests passed" on success.

\set QUIET on
\set amina 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000002'', true); end $$; set local role authenticated;'
\set chidi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000003'', true); end $$; set local role authenticated;'
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

-- Amina's clinic b...01 is paid; Royal Paws (b...02, Chidi) has no payout account; the second clinic b...a1 is paid.
:server
insert into public.partner_payout_accounts (partner_account_id, bank_code, bank_name, account_number, account_name) values
  ('b0000000-0000-0000-0000-000000000001', '058', 'Guaranty Trust Bank', '0123456789', 'Paws and Claws'),
  ('b0000000-0000-0000-0000-0000000000a1', '044', 'Access Bank', '0987654321', 'Lekki Animal Hospital');

insert into public.escrow_transactions (id, payer_user_id, payee_partner_id, kind, amount_kobo, fee_kobo, status, paystack_reference) values
  ('e7000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking', 1000000, 120000, 'held', 'ref-po-1'),
  ('e7000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking', 500000, 60000, 'held', 'ref-po-2'),
  ('e7000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'puppy_deposit', 2000000, 0, 'held', 'ref-po-3'),
  ('e7000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking', 1000000, 120000, 'held', 'ref-po-4'),
  ('e7000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-0000000000a1', 'booking', 1000000, 120000, 'held', 'ref-po-5');
update public.escrow_transactions set status = 'ready' where id in
  ('e7000000-0000-0000-0000-000000000001', 'e7000000-0000-0000-0000-000000000002', 'e7000000-0000-0000-0000-000000000003');
-- A split: 400,000 refunded, the rest (net of its share of the fee) is the clinic's.
update public.escrow_transactions set status = 'paused' where id = 'e7000000-0000-0000-0000-000000000004';
update public.escrow_transactions set status = 'partially_refunded', refund_kobo = 400000 where id = 'e7000000-0000-0000-0000-000000000004';

do $$ begin
  assert private.escrow_net((select e from public.escrow_transactions e where id = 'e7000000-0000-0000-0000-000000000001')) = 880000, 'ready money is net of the fee';
  assert private.escrow_net((select e from public.escrow_transactions e where id = 'e7000000-0000-0000-0000-000000000004')) = 528000, 'a split keeps its share of the fee: 600,000 less 72,000';
  assert private.escrow_net((select e from public.escrow_transactions e where id = 'e7000000-0000-0000-0000-000000000002')) = 440000, 'another ready row';
end $$;

-- ---------------------------------------------------------------------------
-- Preparing a run
-- ---------------------------------------------------------------------------
:amina
do $$ begin
  assert test_helpers.state($q$ select public.admin_prepare_payout_run(current_date) $q$) = '42501', 'partners cannot prepare a run';
end $$;

:admin
select set_config('test.run', public.admin_prepare_payout_run((now() at time zone 'Africa/Lagos')::date)::text, true);
do $$
declare r uuid := current_setting('test.run')::uuid;
begin
  assert (select count(*) from public.payout_items where payout_run_id = r) = 2, 'two partners have money ready';
  assert (select amount_kobo from public.payout_items where payout_run_id = r and partner_account_id = 'b0000000-0000-0000-0000-000000000001') = 1848000, 'the clinic: 880,000 + 440,000 + 528,000';
  assert (select status from public.payout_items where payout_run_id = r and partner_account_id = 'b0000000-0000-0000-0000-000000000002') = 'held', 'no bank account means held';
  assert (select note from public.payout_items where payout_run_id = r and partner_account_id = 'b0000000-0000-0000-0000-000000000002') like 'No payout account%', 'and says why';
  assert (select total_kobo from public.payout_runs where id = r) = 1848000 + 2000000, 'the run total lists everything, held items included';
  assert (select count(*) from public.payout_item_escrows l join public.payout_items i on i.id = l.payout_item_id
           where i.payout_run_id = r and i.partner_account_id = 'b0000000-0000-0000-0000-000000000001') = 3, 'each item records the escrows it pays';
  assert (select count(*) from public.audit_log where action = 'payout_run.prepare') = 1, 'preparing is audited';
end $$;

-- A refreshed draft is rebuilt, not doubled.
select public.admin_prepare_payout_run((now() at time zone 'Africa/Lagos')::date);
do $$ begin
  assert (select count(*) from public.payout_items where payout_run_id = current_setting('test.run')::uuid) = 2, 'refreshing replaces the items';
end $$;

-- Nothing is sent from a draft.
:payments
do $$ begin
  assert (select count(*) from public.claim_payout_items(10)) = 0, 'a draft run sends nothing';
end $$;

-- A dispute opens after the run was prepared: that money must not go out.
:server
update public.escrow_transactions set status = 'paused' where id = 'e7000000-0000-0000-0000-000000000002';

:admin
select public.admin_approve_payout_run(current_setting('test.run')::uuid);

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------
:amina
do $$ begin
  assert test_helpers.state($q$ select * from public.claim_payout_items(10) $q$) = '42501', 'partners cannot claim payouts';
  assert test_helpers.state($q$ select public.finish_payout_item(gen_random_uuid(), true, 'x') $q$) = '42501', 'nor finish them';
end $$;
:admin
do $$ begin
  assert test_helpers.state($q$ select * from public.claim_payout_items(10) $q$) = '42501', 'staff cannot send payouts from the console';
  assert test_helpers.state($q$ select public.schedule_payout_run() $q$) = '42501', 'nor run the schedule';
end $$;
:anon
do $$ begin
  assert test_helpers.state($q$ select * from public.claim_payout_items(10) $q$) = '42501', 'signed out users cannot claim';
end $$;

:payments
select set_config('test.claimed', (select count(*) from public.claim_payout_items(10))::text, true);
do $$
declare it public.payout_items;
begin
  assert current_setting('test.claimed')::int = 1, 'only the clinic is sent: the breeder is held';
  select * into it from public.payout_items where payout_run_id = current_setting('test.run')::uuid and partner_account_id = 'b0000000-0000-0000-0000-000000000001';
  perform set_config('test.item', it.id::text, true);
  assert it.status = 'sending' and it.attempts = 1, 'the item is being sent';
  assert it.amount_kobo = 880000 + 528000, 'the paused escrow dropped out: 880,000 + 528,000';
  assert (select status from public.escrow_transactions where id = 'e7000000-0000-0000-0000-000000000001') = 'released', 'the paid escrow is released first';
  assert (select paid_out_at from public.escrow_transactions where id = 'e7000000-0000-0000-0000-000000000001') is not null, 'with the time it went out';
  assert (select paid_out_at from public.escrow_transactions where id = 'e7000000-0000-0000-0000-000000000004') is not null, 'a split remainder is marked paid';
  assert (select status from public.escrow_transactions where id = 'e7000000-0000-0000-0000-000000000002') = 'paused', 'disputed money stays paused';
  assert (select status from public.escrow_transactions where id = 'e7000000-0000-0000-0000-000000000003') = 'ready', 'the breeder money waits for a payout account';
  assert (select count(*) from public.claim_payout_items(10)) = 0, 'a claimed item is not handed out twice';
end $$;

select public.finish_payout_item(current_setting('test.item')::uuid, true, 'TRF_001', null, 'RCP_001');
do $$
declare r uuid := current_setting('test.run')::uuid;
begin
  assert (select status from public.payout_items where id = current_setting('test.item')::uuid) = 'sent', 'sent';
  assert (select paystack_transfer_code from public.payout_items where id = current_setting('test.item')::uuid) = 'TRF_001', 'with the Paystack transfer code';
  assert (select paystack_recipient_code from public.partner_payout_accounts where partner_account_id = 'b0000000-0000-0000-0000-000000000001') = 'RCP_001', 'the recipient is remembered for next time';
  assert (select status from public.payout_runs where id = r) = 'sent', 'the run is sent once only held items remain';
  assert exists (select 1 from public.notifications where user_id = 'a0000000-0000-0000-0000-000000000002' and title = 'Your payout is on its way'), 'the partner is told';
  -- Finishing twice changes nothing.
  perform public.finish_payout_item(current_setting('test.item')::uuid, false, null, 'late');
  assert (select status from public.payout_items where id = current_setting('test.item')::uuid) = 'sent', 'a finished item stays finished';
  assert (select count(*) from public.claim_payout_items(10)) = 0, 'nothing more to send';
end $$;

-- Paystack later reports the transfer failed: the item is flagged for staff.
select public.mark_transfer_failed('TRF_001', 'Account closed');
do $$ begin
  assert (select status from public.payout_items where id = current_setting('test.item')::uuid) = 'failed', 'flagged failed';
  assert (select note from public.payout_items where id = current_setting('test.item')::uuid) like 'Paystack reported: Account closed', 'with the reason';
  assert (select count(*) from public.claim_payout_items(10)) = 0, 'and not retried by itself';
end $$;

-- ---------------------------------------------------------------------------
-- Failures are retried with the same money, three times
-- ---------------------------------------------------------------------------
:server
update public.escrow_transactions set status = 'ready' where id = 'e7000000-0000-0000-0000-000000000005';
:admin
select set_config('test.run2', public.admin_prepare_payout_run(((now() at time zone 'Africa/Lagos')::date - 1))::text, true);
do $$ begin
  assert (select status from public.payout_items where payout_run_id = current_setting('test.run2')::uuid and partner_account_id = 'b0000000-0000-0000-0000-0000000000a1') = 'pending', 'the second clinic is ready';
end $$;
select public.admin_approve_payout_run(current_setting('test.run2')::uuid);

:payments
do $$
declare it uuid;
begin
  select item_id into it from public.claim_payout_items(10) where partner_id = 'b0000000-0000-0000-0000-0000000000a1';
  assert it is not null, 'claimed';
  perform set_config('test.item2', it::text, true);
  assert (select status from public.escrow_transactions where id = 'e7000000-0000-0000-0000-000000000005') = 'released', 'released at the first claim';
  perform public.finish_payout_item(it, false, null, 'Insufficient balance');
  assert (select status from public.payout_items where id = it) = 'failed' and (select attempts from public.payout_items where id = it) = 1, 'first failure';
  assert (select status from public.payout_runs where id = current_setting('test.run2')::uuid) = 'approved', 'the run waits for the retry';

  -- Second try: same amount, no new release.
  assert (select amount_kobo from public.claim_payout_items(10) where item_id = it) = 880000, 'retried with the same amount';
  perform public.finish_payout_item(it, false, null, 'Insufficient balance');
  assert (select amount_kobo from public.claim_payout_items(10) where item_id = it) = 880000, 'third try';
  perform public.finish_payout_item(it, false, null, 'Insufficient balance');
  assert (select attempts from public.payout_items where id = it) = 3, 'three attempts';
  assert (select count(*) from public.claim_payout_items(10) where item_id = it) = 0, 'then it stops';
  assert (select status from public.payout_runs where id = current_setting('test.run2')::uuid) = 'failed', 'the run is marked failed for staff';
end $$;

-- A stuck "sending" item (the function died) is handed out again after 15 minutes.
:server
insert into public.escrow_transactions (id, payer_user_id, payee_partner_id, kind, amount_kobo, fee_kobo, status, paystack_reference)
  values ('e7000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-0000000000a1', 'booking', 1000000, 120000, 'held', 'ref-po-6');
update public.escrow_transactions set status = 'ready' where id = 'e7000000-0000-0000-0000-000000000006';
:admin
select set_config('test.run3', public.admin_prepare_payout_run(((now() at time zone 'Africa/Lagos')::date - 2))::text, true);
select public.admin_approve_payout_run(current_setting('test.run3')::uuid);
:payments
do $$
declare it uuid;
begin
  select item_id into it from public.claim_payout_items(10);
  assert it is not null, 'claimed';
  assert (select count(*) from public.claim_payout_items(10)) = 0, 'not handed out while fresh';
  update public.payout_items set attempted_at = now() - interval '20 minutes' where id = it;
  assert (select count(*) from public.claim_payout_items(10) where item_id = it) = 1, 'handed out again when stuck';
end $$;

-- ---------------------------------------------------------------------------
-- The weekly schedule
-- ---------------------------------------------------------------------------
:payments
select set_config('test.sched', public.schedule_payout_run()::text, true);
do $$
declare r public.payout_runs;
begin
  select * into r from public.payout_runs where id = current_setting('test.sched')::uuid;
  assert r.status = 'draft', 'the schedule makes a draft for staff to review';
  assert extract(isodow from r.run_on) = (select payout_weekday from public.settings limit 1), 'on the payout weekday';
  assert r.run_on >= (now() at time zone 'Africa/Lagos')::date and r.run_on < (now() at time zone 'Africa/Lagos')::date + 7, 'within the coming week';
  assert public.schedule_payout_run() = r.id, 'running again refreshes the same draft';
  update public.payout_runs set status = 'approved' where id = r.id;
  assert public.schedule_payout_run() is null, 'an approved run is never touched';
end $$;

reset role;
rollback;
\echo Payout tests passed
