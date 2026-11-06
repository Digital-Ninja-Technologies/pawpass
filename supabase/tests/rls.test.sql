-- RLS and business rule tests. Plain SQL, no extensions needed.
--
-- Run against a database that has the migrations and seed.sql applied:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f supabase/tests/rls.test.sql
-- Everything runs in one transaction that is rolled back, so it leaves no data behind.
-- A failed assertion aborts with its message; success prints "RLS tests passed".

\set QUIET on
\set tolu   'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000001'', true); end $$; set local role authenticated;'
\set amina  'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000002'', true); end $$; set local role authenticated;'
\set chidi  'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000003'', true); end $$; set local role authenticated;'
\set ngozi  'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000004'', true); end $$; set local role authenticated;'
\set kemi   'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000005'', true); end $$; set local role authenticated;'
\set bola   'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000006'', true); end $$; set local role authenticated;'
\set admin  'do $$ begin perform set_config(''request.jwt.claim.sub'', ''a0000000-0000-0000-0000-000000000007'', true); end $$; set local role authenticated;'
\set anon   'do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$; set local role anon;'
\set server 'reset role; do $$ begin perform set_config(''request.jwt.claim.sub'', '''', true); end $$;'

begin;

create schema test_helpers;
grant usage on schema test_helpers to anon, authenticated;

-- True when the statement is rejected by RLS, a privilege or a guard trigger.
create function test_helpers.denied(q text) returns boolean
language plpgsql as $$
begin
  execute q;
  return false;
exception when insufficient_privilege then
  return true;
end;
$$;

-- Number of rows a write statement touched (RLS filtering shows up as 0).
create function test_helpers.affected(q text) returns integer
language plpgsql as $$
declare n integer;
begin
  execute q;
  get diagnostics n = row_count;
  return n;
end;
$$;
grant execute on all functions in schema test_helpers to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Anonymous users see nothing
-- ---------------------------------------------------------------------------
:anon
do $$ begin
  assert test_helpers.denied('select * from public.pets'), 'anon must not read pets';
  assert test_helpers.denied('select * from public.profiles'), 'anon must not read profiles';
  assert test_helpers.denied('select * from public.settings'), 'anon must not read settings';
end $$;

-- ---------------------------------------------------------------------------
-- Pets: private by default, visible when public by design
-- ---------------------------------------------------------------------------
:tolu
do $$ begin
  assert (select count(*) from public.pets where owner_user_id = 'a0000000-0000-0000-0000-000000000001') = 2, 'Tolu sees Bingo and Mimi';
  assert (select count(*) from public.pets) = 5, 'Tolu also sees pets that are public (live listings, public post)';
  assert test_helpers.denied($q$ update public.pets set owner_user_id = 'a0000000-0000-0000-0000-000000000005' where name = 'Bingo' $q$),
    'owner cannot give a pet away from the client';
  assert test_helpers.denied($q$ insert into public.pets (owner_user_id, name, species) values ('a0000000-0000-0000-0000-000000000005', 'Fake', 'dog') $q$),
    'cannot create a pet for someone else';
end $$;

:bola
do $$ begin
  assert (select count(*) from public.pets where name in ('Bingo', 'Mimi')) = 0, 'a stranger cannot see private pets';
  assert (select count(*) from public.pets where name in ('Duke', 'Biscuit', 'Luna')) = 3, 'public pets stay visible';
end $$;

-- ---------------------------------------------------------------------------
-- Health records: private, and only vets can verify
-- ---------------------------------------------------------------------------
:tolu
do $$ begin
  assert (select count(*) from public.health_records) = 4, 'Tolu sees Bingo records';
  assert (select count(*) from public.reminders) = 2, 'Tolu sees the rabies and DHPP reminders (made from her records)';
  assert test_helpers.denied($q$ insert into public.health_records (pet_id, type, name, added_by_user_id, verified_by_partner_id, verified_at)
    values ('c0000000-0000-0000-0000-000000000001', 'vaccine', 'Forged', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', now()) $q$),
    'owner cannot create a vet verified record';
  assert test_helpers.denied($q$ update public.health_records set name = 'Edited' where name = 'DHPP vaccine' $q$),
    'verified records cannot be edited';
  assert test_helpers.denied($q$ delete from public.health_records where name = 'DHPP vaccine' $q$),
    'verified records cannot be deleted';
  assert test_helpers.affected($q$ update public.health_records set value = '42 kg' where name = 'Weight' $q$) = 1,
    'owner can edit own unverified record';
end $$;

:kemi
do $$ begin
  assert (select count(*) from public.health_records) = 0, 'other owners cannot read health records';
  assert (select count(*) from public.reminders) = 0, 'other owners cannot read reminders';
end $$;

:amina
do $$ begin
  assert (select count(*) from public.health_records) = 0, 'vet sees nothing before a share';
end $$;

-- Share Bingo with Paws & Claws for health + write.
:tolu
insert into public.passport_shares (pet_id, partner_account_id, token_hash, scopes, expires_at)
values ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'hash-1', array['health', 'write'], now() + interval '1 hour');

:amina
do $$ begin
  assert (select count(*) from public.health_records) = 4, 'vet reads records through a live share';
  assert (select count(*) from public.passport_shares) = 1, 'vet sees own share';
  assert test_helpers.denied($q$ insert into public.health_records (pet_id, type, name, added_by_user_id, given_by_partner_id, verified_by_partner_id, verified_at)
    values ('c0000000-0000-0000-0000-000000000001', 'vaccine', 'Rabies', 'a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', now()) $q$),
    'cannot verify on behalf of another partner';
  insert into public.health_records (pet_id, type, name, added_by_user_id, given_by_partner_id, verified_by_partner_id, verified_at)
    values ('c0000000-0000-0000-0000-000000000001', 'treatment', 'Ear drops', 'a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', now());
end $$;

:chidi
do $$ begin
  assert (select count(*) from public.health_records) = 0, 'a partner without a share sees nothing';
  assert test_helpers.denied($q$ insert into public.health_records (pet_id, type, name, added_by_user_id, given_by_partner_id)
    values ('c0000000-0000-0000-0000-000000000001', 'vaccine', 'X', 'a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002') $q$),
    'a partner without a share cannot write';
end $$;

-- Revoke the share: access ends at once.
:tolu
update public.passport_shares set revoked_at = now() where token_hash = 'hash-1';
:amina
do $$ begin
  assert (select count(*) from public.health_records) = 0, 'revoked share gives no access';
end $$;

-- Expired share
:tolu
insert into public.passport_shares (pet_id, partner_account_id, token_hash, scopes, expires_at)
values ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'hash-2', array['health'], now() + interval '1 hour');
:server
update public.passport_shares set expires_at = now() - interval '1 minute' where token_hash = 'hash-2';
:amina
do $$ begin
  assert (select count(*) from public.health_records) = 0, 'expired share gives no access';
end $$;

-- ---------------------------------------------------------------------------
-- Profiles: phone numbers are never visible to other people
-- ---------------------------------------------------------------------------
:server
update public.profiles set phone = '+2348030000000' where user_id = 'a0000000-0000-0000-0000-000000000005';

:tolu
do $$ begin
  assert (select count(*) from public.profiles) = 1, 'users read only their own profile row';
  assert (select count(*) from public.profiles where phone is not null) = 0, 'cannot read anyone else''s phone';
  assert (select count(*) from public.public_profiles where first_name = 'Kemi') = 1, 'public profile is readable';
  assert not exists (select 1 from information_schema.columns where table_name = 'public_profiles' and column_name = 'phone'),
    'public_profiles must not expose phone';
  assert test_helpers.affected($q$ update public.profiles set first_name = 'Hacked' where user_id = 'a0000000-0000-0000-0000-000000000005' $q$) = 0,
    'cannot edit another profile';
end $$;

-- ---------------------------------------------------------------------------
-- Partners: cannot approve themselves
-- ---------------------------------------------------------------------------
:bola
do $$ begin
  assert test_helpers.denied($q$ update public.partner_accounts set status = 'approved' where id = 'b0000000-0000-0000-0000-000000000004' $q$),
    'partner cannot change own status';
  assert test_helpers.denied($q$ update public.partner_accounts set verified_at = now() where id = 'b0000000-0000-0000-0000-000000000004' $q$),
    'partner cannot set verified_at';
  assert test_helpers.denied($q$ insert into public.partner_accounts (owner_user_id, type, business_name, status)
    values ('a0000000-0000-0000-0000-000000000006', 'vet', 'Instant vet', 'approved') $q$),
    'cannot create an already approved partner';
  assert test_helpers.affected($q$ update public.partner_accounts set business_name = 'Bola''s Pet Spa' where id = 'b0000000-0000-0000-0000-000000000004' $q$) = 1,
    'partner can edit descriptive fields';
  assert test_helpers.denied($q$ select public.submit_partner_application('b0000000-0000-0000-0000-000000000004') $q$),
    'cannot resubmit an application that is already submitted';
  assert (select count(*) from public.partner_documents) = 2, 'partner sees own documents';
end $$;

:tolu
do $$ begin
  assert (select count(*) from public.partner_documents) = 0, 'owners cannot read KYC documents';
  assert (select count(*) from public.partner_accounts where status <> 'approved') = 0, 'owners only see approved partners';
end $$;

:admin
do $$ begin
  assert (select count(*) from public.partner_documents) = 2, 'full admin reads KYC documents';
  assert test_helpers.denied($q$ update public.partner_accounts set status = 'approved' where id = 'b0000000-0000-0000-0000-000000000004' $q$),
    'staff do not write through the client either';
end $$;

-- ---------------------------------------------------------------------------
-- Bookings and money: written by the server only
-- ---------------------------------------------------------------------------
:tolu
do $$ declare svc uuid; begin
  select id into svc from public.services where name = 'Vet consultation';
  assert test_helpers.denied($q$ insert into public.escrow_transactions (payer_user_id, payee_partner_id, kind, amount_kobo)
    values ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking', 100) $q$),
    'clients cannot create escrow rows';
  assert test_helpers.denied(format($q$ insert into public.bookings (owner_user_id, pet_id, partner_account_id, service_id, starts_at, status)
    values ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', %L, now() + interval '2 day', 'confirmed') $q$, svc)),
    'a booking cannot start confirmed';
  assert test_helpers.denied(format($q$ insert into public.bookings (owner_user_id, pet_id, partner_account_id, service_id, starts_at)
    values ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', %L, now() + interval '2 day') $q$, svc)),
    'cannot book with a pet you do not own';
  assert test_helpers.denied(format($q$ insert into public.bookings (owner_user_id, pet_id, partner_account_id, service_id, starts_at)
    values ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', %L, now() + interval '2 day') $q$, svc)),
    'bookings are made through create_booking, never inserted from the client';
end $$;

-- A booking made by the server (as create_booking does), to check who can see and change it.
:server
insert into public.bookings (owner_user_id, pet_id, partner_account_id, service_id, starts_at)
  select 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', s.id, now() + interval '2 day'
    from public.services s where s.name = 'Vet consultation';
:tolu
do $$ begin
  assert test_helpers.affected($q$ update public.bookings set status = 'completed' $q$) = 0, 'owner cannot complete a booking from the client';
end $$;

:amina
do $$ begin
  assert (select count(*) from public.bookings) = 1, 'partner sees bookings made with them';
end $$;
:kemi
do $$ begin
  assert (select count(*) from public.bookings) = 0, 'other users cannot see bookings';
end $$;

-- ---------------------------------------------------------------------------
-- Community: posts, blocks
-- ---------------------------------------------------------------------------
:kemi
do $$ begin
  assert (select count(*) from public.posts where body like 'Luna%') = 1, 'public post visible';
  assert (select count(*) from public.posts where body like 'Bingo%') = 0, 'nearby post hidden from another area';
  assert test_helpers.denied($q$ update public.posts set status = 'hidden' where body like 'Luna%' $q$),
    'authors cannot change moderation status';
  assert test_helpers.affected($q$ update public.posts set body = 'Luna naps' where body like 'Luna%' $q$) = 1, 'authors can edit their text';
end $$;

:server
insert into public.blocks (user_id, blocked_user_id) values ('a0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001');

:tolu
do $$ begin
  assert (select count(*) from public.public_profiles where first_name = 'Kemi') = 0, 'blocked user cannot see the blocker profile';
  assert (select count(*) from public.posts where body like 'Luna%') = 0, 'blocked user cannot see the blocker posts';
end $$;

-- ---------------------------------------------------------------------------
-- Lost and found
-- ---------------------------------------------------------------------------
:tolu
insert into public.lost_alerts (pet_id, last_seen_point, description)
values ('c0000000-0000-0000-0000-000000000001', extensions.st_point(3.4, 6.45, 4326)::extensions.geography, 'Last seen near the park');

do $$ declare a public.lost_alerts; begin
  select * into a from public.lost_alerts;
  assert a.radius_m = 5000, 'radius comes from settings';
  assert a.closes_at > now() + interval '13 days' and a.closes_at < now() + interval '15 days', 'auto close comes from settings (14 days)';
  assert test_helpers.denied($q$ update public.lost_alerts set radius_m = 50000 $q$), 'owner cannot widen the radius';
end $$;

:chidi
do $$ begin
  assert (select count(*) from public.lost_alerts) = 1, 'anyone signed in sees active lost alerts';
  insert into public.sightings (lost_alert_id, reporter_user_id, point, note)
    select id, 'a0000000-0000-0000-0000-000000000003', extensions.st_point(3.41, 6.46, 4326)::extensions.geography, 'Saw a Boerboel'
    from public.lost_alerts;
  assert test_helpers.affected($q$ update public.lost_alerts set status = 'found' $q$) = 0, 'a finder cannot close the alert';
end $$;

:kemi
do $$ begin
  assert (select count(*) from public.sightings) = 0, 'unrelated users cannot read sightings';
end $$;

:tolu
do $$ begin
  assert (select count(*) from public.sightings) = 1, 'the owner reads sightings on the alert';
end $$;

-- Expired alerts close.
:server
update public.lost_alerts set closes_at = now() - interval '1 hour';
do $$ begin
  assert private.close_expired_lost_alerts() = 1, 'expired alerts are closed';
  assert (select status from public.lost_alerts) = 'closed', 'status is closed';
end $$;

-- ---------------------------------------------------------------------------
-- Listings and adoption
-- ---------------------------------------------------------------------------
:bola
do $$ begin
  assert test_helpers.denied($q$ insert into public.listings (partner_account_id, pet_id, kind, price_kobo, status)
    values ('b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 'sale', 100, 'draft') $q$),
    'only breeders and shelters can list pets';
end $$;

:tolu
do $$ begin
  assert (select count(*) from public.listings) = 2, 'live listings are public';
  insert into public.adoption_applications (listing_id, applicant_user_id, answers)
    select id, 'a0000000-0000-0000-0000-000000000001', '{"home":"flat"}' from public.listings where kind = 'adoption';
  assert test_helpers.denied($q$ insert into public.adoption_applications (listing_id, applicant_user_id)
    select id, 'a0000000-0000-0000-0000-000000000001' from public.listings where kind = 'sale' $q$),
    'cannot apply to a sale listing';
  assert test_helpers.affected($q$ update public.adoption_applications set status = 'approved' $q$) = 0, 'applicants cannot approve themselves';
end $$;

:ngozi
do $$ begin
  assert (select count(*) from public.adoption_applications) = 1, 'the shelter sees applications to its listings';
  assert test_helpers.affected($q$ update public.adoption_applications set status = 'home_visit' $q$) = 1, 'the shelter moves the application on';
  assert test_helpers.denied($q$ update public.adoption_applications set answers = '{}' $q$), 'the shelter cannot rewrite answers';
end $$;

:kemi
do $$ begin
  assert (select count(*) from public.adoption_applications) = 0, 'other users cannot see applications';
end $$;

:chidi
do $$ begin
  assert test_helpers.affected($q$ update public.listings set status = 'removed' where kind = 'adoption' $q$) = 0,
    'a partner cannot edit another partner''s listing';
  assert test_helpers.denied($q$ update public.listings set status = 'sold' where kind = 'sale' $q$), 'sold is set by the handover server function';
end $$;

-- ---------------------------------------------------------------------------
-- Chat is server created and members only
-- ---------------------------------------------------------------------------
:tolu
do $$ begin
  assert test_helpers.denied($q$ insert into public.conversations (context_type) values ('support') $q$), 'clients cannot create conversations';
end $$;

:server
insert into public.conversations (id, context_type) values ('d0000000-0000-0000-0000-000000000001', 'lost_alert');
insert into public.conversation_members (conversation_id, user_id) values
  ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'),
  ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003');

:chidi
do $$ begin
  insert into public.messages (conversation_id, sender_user_id, body)
    values ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 'I think I saw Bingo');
  assert (select count(*) from public.messages) = 1, 'members read messages';
  assert test_helpers.denied($q$ update public.messages set body = 'edited' $q$), 'messages cannot be edited';
  assert test_helpers.denied($q$ insert into public.messages (conversation_id, sender_user_id, body)
    values ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'spoofed') $q$),
    'cannot send as someone else';
end $$;

:kemi
do $$ begin
  assert (select count(*) from public.messages) = 0, 'non members cannot read messages';
  assert test_helpers.denied($q$ insert into public.messages (conversation_id, sender_user_id, body)
    values ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000005', 'hi') $q$),
    'non members cannot send messages';
end $$;

-- ---------------------------------------------------------------------------
-- Support
-- ---------------------------------------------------------------------------
:tolu
insert into public.support_tickets (user_id, topic, subject) values ('a0000000-0000-0000-0000-000000000001', 'booking', 'Help with a booking');
:server
insert into public.support_messages (ticket_id, author_staff_id, body, internal)
  select t.id, s.id, 'Internal: check the payout', true from public.support_tickets t, public.staff_members s;
:tolu
do $$ begin
  assert (select count(*) from public.support_tickets) = 1, 'owner sees own ticket';
  assert (select count(*) from public.support_messages) = 0, 'internal notes are hidden from the ticket owner';
end $$;
:kemi
do $$ begin
  assert (select count(*) from public.support_tickets) = 0, 'others cannot see tickets';
end $$;
:admin
do $$ begin
  assert (select count(*) from public.support_messages) = 1, 'staff read internal notes';
end $$;

-- ---------------------------------------------------------------------------
-- Settings, staff, audit log
-- ---------------------------------------------------------------------------
:tolu
do $$ begin
  assert (select booking_commission_bps from public.settings) = 1200, 'signed in users can read settings';
  assert test_helpers.denied($q$ update public.settings set booking_commission_bps = 0 $q$) or
         test_helpers.affected($q$ update public.settings set booking_commission_bps = 0 $q$) = 0, 'users cannot change settings';
  assert (select count(*) from public.staff_members) = 0, 'users cannot list staff';
  assert (select count(*) from public.audit_log) = 0, 'users cannot read the audit log';
end $$;

:server
insert into public.audit_log (staff_id, action, target_type, details)
  select id, 'test.action', 'partner_account', '{"note":"rls test"}' from public.staff_members;

do $$ begin
  begin
    update public.audit_log set action = 'tampered';
    raise exception 'audit_log update should have failed';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.audit_log;
    raise exception 'audit_log delete should have failed';
  exception when insufficient_privilege then null;
  end;
  begin
    truncate public.audit_log;
    raise exception 'audit_log truncate should have failed';
  exception when insufficient_privilege then null;
  end;
end $$;

:admin
do $$ begin
  assert (select count(*) from public.audit_log) = 1, 'full admin reads the audit log';
  assert (select count(*) from public.staff_members) = 1, 'full admin lists staff';
end $$;

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------
:tolu
do $$ begin
  insert into storage.objects (bucket_id, name, owner) values ('avatars', 'a0000000-0000-0000-0000-000000000001/me.jpg', 'a0000000-0000-0000-0000-000000000001');
  assert test_helpers.denied($q$ insert into storage.objects (bucket_id, name) values ('avatars', 'a0000000-0000-0000-0000-000000000005/steal.jpg') $q$),
    'cannot write into another user''s folder';
  insert into storage.objects (bucket_id, name) values ('pet-photos', 'a0000000-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000001/bingo.jpg');
  insert into storage.objects (bucket_id, name) values ('health-attachments', 'a0000000-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000001/lab.pdf');
  assert test_helpers.denied($q$ insert into storage.objects (bucket_id, name) values ('pet-photos', 'a0000000-0000-0000-0000-000000000001/c0000000-0000-0000-0000-000000000005/luna.jpg') $q$),
    'cannot upload a photo for a pet you do not own';
end $$;

:kemi
do $$ begin
  assert (select count(*) from storage.objects where bucket_id = 'health-attachments') = 0, 'others cannot read health attachments';
  assert (select count(*) from storage.objects where bucket_id = 'pet-photos') = 0, 'private pet photos are hidden from strangers';
end $$;

:bola
do $$ begin
  insert into storage.objects (bucket_id, name) values ('partner-documents', 'a0000000-0000-0000-0000-000000000006/cac.pdf');
end $$;
:tolu
do $$ begin
  assert (select count(*) from storage.objects where bucket_id = 'partner-documents') = 0, 'KYC files are private to the partner and verifiers';
end $$;

:server
select 'RLS tests passed' as result;

rollback;
