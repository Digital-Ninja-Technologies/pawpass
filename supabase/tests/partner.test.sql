-- Partner mode tests (milestone 6): becoming a partner, the verification steps, dashboards, earnings,
-- listings, adoption decisions, help and support.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/partner.test.sql
-- Needs seed.sql. Runs in one transaction that is rolled back. Prints "Partner tests passed" on success.

\set QUIET on
\set tolu 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set amina 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000002'', true); end $$; set local role authenticated;'
\set chidi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000003'', true); end $$; set local role authenticated;'
\set ngozi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000004'', true); end $$; set local role authenticated;'
\set kemi 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); end $$; set local role authenticated;'
\set bola 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000006'', true); end $$; set local role authenticated;'
\set admin 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000007'', true); end $$; set local role authenticated;'
\set anon 'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
\set server 'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$;'

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

-- ---------------------------------------------------------------------------
-- Starting an application
-- ---------------------------------------------------------------------------
:tolu
do $$
declare
  app jsonb;
  pid uuid;
begin
  assert public.partner_application() is null, 'a new partner has no application yet';

  assert test_helpers.state($q$ select public.partner_start('pirate', 'Tolu Kennels', 'Lekki') $q$) = '22023', 'the type must be one of the four';
  assert test_helpers.state($q$ select public.partner_start('breeder', 'T', 'Lekki') $q$) = '22023', 'a business name is required';
  assert test_helpers.state($q$ select public.partner_start('breeder', 'Tolu Kennels', '') $q$) = '22023', 'an area is required';

  pid := public.partner_start('breeder', 'Tolu Kennels', 'Lekki');
  perform set_config('test.tolu_partner', pid::text, true);
  app := public.partner_application();
  assert app ->> 'status' = 'draft' and app ->> 'type' = 'breeder', 'it starts as a draft breeder';
  assert (app ->> 'steps_total')::int = 4 and (app ->> 'steps_done')::int = 1, 'four steps for a breeder, the business details are done';
  assert not (app ->> 'can_submit')::boolean, 'it cannot be submitted yet';
  assert app -> 'payout' = 'null'::jsonb, 'no payout account yet';

  -- Starting again updates the same draft, and a draft can change type.
  assert public.partner_start('shelter', 'Tolu Rescue', 'Lekki') = pid, 'the draft is reused';
  assert (public.partner_application() ->> 'type') = 'shelter', 'a draft can change type';
  perform public.partner_start('breeder', 'Tolu Kennels', 'Lekki');

  assert test_helpers.state(format($q$ select public.submit_partner_for_review(%L) $q$, pid)) = 'P0001', 'an unfinished application cannot be submitted';
end $$;

-- ---------------------------------------------------------------------------
-- Documents and the payout account
-- ---------------------------------------------------------------------------
do $$
declare
  pid uuid := current_setting('test.tolu_partner')::uuid;
  me text := 'a0000000-0000-0000-0000-000000000001';
  app jsonb;
