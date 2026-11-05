-- Removes everything created by seed.sql and demo/demo_data.sql (users with fixed a000... ids and
-- all data that belongs to them). audit_log is append only, so its guard trigger is switched off for
-- this one statement and back on again, inside the same transaction.
begin;
alter table public.audit_log disable trigger audit_log_no_change;
alter table public.audit_log disable trigger audit_log_no_truncate;
delete from public.audit_log where staff_id in (select id from public.staff_members where user_id::text like 'a0000000-0000-0000-0000-0000000000%');
alter table public.audit_log enable trigger audit_log_no_change;
alter table public.audit_log enable trigger audit_log_no_truncate;

delete from public.support_messages where ticket_id in (select id from public.support_tickets where user_id::text like 'a0000000-0000-0000-0000-0000000000%');
delete from public.support_tickets where user_id::text like 'a0000000-0000-0000-0000-0000000000%';
delete from public.reports where reporter_user_id::text like 'a0000000-0000-0000-0000-0000000000%';
delete from public.sightings where reporter_user_id::text like 'a0000000-0000-0000-0000-0000000000%';
delete from public.lost_alerts where pet_id in (select id from public.pets where owner_user_id::text like 'a0000000-0000-0000-0000-0000000000%');
delete from public.qr_tag_orders where user_id::text like 'a0000000-0000-0000-0000-0000000000%';
delete from public.disputes where opened_by_user_id::text like 'a0000000-0000-0000-0000-0000000000%';
delete from public.ownership_transfers where to_user_id::text like 'a0000000-0000-0000-0000-0000000000%';
delete from public.bookings where owner_user_id::text like 'a0000000-0000-0000-0000-0000000000%';
delete from public.escrow_transactions where payer_user_id::text like 'a0000000-0000-0000-0000-0000000000%';
delete from public.payout_items where partner_account_id in (select id from public.partner_accounts where owner_user_id::text like 'a0000000-0000-0000-0000-0000000000%');
delete from public.payout_runs where id not in (select payout_run_id from public.payout_items);
delete from public.listings where partner_account_id in (select id from public.partner_accounts where owner_user_id::text like 'a0000000-0000-0000-0000-0000000000%');
delete from public.posts where author_user_id::text like 'a0000000-0000-0000-0000-0000000000%';
delete from public.health_records where pet_id in (select id from public.pets where owner_user_id::text like 'a0000000-0000-0000-0000-0000000000%');
delete from public.pets where owner_user_id::text like 'a0000000-0000-0000-0000-0000000000%';
delete from public.staff_invites where invited_by in (select id from public.staff_members where user_id::text like 'a0000000-0000-0000-0000-0000000000%');
delete from auth.users where id::text like 'a0000000-0000-0000-0000-0000000000%';
commit;
