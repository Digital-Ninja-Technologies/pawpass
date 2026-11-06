-- Admin console functions and views: role checks, state changes, audit trail.
--
-- Run after migrations and seed.sql:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/admin.test.sql
-- Runs in one transaction that is rolled back.

\set QUIET on
\set tolu    'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); perform set_config(''request.jwt.claim.email'', ''tolu@example.com'', true); end $$; set local role authenticated;'
\set kemi    'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); perform set_config(''request.jwt.claim.email'', ''kemi@example.com'', true); end $$; set local role authenticated;'
\set admin   'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000007'', true); perform set_config(''request.jwt.claim.email'', ''admin@pawpass.example'', true); end $$; set local role authenticated;'
\set finance 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f1'', true); perform set_config(''request.jwt.claim.email'', ''finance@pawpass.example'', true); end $$; set local role authenticated;'
\set support 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f2'', true); perform set_config(''request.jwt.claim.email'', ''support@pawpass.example'', true); end $$; set local role authenticated;'
\set kyc     'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f3'', true); perform set_config(''request.jwt.claim.email'', ''kyc@pawpass.example'', true); end $$; set local role authenticated;'
\set viewer  'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f4'', true); perform set_config(''request.jwt.claim.email'', ''viewer@pawpass.example'', true); end $$; set local role authenticated;'
\set newhire 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f5'', true); perform set_config(''request.jwt.claim.email'', ''new.hire@pawpass.example'', true); end $$; set local role authenticated;'
\set wrong   'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-0000000000f6'', true); perform set_config(''request.jwt.claim.email'', ''someone.else@example.com'', true); end $$; set local role authenticated;'
\set anon    'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
\set server  'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); perform set_config(''request.jwt.claim.email'', '''', true); end $$;'

begin;

create schema test_helpers;
grant usage on schema test_helpers to anon, authenticated;

-- SQLSTATE of a failing statement, or null if it succeeded.
create function test_helpers.state(q text) returns text
language plpgsql as $$
begin
  execute q;
  return null;
exception when others then
  return sqlstate;
end;
$$;
grant execute on all functions in schema test_helpers to anon, authenticated;

-- Staff of every role, plus two users for the invite flow.
:server
insert into auth.users (id, email, aud, role, email_confirmed_at, raw_user_meta_data) values
  ('a0000000-0000-0000-0000-0000000000f1', 'finance@pawpass.example', 'authenticated', 'authenticated', now(), '{"first_name":"Tunde","last_name":"K"}'),
  ('a0000000-0000-0000-0000-0000000000f2', 'support@pawpass.example', 'authenticated', 'authenticated', now(), '{"first_name":"Halima","last_name":"S"}'),
  ('a0000000-0000-0000-0000-0000000000f3', 'kyc@pawpass.example',     'authenticated', 'authenticated', now(), '{"first_name":"Bisi","last_name":"A"}'),
  ('a0000000-0000-0000-0000-0000000000f4', 'viewer@pawpass.example',  'authenticated', 'authenticated', now(), '{"first_name":"Read","last_name":"Only"}'),
  ('a0000000-0000-0000-0000-0000000000f5', 'new.hire@pawpass.example','authenticated', 'authenticated', now(), '{"first_name":"New","last_name":"Hire"}'),
  ('a0000000-0000-0000-0000-0000000000f6', 'someone.else@example.com','authenticated', 'authenticated', now(), '{}');
insert into public.staff_members (user_id, role) values
  ('a0000000-0000-0000-0000-0000000000f1', 'payouts_disputes'),
  ('a0000000-0000-0000-0000-0000000000f2', 'support_reports'),
  ('a0000000-0000-0000-0000-0000000000f3', 'verifications'),
  ('a0000000-0000-0000-0000-0000000000f4', 'read_only');

-- ---------------------------------------------------------------------------
-- Who am I
-- ---------------------------------------------------------------------------
:kyc
do $$ begin
  assert (select role from public.admin_me_v) = 'verifications', 'staff can read their own role';
end $$;
:tolu
do $$ begin
  assert test_helpers.state($q$ select * from public.partner_reviews $q$) is null and (select count(*) from public.partner_reviews) = 0, 'owners cannot read reviewer notes';
  assert (select count(*) from public.admin_me_v) = 0, 'owners are not staff';
  assert (select count(*) from public.admin_directory_v) = 0, 'owners cannot read the admin directory';
  assert test_helpers.state($q$ select public.admin_review_partner('b0000000-0000-0000-0000-000000000004', 'approve') $q$) = '42501',
    'owners cannot call admin functions';
end $$;
:anon
do $$ begin
  assert test_helpers.state($q$ select public.admin_review_partner('b0000000-0000-0000-0000-000000000004', 'approve') $q$) = '42501',
    'anonymous cannot call admin functions';
end $$;

-- ---------------------------------------------------------------------------
-- Verifications
-- ---------------------------------------------------------------------------
:support
do $$ begin
  assert test_helpers.state($q$ select public.admin_review_partner('b0000000-0000-0000-0000-000000000004', 'approve') $q$) = '42501',
    'support staff cannot approve partners';
end $$;
:viewer
do $$ begin
  assert test_helpers.state($q$ select public.admin_review_partner('b0000000-0000-0000-0000-000000000004', 'approve') $q$) = '42501',
    'read only staff cannot approve partners';
  assert (select count(*) from public.admin_kyc_v) >= 1, 'read only staff can read the queue';
end $$;
:kyc
do $$ begin
  assert (select count(*) from public.admin_kyc_v where status = 'submitted') = 1, 'one application is waiting';
  assert test_helpers.state($q$ select public.admin_review_partner('b0000000-0000-0000-0000-000000000004', 'needs_info') $q$) = '22023',
    'asking for more info needs a note';
  perform public.admin_save_kyc_review('b0000000-0000-0000-0000-000000000004', '{"name_matches": true}', 'ID looks fine');
  assert (select internal_note from public.admin_kyc_v where id = 'b0000000-0000-0000-0000-000000000004') = 'ID looks fine', 'internal note saved';

  perform public.admin_review_partner('b0000000-0000-0000-0000-000000000004', 'needs_info', 'Please upload a clearer CAC certificate');
  assert (select status from public.admin_kyc_v where id = 'b0000000-0000-0000-0000-000000000004') = 'needs_info', 'status is needs_info';
  perform public.admin_review_partner('b0000000-0000-0000-0000-000000000004', 'approve');
  assert (select status from public.admin_kyc_v where id = 'b0000000-0000-0000-0000-000000000004') = 'approved', 'approved';
  assert test_helpers.state($q$ select public.admin_review_partner('b0000000-0000-0000-0000-000000000004', 'reject', 'x') $q$) = 'P0002',
    'an approved application cannot be decided again';
end $$;
:server
do $$ begin
  assert (select verified_at from public.partner_accounts where id = 'b0000000-0000-0000-0000-000000000004') is not null, 'verified_at is set';
  assert (select count(*) from public.partner_reviews) = 1, 'review notes are stored separately';
  assert (select count(*) from public.partner_documents where partner_account_id = 'b0000000-0000-0000-0000-000000000004' and status = 'approved') = 2, 'documents approved';
  assert (select count(*) from public.audit_log where action in ('partner.approve', 'partner.needs_info', 'partner.review_notes')) = 3, 'each action is audited';
  assert (select count(*) from public.audit_log where staff_id is null) = 0, 'audit rows carry the staff member';
end $$;

do $$ begin null; end $$;
:server
do $$ begin perform set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000006', true); end $$;
set local role authenticated;
do $$ begin
  assert (select count(*) from public.partner_reviews) = 0, 'a partner cannot read the reviewer notes about them';
  assert (select count(*) from public.admin_kyc_v) = 0, 'a partner cannot use the admin view';
end $$;
:server

-- ---------------------------------------------------------------------------
-- Disputes
-- ---------------------------------------------------------------------------
insert into public.escrow_transactions (id, payer_user_id, payee_partner_id, kind, amount_kobo, fee_kobo, status) values
  ('e0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'puppy_balance', 38000000, 1900000, 'paused'),
  ('e0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking', 1500000, 180000, 'ready'),
  ('e0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', 'booking', 800000, 96000, 'ready'),
  ('e0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000003', 'booking', 500000, 60000, 'held');
insert into public.disputes (id, escrow_transaction_id, opened_by_user_id, reason, details, status, due_at) values
  ('d1000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Puppy ill after handover', 'Parvo positive', 'open', now() + interval '1 day');

:support
do $$ begin
  assert (select count(*) from public.admin_dispute_v) = 0, 'support staff cannot read disputes';
  assert (select count(*) from public.admin_escrow_v) = 0, 'support staff cannot read escrow';
  assert test_helpers.state($q$ select public.admin_decide_dispute('d1000000-0000-0000-0000-000000000001', 'refund') $q$) = '42501',
    'support staff cannot decide disputes';
end $$;
:finance
do $$ begin
  assert (select count(*) from public.admin_dispute_v where status = 'open') = 1, 'finance staff read disputes';
  assert (select count(*) from public.admin_escrow_v) = 4, 'finance staff read escrow';
  assert (select ref from public.admin_escrow_v where id = 'e0000000-0000-0000-0000-000000000001') like 'T-%', 'escrow has a readable reference';
  assert test_helpers.state($q$ select public.admin_decide_dispute('d1000000-0000-0000-0000-000000000001', 'split', 38000000) $q$) = '22023',
    'a split cannot refund the full amount';
  assert test_helpers.state($q$ select public.admin_decide_dispute('d1000000-0000-0000-0000-000000000001', 'split') $q$) = '22023',
    'a split needs an amount';
  perform public.admin_decide_dispute('d1000000-0000-0000-0000-000000000001', 'split', 19000000, 'Half each');
  assert (select status from public.admin_escrow_v where id = 'e0000000-0000-0000-0000-000000000001') = 'partially_refunded', 'escrow partially refunded';
  assert test_helpers.state($q$ select public.admin_decide_dispute('d1000000-0000-0000-0000-000000000001', 'refund') $q$) = 'P0001',
    'a decided dispute cannot be decided again';
  assert (select decision_refund_kobo from public.admin_dispute_v) = 19000000, 'refund amount recorded';
end $$;

-- ---------------------------------------------------------------------------
-- Payout run: only "ready" money, net of fees, grouped by partner
-- ---------------------------------------------------------------------------
:finance
do $$ declare r uuid; begin
  r := public.admin_prepare_payout_run(date '2026-11-09');
  assert (select count(*) from public.payout_items where payout_run_id = r) = 2,
    'the clinic with ready money, and the kennel owed its half of the split puppy payment';
  assert (select amount_kobo from public.payout_items where payout_run_id = r and partner_account_id = 'b0000000-0000-0000-0000-000000000001')
    = (1500000 - 180000) + (800000 - 96000), 'net of fees, summed';
  -- The split refunded 19,000,000 of 38,000,000: the kennel gets the other half, less half of the 1,900,000 fee.
  assert (select amount_kobo from public.payout_items where payout_run_id = r and partner_account_id = 'b0000000-0000-0000-0000-000000000002')
    = 19000000 - 950000, 'a split pays the provider the rest, with a proportional fee';
  assert (select total_kobo from public.payout_runs where id = r) = 2024000 + 18050000, 'run total matches';
  -- preparing again replaces the draft instead of duplicating it
  assert public.admin_prepare_payout_run(date '2026-11-09') = r, 'same run id';
  assert (select count(*) from public.payout_items where payout_run_id = r) = 2, 'no duplicate items';
  perform public.admin_approve_payout_run(r);
  assert (select status from public.payout_runs where id = r) = 'approved', 'run approved';
  assert test_helpers.state($q$ select public.admin_prepare_payout_run(date '2026-11-09') $q$) = 'P0001', 'an approved run is frozen';
  assert test_helpers.state(format($q$ select public.admin_approve_payout_run(%L) $q$, r)) = 'P0001', 'cannot approve twice';
end $$;
:support
do $$ begin
  assert test_helpers.state($q$ select public.admin_prepare_payout_run(date '2026-11-16') $q$) = '42501', 'support cannot prepare payouts';
end $$;

-- ---------------------------------------------------------------------------
-- Reports, moderation and suspension
-- ---------------------------------------------------------------------------
:server
insert into public.reports (reporter_user_id, target_type, target_id, reason)
select 'a0000000-0000-0000-0000-000000000001', 'post', p.id, 'Unsafe advice' from public.posts p where p.author_user_id = 'a0000000-0000-0000-0000-000000000005';
insert into public.reports (reporter_user_id, target_type, target_id, reason)
select 'a0000000-0000-0000-0000-000000000003', 'post', p.id, 'Unsafe advice' from public.posts p where p.author_user_id = 'a0000000-0000-0000-0000-000000000005';

:support
do $$ declare post uuid; begin
  select target_id into post from public.admin_report_v where target_type = 'post';
  assert (select report_count from public.admin_report_v where target_id = post) = 2, 'reports are grouped per item';
  assert (select summary from public.admin_report_v where target_id = post) like 'Luna%', 'content summary shown';
  assert test_helpers.state(format($q$ select public.admin_resolve_report('post', %L, 'delete_everything') $q$, post)) = '22023', 'unknown action rejected';
  perform public.admin_resolve_report('post', post, 'remove_and_suspend', 'Unsafe advice');
  assert (select is_open from public.admin_report_v where target_id = post) = false, 'reports closed';
end $$;
:server
do $$ begin
  assert (select status from public.posts where author_user_id = 'a0000000-0000-0000-0000-000000000005') = 'removed', 'post removed';
  assert (select suspended_at from public.profiles where user_id = 'a0000000-0000-0000-0000-000000000005') is not null, 'author flagged suspended';
  assert (select banned_until from auth.users where id = 'a0000000-0000-0000-0000-000000000005') = 'infinity', 'sign in is blocked';
  assert (select count(*) from public.audit_log where action = 'report.remove_and_suspend') = 1, 'audited';
end $$;
:support
do $$ begin
  assert test_helpers.state($q$ select public.admin_set_user_suspended('a0000000-0000-0000-0000-000000000007', true, 'test') $q$) = '42501', 'staff cannot be suspended';
  assert test_helpers.state($q$ select public.admin_set_user_suspended('a0000000-0000-0000-0000-000000000001', true) $q$) = '22023', 'suspending needs a reason';
  perform public.admin_set_user_suspended('a0000000-0000-0000-0000-000000000005', false);
end $$;
:server
do $$ begin
  assert (select banned_until from auth.users where id = 'a0000000-0000-0000-0000-000000000005') is null, 'unsuspend clears the ban';
  assert (select suspended_at from public.profiles where user_id = 'a0000000-0000-0000-0000-000000000005') is null, 'flag cleared';
end $$;
:tolu
do $$ begin
  assert test_helpers.state($q$ update public.profiles set suspended_at = null $q$) = '42501', 'users cannot edit their own suspension state';
  assert test_helpers.state($q$ update public.profiles set first_name = 'Tolu' $q$) is null, 'users can still edit their name';
end $$;

-- Suspending a partner takes their listings down.
:support
do $$ begin
  perform public.admin_set_user_suspended('a0000000-0000-0000-0000-000000000003', true, 'Investigating a complaint');
end $$;
:server
do $$ begin
  assert (select status from public.partner_accounts where id = 'b0000000-0000-0000-0000-000000000002') = 'suspended', 'partner suspended';
  assert (select count(*) from public.listings where partner_account_id = 'b0000000-0000-0000-0000-000000000002' and status = 'live') = 0, 'listings taken down';
end $$;

-- ---------------------------------------------------------------------------
-- Lost and found, QR tags
-- ---------------------------------------------------------------------------
:tolu
insert into public.lost_alerts (pet_id, last_seen_point) values ('c0000000-0000-0000-0000-000000000001', extensions.st_point(3.4, 6.45, 4326)::extensions.geography);
do $$ begin
  assert test_helpers.state($q$ insert into public.qr_tag_orders (user_id, pet_id) values ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001') $q$) = '42501',
    'owners cannot create tag orders from the client (paid server side)';
end $$;
:server
insert into public.qr_tag_orders (user_id, pet_id, status) values ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'paid');
:support
do $$ declare a uuid; o uuid; begin
  select id into a from public.admin_lost_v where pet_name = 'Bingo';
  assert (select radius_m from public.admin_lost_v where id = a) = 5000, 'default radius from settings';
  assert test_helpers.state(format($q$ select public.admin_widen_lost_alert(%L, 100) $q$, a)) is null, 'widen works';
  assert test_helpers.state(format($q$ select public.admin_widen_lost_alert(%L, 99000) $q$, a)) = '22023', 'radius is capped at 50 km';
  select id into o from public.admin_qr_v limit 1;
  assert test_helpers.state(format($q$ select public.admin_set_qr_order_status(%L, 'delivered') $q$, o)) = 'P0001', 'cannot skip shipping';
  perform public.admin_set_qr_order_status(o, 'shipped');
  perform public.admin_set_qr_order_status(o, 'delivered');
end $$;

-- ---------------------------------------------------------------------------
-- Support inbox
-- ---------------------------------------------------------------------------
:tolu
insert into public.support_tickets (user_id, topic, subject) values ('a0000000-0000-0000-0000-000000000001', 'Payments & refunds', 'When will my refund arrive?');
:support
do $$ declare t uuid; begin
  select id into t from public.admin_support_v limit 1;
  perform public.admin_reply_ticket(t, 'Your refund is on its way', false);
  perform public.admin_reply_ticket(t, 'Internal: check with finance', true);
  assert test_helpers.state(format($q$ select public.admin_reply_ticket(%L, '   ') $q$, t)) = '22023', 'empty replies rejected';
  assert (select status from public.admin_support_v where id = t) = 'waiting_user', 'a reply moves the ticket to waiting on user';
end $$;
:tolu
do $$ begin
  assert (select count(*) from public.support_messages) = 1, 'the user sees the reply but not the internal note';
end $$;

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
:support
do $$ begin
  assert test_helpers.state($q$ select public.admin_update_settings('{"booking_commission_bps": 1000}') $q$) = '42501', 'only full admins change settings';
end $$;
:admin
do $$ begin
  perform public.admin_update_settings('{"booking_commission_bps": 1000, "free_cancel_hours": 4}');
  assert (select booking_commission_bps from public.settings) = 1000, 'commission updated';
  assert (select puppy_escrow_fee_bps from public.settings) = 500, 'untouched settings keep their value';
  assert test_helpers.state($q$ select public.admin_update_settings('{"booking_commission_bps": 20000}') $q$) = '23514', 'out of range rejected by the database';
  assert (select details -> 'before' ->> 'booking_commission_bps' from public.admin_audit_v where action = 'settings.update' limit 1) = '1200', 'audit keeps the old value';
end $$;

-- ---------------------------------------------------------------------------
-- Team and invites
-- ---------------------------------------------------------------------------
:support
do $$ begin
  assert (select count(*) from public.admin_audit_v) = 0, 'only full admins read the audit log';
  assert test_helpers.state($q$ select public.admin_create_staff_invite('x@pawpass.example', 'read_only', null, 'h', now() + interval '2 day') $q$) = '42501', 'only full admins invite';
end $$;
:admin
do $$ declare inv uuid; begin
  assert test_helpers.state($q$ select public.admin_create_staff_invite('not-an-email', 'read_only', null, 'h0', now() + interval '2 day') $q$) = '22023', 'email is validated';
  inv := public.admin_create_staff_invite('New.Hire@pawpass.example', 'support_reports', 'Welcome!', encode(extensions.digest('secret-token', 'sha256'), 'hex'), now() + interval '48 hours');
  assert (select email from public.staff_invites where id = inv) = 'new.hire@pawpass.example', 'email is normalised';
  assert test_helpers.state($q$ select public.admin_create_staff_invite('new.hire@pawpass.example', 'read_only', null, 'h2', now() + interval '2 day') $q$) = 'P0001', 'no duplicate live invites';
  assert test_helpers.state($q$ select public.admin_set_staff_role((select id from public.staff_members where user_id = 'a0000000-0000-0000-0000-000000000007'), 'read_only') $q$) = 'P0001', 'cannot change your own role';
end $$;
:anon
do $$ begin
  assert (select count(*) from public.staff_invite_preview('secret-token')) = 1, 'the invite page can preview a valid token';
  assert (select role from public.staff_invite_preview('secret-token')) = 'support_reports', 'preview shows the role';
  assert (select count(*) from public.staff_invite_preview('guess')) = 0, 'a wrong token shows nothing';
  assert test_helpers.state($q$ select public.accept_staff_invite('secret-token') $q$) = '42501', 'accepting needs a sign in';
end $$;
:wrong
do $$ begin
  assert test_helpers.state($q$ select public.accept_staff_invite('secret-token') $q$) = '42501', 'the invite is tied to its email address';
end $$;
:newhire
do $$ begin
  assert test_helpers.state($q$ select public.accept_staff_invite('wrong-token') $q$) = 'P0002', 'wrong token rejected';
  assert public.accept_staff_invite('secret-token') = 'support_reports', 'invite accepted with the right email';
  assert (select role from public.admin_me_v) = 'support_reports', 'the new hire has the invited role';
  assert test_helpers.state($q$ select public.accept_staff_invite('secret-token') $q$) = 'P0002', 'an invite works once';
end $$;
:anon
do $$ begin
  assert (select count(*) from public.staff_invite_preview('secret-token')) = 0, 'used invites no longer preview';
end $$;

-- The last active full admin cannot be removed.
:server
update public.staff_members set role = 'read_only' where user_id = 'a0000000-0000-0000-0000-0000000000f4';
insert into public.staff_members (user_id, role) values ('a0000000-0000-0000-0000-0000000000f6', 'full_admin');
:admin
do $$ begin
  perform public.admin_set_staff_status((select id from public.staff_members where user_id = 'a0000000-0000-0000-0000-0000000000f6'), 'suspended');
  assert test_helpers.state($q$ select public.admin_set_staff_status((select id from public.staff_members where user_id = 'a0000000-0000-0000-0000-000000000007'), 'suspended') $q$) = 'P0001', 'cannot suspend yourself';
end $$;

-- ---------------------------------------------------------------------------
-- Overview numbers respect each role's access
-- ---------------------------------------------------------------------------
:finance
do $$ declare o jsonb; begin
  o := public.admin_overview(30);
  assert (o ->> 'held_kobo')::bigint = 500000, 'finance sees the escrow still held (the 5,000 naira row)';
  assert (o ->> 'ready_kobo')::bigint = (1500000 - 180000) + (800000 - 96000), 'ready money is net of fees';
  assert (o ->> 'ready_partners')::int = 1, 'one partner is waiting for a payout';
  assert jsonb_array_length(o -> 'weekly') = 12, 'twelve weekly buckets';
end $$;
:support
do $$ declare o jsonb; begin
  o := public.admin_overview(30);
  assert (o ->> 'held_kobo')::bigint = 0, 'support staff cannot see escrow figures';
  assert (o ->> 'reports_open') is not null, 'support staff see report counts';
  assert (o ->> 'active_pets')::int >= 1, 'staff can count pets';
end $$;
:tolu
do $$ begin
  assert (public.admin_overview(30) ->> 'held_kobo')::bigint = 0, 'owners see no escrow totals';
end $$;

-- ---------------------------------------------------------------------------
-- Waitlist (public landing page)
-- ---------------------------------------------------------------------------
:anon
do $$ begin
  insert into public.waitlist_signups (email, source) values ('hello@example.com', 'hero');
  assert test_helpers.state($q$ insert into public.waitlist_signups (email) values ('HELLO@example.com') $q$) = '23505', 'duplicates are caught (case insensitive)';
  assert test_helpers.state($q$ insert into public.waitlist_signups (email) values ('not an email') $q$) = '23514', 'bad emails rejected';
  assert test_helpers.state($q$ select * from public.waitlist_signups $q$) = '42501', 'the public cannot read the list';
  assert test_helpers.state($q$ insert into public.waitlist_signups (email, created_at) values ('x@example.com', now() - interval '1 year') $q$) = '42501', 'the public can only set email and source';
end $$;
:admin
do $$ begin
  assert (select count(*) from public.waitlist_signups) = 1, 'staff can read the waitlist';
end $$;

:server
select 'Admin tests passed' as result;
rollback;