begin
  assert test_helpers.state(format($q$ select public.partner_add_document(%L, 'owner_id', 'a0000000-0000-0000-0000-000000000005/id.jpg') $q$, pid)) = '22023', 'files must be in your own folder';
  assert test_helpers.state(format($q$ select public.partner_add_document(%L, 'owner_id', 'a0000000-0000-0000-0000-000000000001/../x.jpg') $q$, pid)) = '22023', 'no path tricks';
  assert test_helpers.state(format($q$ select public.partner_add_document(%L, 'licence', %L) $q$, pid, me || '/l.jpg')) = '22023', 'only vets need a practising licence';
  assert test_helpers.state(format($q$ select public.partner_add_document(%L, 'passport', %L) $q$, pid, me || '/l.jpg')) = '22023', 'unknown document kinds are refused';

  perform public.partner_add_document(pid, 'owner_id', me || '/id.jpg');
  perform public.partner_add_document(pid, 'owner_id', me || '/id2.jpg');
  assert (select count(*) from public.partner_documents where partner_account_id = pid and kind = 'owner_id') = 1, 'a new upload replaces the old one';
  perform public.partner_add_document(pid, 'cac', me || '/cac.jpg');

  assert test_helpers.state(format($q$ select public.partner_save_payout_account(%L, '058', 'GTBank', '12345', 'Tolu Adeyemi') $q$, pid)) = '22023', 'an account number has 10 digits';
  assert test_helpers.state(format($q$ select public.partner_save_payout_account(%L, 'abc', 'GTBank', '0123456789', 'Tolu Adeyemi') $q$, pid)) = '22023', 'the bank code is digits';
  perform public.partner_save_payout_account(pid, '058', 'GTBank', '0123456789', 'Tolu Adeyemi');

  perform public.partner_add_document(pid, 'facility_photo', me || '/f1.jpg');
  perform public.partner_add_document(pid, 'facility_photo', me || '/f2.jpg');
  app := public.partner_application();
  assert not (app ->> 'can_submit')::boolean, 'two photos are not enough';
  perform public.partner_add_document(pid, 'facility_photo', me || '/f3.jpg');
  app := public.partner_application();
  assert (app ->> 'steps_done')::int = 4 and (app ->> 'can_submit')::boolean, 'all four steps are done';
  assert app #>> '{payout,last4}' = '6789', 'only the last four digits are shown';
  assert not (app::text like '%0123456789%'), 'the full account number is never returned';

  assert test_helpers.state(format($q$ select public.partner_add_document('b0000000-0000-0000-0000-000000000004', 'cac', %L) $q$, me || '/c.jpg')) = '42501', 'you cannot add to someone else''s application';
end $$;

:kemi
do $$ begin
  assert (select count(*) from public.partner_payout_accounts) = 0, 'payout accounts are private';
  assert (select count(*) from public.partner_documents where partner_account_id = current_setting('test.tolu_partner')::uuid) = 0, 'documents are private';
  assert test_helpers.state($q$ insert into public.partner_payout_accounts values (current_setting('test.tolu_partner')::uuid, '058', 'X', '0123456789', 'X') $q$) = '42501', 'no direct writes to the payout account';
end $$;

-- ---------------------------------------------------------------------------
-- Submitting, review and the decision notice
-- ---------------------------------------------------------------------------
:tolu
do $$
declare pid uuid := current_setting('test.tolu_partner')::uuid;
begin
  perform public.submit_partner_for_review(pid);
  assert (select status from public.partner_accounts where id = pid) = 'submitted', 'the application is submitted';
  assert exists (select 1 from public.notifications where user_id = 'a0000000-0000-0000-0000-000000000001' and title = 'We got your application'), 'the partner is told it was received';
  assert test_helpers.state(format($q$ select public.submit_partner_for_review(%L) $q$, pid)) = 'P0001', 'it cannot be submitted twice';
  assert test_helpers.state(format($q$ select public.partner_add_document(%L, 'cac', 'a0000000-0000-0000-0000-000000000001/c2.jpg') $q$, pid)) = 'P0001', 'documents are locked while it is reviewed';
  assert test_helpers.state($q$ select public.partner_start('vet', 'Another', 'Yaba') $q$) = 'P0001', 'a second application is refused while one is in review';
  assert test_helpers.state(format($q$ select public.partner_dashboard(%L) $q$, pid)) = '42501', 'the dashboard stays locked until approval';
end $$;

:admin
select public.admin_review_partner(current_setting('test.tolu_partner')::uuid, 'needs_info', 'Your CAC photo is blurry');
:tolu
do $$
declare pid uuid := current_setting('test.tolu_partner')::uuid;
begin
  assert (public.partner_application() ->> 'decision_note') = 'Your CAC photo is blurry', 'the note is shown to the partner';
  assert exists (select 1 from public.notifications where user_id = 'a0000000-0000-0000-0000-000000000001' and title = 'One more thing for your application'), 'they are notified';
  perform public.partner_add_document(pid, 'cac', 'a0000000-0000-0000-0000-000000000001/cac-clear.jpg');
  assert (select storage_path from public.partner_documents where partner_account_id = pid and kind = 'cac') like '%cac-clear%', 'the new certificate replaced the blurry one';
  perform public.submit_partner_for_review(pid);
end $$;
:admin
select public.admin_review_partner(current_setting('test.tolu_partner')::uuid, 'approve', null);
:tolu
do $$ begin
  assert (public.partner_application() ->> 'status') = 'approved', 'approved';
  assert exists (select 1 from public.notifications where user_id = 'a0000000-0000-0000-0000-000000000001' and title = 'You are verified'), 'they are told they are verified';
end $$;

-- Bola's earlier application (two documents) is still short of three steps.
:bola
do $$
declare app jsonb := public.partner_application();
begin
  assert app ->> 'status' = 'submitted' and (app ->> 'steps_done')::int = 2, 'Bola has the business details and the owner ID';
  assert not (app ->> 'can_submit')::boolean, 'a submitted application cannot be submitted again';
end $$;

-- A vet needs a licence step too.
:kemi
do $$
declare pid uuid;
begin
  pid := public.partner_start('vet', 'Kemi Vets', 'Yaba');
  assert (public.partner_application() ->> 'steps_total')::int = 5, 'five steps for a vet';
  assert exists (select 1 from jsonb_array_elements(public.partner_application() -> 'steps') s where s ->> 'key' = 'licence'), 'the licence step is there';
  perform public.partner_add_document(pid, 'licence', 'a0000000-0000-0000-0000-000000000005/lic.pdf');
  delete from public.partner_accounts where id = pid;
end $$;

-- ---------------------------------------------------------------------------
-- Listings
-- ---------------------------------------------------------------------------
:tolu
do $$
declare
  pid uuid := current_setting('test.tolu_partner')::uuid;
  ids uuid[];
begin
  assert test_helpers.state(format($q$ select public.partner_create_listings(%L, '{"name":"Zeus","price_kobo":"50"}') $q$, pid)) = '22023', 'a puppy needs a real price';
  assert test_helpers.state(format($q$ select public.partner_create_listings(%L, '{"name":"","price_kobo":"30000000"}') $q$, pid)) = '22023', 'a name is required';
  assert test_helpers.state(format($q$ select public.partner_create_listings(%L, '{"name":"Zeus","price_kobo":"30000000","count":"40"}') $q$, pid)) = '22023', 'a litter is at most 12';
  assert test_helpers.state(format($q$ select public.partner_create_listings(%L, '{"name":"Zeus","price_kobo":"30000000","mother_pet_id":"c0000000-0000-0000-0000-000000000005"}') $q$, pid)) = '22023', 'parents must be your own pets';
  assert test_helpers.state(format($q$ select public.partner_create_listings(%L, '{"name":"Zeus","price_kobo":"30000000","photo_path":"a0000000-0000-0000-0000-000000000005/p.jpg"}') $q$, pid)) = '22023', 'photos must be in your own folder';

  ids := public.partner_create_listings(pid, '{"name":"Zeus","breed":"Boerboel","sex":"male","price_kobo":"30000000","mother_pet_id":"c0000000-0000-0000-0000-000000000002"}');
  assert cardinality(ids) = 1, 'one puppy, one listing';
  assert (select status || kind from public.listings where id = ids[1]) = 'livesale', 'it is live and for sale';
  assert (select count(*) from public.pets where origin_partner_id = pid and name = 'Zeus' and owner_user_id = 'a0000000-0000-0000-0000-000000000001' and tag_code is not null) = 1, 'the puppy has its own passport';

  ids := public.partner_create_listings(pid, '{"name":"Hera","breed":"Boerboel","price_kobo":"25000000","count":"3"}');
  assert cardinality(ids) = 3, 'a litter makes one listing each';
  assert (select count(*) from public.pets where name in ('Hera 1', 'Hera 2', 'Hera 3')) = 3, 'litter members are numbered';
  perform set_config('test.hera', ids[1]::text, true);
end $$;

:kemi
do $$ begin
  assert (select count(*) from public.adopt_listings('sale', null, 'Hera')) = 3, 'buyers see the new litter';
  assert test_helpers.state(format($q$ select public.partner_set_listing_status(%L, 'removed') $q$, current_setting('test.hera'))) = '42501', 'only the seller can take a listing down';
end $$;
:tolu
do $$ begin
  perform public.partner_set_listing_status(current_setting('test.hera')::uuid, 'removed');
  assert (select status from public.listings where id = current_setting('test.hera')::uuid) = 'removed', 'taken down';
  perform public.partner_set_listing_status(current_setting('test.hera')::uuid, 'live');
  assert test_helpers.state($q$ select public.partner_set_listing_status(current_setting('test.hera')::uuid, 'sold') $q$) = '22023', 'sold is set by the handover, not by hand';
end $$;

-- Only approved breeders and shelters can list.
:amina
do $$ begin
  assert test_helpers.state($q$ select public.partner_create_listings('b0000000-0000-0000-0000-000000000001', '{"name":"X","price_kobo":"30000000"}') $q$) = '42501', 'a vet cannot list pets';
end $$;
:bola
do $$ begin
  assert test_helpers.state($q$ select public.partner_create_listings('b0000000-0000-0000-0000-000000000004', '{"name":"X","price_kobo":"30000000"}') $q$) = '42501', 'an unapproved partner cannot list';
end $$;

-- Shelter listings are free.
:ngozi
do $$
declare ids uuid[];
begin
  ids := public.partner_create_listings('b0000000-0000-0000-0000-000000000003', '{"name":"Kofi","species":"dog","price_kobo":"99999999"}');
  assert (select kind || coalesce(price_kobo::text, 'free') from public.listings where id = ids[1]) = 'adoptionfree', 'a shelter listing is an adoption with no price';
end $$;

-- ---------------------------------------------------------------------------
-- Dashboards
-- ---------------------------------------------------------------------------
:server
insert into public.escrow_transactions (id, payer_user_id, payee_partner_id, kind, amount_kobo, fee_kobo, status, paystack_reference) values
  ('e6000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', 'booking', 2500000, 300000, 'held', 'ref-pm-1'),
  ('e6000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', 'booking', 1000000, 120000, 'held', 'ref-pm-2');
update public.escrow_transactions set status = 'ready' where id = 'e6000000-0000-0000-0000-000000000002';
insert into public.bookings (id, owner_user_id, pet_id, partner_account_id, service_id, starts_at, status, escrow_transaction_id)
select 'd6000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005',
       'b0000000-0000-0000-0000-000000000001', s.id, now(), 'confirmed', 'e6000000-0000-0000-0000-000000000001'
  from public.services s where s.partner_account_id = 'b0000000-0000-0000-0000-000000000001' and s.name = 'Full check-up';

:amina
do $$
declare d jsonb := public.partner_dashboard();
begin
  assert d #>> '{partner,type}' = 'vet' and d #>> '{partner,id}' = 'b0000000-0000-0000-0000-000000000001', 'the oldest approved partner is the default';
  assert (d #>> '{stats,visits_today}')::int = 1, 'one visit today';
  assert d #>> '{schedule,0,service}' = 'Full check-up' and d #>> '{schedule,0,pet_name}' = 'Luna', 'the schedule names the service and the pet';
  assert d #>> '{schedule,0,owner_name}' = 'Kemi', 'and the owner';
  assert (d #>> '{stats,week_kobo}')::bigint = 2200000, 'the week counts bookings after the fee';
  assert (d #>> '{stats,next_payout_kobo}')::bigint = 880000, 'only ready money is in the next payout';

  d := public.partner_dashboard('b0000000-0000-0000-0000-0000000000a1');
  assert d #>> '{partner,name}' = 'Lekki Animal Hospital', 'a specific partner can be asked for';
  assert (d #>> '{stats,visits_today}')::int = 0, 'and has its own numbers';
end $$;
:kemi
do $$ begin
  assert test_helpers.state($q$ select public.partner_dashboard('b0000000-0000-0000-0000-000000000001') $q$) = '42501', 'owners cannot open a partner dashboard';
end $$;

:chidi
do $$
declare d jsonb := public.partner_dashboard();
begin
  assert d #>> '{partner,type}' = 'breeder', 'the breeder dashboard';
  assert (d #>> '{stats,live_listings}')::int = 1, 'Duke is the one live listing';
  assert d #>> '{listings,0,pet_name}' = 'Duke', 'it lists Duke';
  assert d ->> 'applications' = '[]', 'no applications for a breeder';
end $$;

-- An enquiry shows up for the breeder, and clears when read.
:kemi
select public.open_listing_chat((select id from public.listings where pet_id = 'c0000000-0000-0000-0000-000000000003'));
select public.send_message((select id from public.conversations where context_type = 'listing' limit 1), 'Can I visit on Saturday?', null, null);
:chidi
do $$
declare d jsonb := public.partner_dashboard();
begin
  assert (d #>> '{stats,new_enquiries}')::int = 1, 'one new enquiry';
  assert d #>> '{enquiries,0,last_body}' = 'Can I visit on Saturday?' and d #>> '{enquiries,0,other_name}' = 'Kemi', 'the enquiry shows who and what';
  perform public.mark_conversation_read((d #>> '{enquiries,0,conversation_id}')::uuid);
  assert (public.partner_dashboard() #>> '{stats,new_enquiries}')::int = 0, 'reading it clears the count';
end $$;

-- Adoption: Kemi applies for Biscuit, the shelter decides.
:kemi
select public.apply_to_adopt((select id from public.listings where pet_id = 'c0000000-0000-0000-0000-000000000004'),
  '{"home_type":"house","other_pets":"one cat","daytime":"home 3 days","why":"We have room and time for a rescue dog.","agree_visit":true}');
:ngozi
do $$
declare
  d jsonb := public.partner_dashboard();
  app uuid;
begin
  assert d #>> '{partner,type}' = 'shelter', 'the shelter dashboard';
  assert (d #>> '{stats,new_applications}')::int = 1, 'one new application';
  assert (d #>> '{stats,pets_listed}')::int = 2, 'Biscuit and Kofi are listed';
  assert d #>> '{applications,0,applicant_name}' = 'Kemi' and d #>> '{applications,0,pet_name}' = 'Biscuit', 'the application shows who and for which pet';
  assert d #>> '{applications,0,home_type}' = 'house', 'and what they said';
  assert (d #>> '{applications,0,pets_total}')::int = 1, 'and how many pets they have';
  app := (d #>> '{applications,0,application_id}')::uuid;
  perform set_config('test.app', app::text, true);

  assert test_helpers.state($q$ select public.decide_application(current_setting('test.app')::uuid, 'maybe') $q$) = '22023', 'unknown decisions are refused';
  perform public.decide_application(app, 'home_visit');
  assert (select status from public.adoption_applications where id = app) = 'home_visit', 'a home visit is arranged';
  assert public.open_application_chat(app) = public.open_application_chat(app), 'the chat is reused';
  perform public.decide_application(app, 'approve');
  assert (select status from public.adoption_applications where id = app) = 'approved', 'approved';
  assert test_helpers.state($q$ select public.decide_application(current_setting('test.app')::uuid, 'decline') $q$) = 'P0001', 'a decided application is final';
end $$;
:kemi
do $$ begin
  assert exists (select 1 from public.notifications where user_id = 'a0000000-0000-0000-0000-000000000005' and title like 'Your application for Biscuit was approved'), 'the applicant is told';
  assert test_helpers.state($q$ select public.decide_application(current_setting('test.app')::uuid, 'decline') $q$) = '42501', 'applicants cannot decide their own applications';
  assert test_helpers.state($q$ select public.open_application_chat(current_setting('test.app')::uuid) $q$) = '42501', 'nor open the shelter side of the chat';
end $$;

-- ---------------------------------------------------------------------------
-- Earnings
-- ---------------------------------------------------------------------------
:server
insert into public.payout_runs (id, run_on, status, total_kobo) values ('f6000000-0000-0000-0000-000000000001', current_date - 7, 'sent', 9640000);
insert into public.payout_items (payout_run_id, partner_account_id, amount_kobo, status) values
  ('f6000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 9640000, 'sent');

:amina
do $$
declare e jsonb := public.partner_earnings();
begin
  assert (e ->> 'held_kobo')::bigint = 2200000, 'held money is after the fee';
  assert (e ->> 'next_payout_kobo')::bigint = 880000, 'ready money goes out on Monday';
  assert (e ->> 'paid_month_kobo')::bigint >= 0, 'paid this month is counted';
  assert (e ->> 'next_payout_on')::date > (now() at time zone 'Africa/Lagos')::date and extract(isodow from (e ->> 'next_payout_on')::date) = 1, 'the next payout is a Monday after today';
  assert e ->> 'account_last4' is null, 'no bank account on file for the seed vet';
  assert jsonb_array_length(e -> 'recent') >= 3, 'recent shows both payments and the payout';
  assert exists (select 1 from jsonb_array_elements(e -> 'recent') r where r ->> 'title' = 'Full check-up · Luna' and r ->> 'state' = 'held'), 'a held booking is labelled with its service and pet';
  assert exists (select 1 from jsonb_array_elements(e -> 'recent') r where r ->> 'source' = 'payout' and r ->> 'title' = 'Weekly payout'), 'payouts appear too';
end $$;
:kemi
do $$ begin
  assert test_helpers.state($q$ select public.partner_earnings('b0000000-0000-0000-0000-000000000001') $q$) = '42501', 'owners cannot see earnings';
end $$;
:tolu
do $$ begin
  assert public.partner_earnings() ->> 'account_last4' = '6789', 'a partner sees only the last four digits of their account';
end $$;

-- ---------------------------------------------------------------------------
-- Help and support
-- ---------------------------------------------------------------------------
:kemi
do $$
declare t uuid;
begin
  assert test_helpers.state($q$ select public.create_support_ticket('gossip', 'Where is my tag order?') $q$) = '22023', 'the topic must be one we know';
  assert test_helpers.state($q$ select public.create_support_ticket('payments', 'hi') $q$) = '22023', 'a message needs some detail';
  t := public.create_support_ticket('payments', 'My refund has not arrived yet, it has been three days.');
  assert (select count(*) from public.my_support_tickets()) = 1, 'the ticket is listed';
  assert (select status from public.my_support_tickets()) = 'open', 'and open';
  assert (select number from public.my_support_tickets()) > 0, 'with a number to quote';
  assert (select count(*) from public.support_messages where ticket_id = t and author_user_id = 'a0000000-0000-0000-0000-000000000005') = 1, 'the first message is stored';

  perform public.create_support_ticket('other', 'Second request, long enough.');
  perform public.create_support_ticket('other', 'Third request, long enough.');
  perform public.create_support_ticket('other', 'Fourth request, long enough.');
  perform public.create_support_ticket('other', 'Fifth request, long enough.');
  assert test_helpers.state($q$ select public.create_support_ticket('other', 'Sixth request, long enough.') $q$) = 'P0001', 'a flood of requests is slowed down';
end $$;
:tolu
do $$ begin
  assert (select count(*) from public.my_support_tickets()) = 0, 'tickets are private';
end $$;
:anon
do $$ begin
  assert test_helpers.state($q$ select public.partner_application() $q$) = '42501', 'signed out users are refused';
  assert test_helpers.state($q$ select public.create_support_ticket('other', 'hello there friend') $q$) = '42501', 'signed out users cannot write to support';
end $$;

reset role;
rollback;
\echo Partner tests passed
