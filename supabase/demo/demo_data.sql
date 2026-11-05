-- Demo data for the admin console. Run AFTER seed.sql. Matches the sample numbers in design/screens.
-- NOT for production. Everything here belongs to fake users with @example.com or .example emails;
-- supabase/demo/cleanup.sql removes it.
--
-- Extra users: a...11 Chinedu (Lekki K9 Home)   a...12 Hope Rescue owner   a...13 Happy Tails owner
--              a...14 Glam Paws owner           a...15 Prince Kennels      a...16 Emeka O (buyer)
--              a...17 Funmi A (owner)

insert into auth.users (id, email, aud, role, email_confirmed_at, raw_user_meta_data) values
  ('a0000000-0000-0000-0000-000000000011', 'chinedu@lekkik9.example',  'authenticated', 'authenticated', now(), '{"first_name":"Chinedu","last_name":"Okafor"}'),
  ('a0000000-0000-0000-0000-000000000012', 'hope@hoperescue.example',  'authenticated', 'authenticated', now(), '{"first_name":"Hope","last_name":"Animal Rescue"}'),
  ('a0000000-0000-0000-0000-000000000013', 'info@happytails.example',  'authenticated', 'authenticated', now(), '{"first_name":"Happy","last_name":"Tails"}'),
  ('a0000000-0000-0000-0000-000000000014', 'hello@glampaws.example',   'authenticated', 'authenticated', now(), '{"first_name":"Glam","last_name":"Paws"}'),
  ('a0000000-0000-0000-0000-000000000015', 'prince@princekennels.example', 'authenticated', 'authenticated', now() - interval '1 day', '{"first_name":"Prince","last_name":"Kennels"}'),
  ('a0000000-0000-0000-0000-000000000016', 'emeka@example.com',        'authenticated', 'authenticated', now(), '{"first_name":"Emeka","last_name":"Obi"}'),
  ('a0000000-0000-0000-0000-000000000017', 'funmi@example.com',        'authenticated', 'authenticated', now(), '{"first_name":"Funmi","last_name":"Adebayo"}');
update public.profiles set area = 'Lekki' where user_id in ('a0000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000014', 'a0000000-0000-0000-0000-000000000017');
update public.profiles set area = 'Surulere' where user_id = 'a0000000-0000-0000-0000-000000000012';
update public.profiles set area = 'Ikeja' where user_id in ('a0000000-0000-0000-0000-000000000013', 'a0000000-0000-0000-0000-000000000016');
update public.profiles set first_name = 'Ops', last_name = 'Admin' where user_id = 'a0000000-0000-0000-0000-000000000007';

-- Partners waiting for review (submitted at different times) -----------------------------------
insert into public.partner_accounts (id, owner_user_id, type, business_name, area, status, submitted_at, created_at) values
  ('b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000011', 'breeder', 'Lekki K9 Home',        'Lekki',    'submitted', now() - interval '31 hours', now() - interval '31 hours'),
  ('b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000012', 'shelter', 'Hope Animal Rescue',   'Surulere', 'submitted', now() - interval '20 hours', now() - interval '20 hours'),
  ('b0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000013', 'service', 'Happy Tails Boarding', 'Ikeja',    'submitted', now() - interval '6 hours',  now() - interval '6 hours'),
  ('b0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000014', 'service', 'Glam Paws Grooming',   'Lekki',    'submitted', now() - interval '2 hours',  now() - interval '2 hours'),
  ('b0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000015', 'breeder', 'Prince Kennels',      'Unknown',  'submitted', now() - interval '1 day',    now() - interval '1 day');
update public.partner_accounts set submitted_at = created_at where id = 'b0000000-0000-0000-0000-000000000004';

insert into public.partner_documents (partner_account_id, kind, storage_path) values
  ('b0000000-0000-0000-0000-000000000005', 'owner_id',       'a0000000-0000-0000-0000-000000000011/owner-id.pdf'),
  ('b0000000-0000-0000-0000-000000000005', 'cac',            'a0000000-0000-0000-0000-000000000011/cac.pdf'),
  ('b0000000-0000-0000-0000-000000000005', 'facility_photo', 'a0000000-0000-0000-0000-000000000011/facility.jpg'),
  ('b0000000-0000-0000-0000-000000000005', 'vet_reference',  'a0000000-0000-0000-0000-000000000011/vet-reference.pdf'),
  ('b0000000-0000-0000-0000-000000000005', 'payout_account', 'a0000000-0000-0000-0000-000000000011/payout.pdf'),
  ('b0000000-0000-0000-0000-000000000006', 'owner_id',       'a0000000-0000-0000-0000-000000000012/owner-id.pdf'),
  ('b0000000-0000-0000-0000-000000000006', 'cac',            'a0000000-0000-0000-0000-000000000012/cac.pdf'),
  ('b0000000-0000-0000-0000-000000000006', 'facility_photo', 'a0000000-0000-0000-0000-000000000012/facility.jpg'),
  ('b0000000-0000-0000-0000-000000000007', 'owner_id',       'a0000000-0000-0000-0000-000000000013/owner-id.pdf'),
  ('b0000000-0000-0000-0000-000000000007', 'cac',            'a0000000-0000-0000-0000-000000000013/cac.pdf'),
  ('b0000000-0000-0000-0000-000000000007', 'facility_photo', 'a0000000-0000-0000-0000-000000000013/facility.jpg');
insert into public.partner_reviews (partner_account_id, kyc_checks, internal_note) values
  ('b0000000-0000-0000-0000-000000000005', '{"name_matches": true, "address_in_area": true, "no_duplicates": true}', 'Vet reference still to be confirmed by phone.');

-- Pets, listings -------------------------------------------------------------------------------
insert into public.pets (id, owner_user_id, name, species, breed, sex, date_of_birth) values
  ('c0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000016', 'Nala',  'dog', 'German Shepherd', 'female', current_date - 90),
  ('c0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000015', 'Rottweiler puppies', 'dog', 'Rottweiler', 'unknown', current_date - 60),
  ('c0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000003', 'Max',   'dog', 'Rottweiler', 'male', current_date - 70),
  ('c0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000017', 'Bruno', 'dog', 'Jack Russell', 'male', '2023-03-01'),
  ('c0000000-0000-0000-0000-00000000000a', 'a0000000-0000-0000-0000-000000000016', 'Simba', 'dog', 'Boerboel', 'male', '2022-06-01'),
  ('c0000000-0000-0000-0000-00000000000b', 'a0000000-0000-0000-0000-000000000016', 'Coco',  'cat', 'Domestic shorthair', 'female', '2024-01-01');
insert into public.listings (id, partner_account_id, pet_id, kind, price_kobo, status) values
  ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000009', 'c0000000-0000-0000-0000-000000000007', 'sale', 12000000, 'live'),
  ('f0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000008', 'sale', 34000000, 'live');

-- Money: escrow in every state, two disputes -----------------------------------------------------
insert into public.escrow_transactions (id, payer_user_id, payee_partner_id, kind, amount_kobo, fee_kobo, status, created_at) values
  ('e0000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'puppy_deposit', 15750000, 787500, 'held',     now() - interval '3 hours'),
  ('e0000000-0000-0000-0000-000000000012', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking',        1500000, 180000, 'held',     now() - interval '4 hours'),
  ('e0000000-0000-0000-0000-000000000013', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking',        1200000, 144000, 'ready',    now() - interval '2 days'),
  ('e0000000-0000-0000-0000-000000000014', 'a0000000-0000-0000-0000-000000000016', 'b0000000-0000-0000-0000-000000000002', 'puppy_balance', 38000000, 1900000, 'paused',   now() - interval '4 days'),
  ('e0000000-0000-0000-0000-000000000015', 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'booking',        2000000, 240000, 'released', now() - interval '10 days'),
  ('e0000000-0000-0000-0000-000000000016', 'a0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', 'booking',        1800000, 216000, 'refunded', now() - interval '14 days'),
  ('e0000000-0000-0000-0000-000000000017', 'a0000000-0000-0000-0000-000000000017', 'b0000000-0000-0000-0000-000000000001', 'booking',        6250000, 750000, 'paused',   now() - interval '9 days'),
  ('e0000000-0000-0000-0000-000000000018', 'a0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000003', 'booking',        4500000, 540000, 'paused',   now() - interval '6 days');
insert into public.ownership_transfers (pet_id, from_partner_id, to_user_id, escrow_transaction_id, completed_at) values
  ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000011', null),
  ('c0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000016', 'e0000000-0000-0000-0000-000000000014', now() - interval '3 days');
insert into public.bookings (owner_user_id, pet_id, partner_account_id, service_id, starts_at, status, escrow_transaction_id)
select 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', s.id, now() + interval '3 hours', 'confirmed', 'e0000000-0000-0000-0000-000000000012'
  from public.services s where s.name = 'Vet consultation';
insert into public.disputes (id, escrow_transaction_id, opened_by_user_id, reason, details, partner_response, status, due_at, created_at) values
  ('d1000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000014', 'a0000000-0000-0000-0000-000000000016', 'Puppy ill after handover',
     'Nala was diagnosed with parvovirus 2 days after pickup. Vet report attached.',
     'She was healthy at handover. Our vet checked the litter on 28 Oct.', 'open', now() + interval '6 hours', now() - interval '1 day'),
  ('d1000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000018', 'a0000000-0000-0000-0000-000000000005', 'Dog returned with a wound', 'Luna came back with a cut on her paw.', null, 'open', now() + interval '2 days', now() - interval '3 days'),
  ('d1000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000017', 'a0000000-0000-0000-0000-000000000017', 'Sessions not delivered', 'The trainer never showed up for 3 sessions.', null, 'open', now() + interval '3 days', now() - interval '2 days');

-- A year of completed bookings for the chart -----------------------------------------------------
insert into public.bookings (owner_user_id, pet_id, partner_account_id, service_id, starts_at, status)
select 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', s.id,
       now() - (g * 1.4) * interval '1 day', 'completed'
  from public.services s, generate_series(1, 60) g where s.name = 'Vet consultation';

-- Reports ----------------------------------------------------------------------------------------
insert into public.posts (id, author_user_id, pet_id, body, visibility, area) values
  ('90000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000015', null, 'DM me for cheap vaccines, no vet needed', 'everyone', 'Lekki'),
  ('90000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000016', null, 'Comment on Rex & Tiger post: you people are useless', 'everyone', 'Ikeja');
insert into public.reports (reporter_user_id, target_type, target_id, reason, created_at)
select r.u, 'listing', 'f0000000-0000-0000-0000-000000000001', 'Possible scam: pay deposit by transfer to reserve', now() - interval '3 hours'
  from (values ('a0000000-0000-0000-0000-000000000001'::uuid), ('a0000000-0000-0000-0000-000000000005'), ('a0000000-0000-0000-0000-000000000003'), ('a0000000-0000-0000-0000-000000000004')) r(u);
insert into public.reports (reporter_user_id, target_type, target_id, reason, created_at)
select r.u, 'post', '90000000-0000-0000-0000-000000000001', 'Unsafe advice', now() - interval '7 hours'
  from (values ('a0000000-0000-0000-0000-000000000001'::uuid), ('a0000000-0000-0000-0000-000000000005'), ('a0000000-0000-0000-0000-000000000004')) r(u);
insert into public.reports (reporter_user_id, target_type, target_id, reason, created_at)
select r.u, 'post', '90000000-0000-0000-0000-000000000002', 'Harassment', now() - interval '14 hours'
  from (values ('a0000000-0000-0000-0000-000000000001'::uuid), ('a0000000-0000-0000-0000-000000000005')) r(u);
insert into public.reports (reporter_user_id, target_type, target_id, reason, created_at)
select r.u, 'user', 'a0000000-0000-0000-0000-000000000015', 'Spam messages', now() - interval '18 hours'
  from (values ('a0000000-0000-0000-0000-000000000001'::uuid), ('a0000000-0000-0000-0000-000000000005'), ('a0000000-0000-0000-0000-000000000003')) r(u);

-- Lost and found, QR orders ------------------------------------------------------------------------
insert into public.lost_alerts (id, pet_id, last_seen_point, description, created_at) values
  ('a1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000009', extensions.st_point(3.4700, 6.4400, 4326)::extensions.geography, 'Last seen near Lekki Phase 1', now() - interval '2 hours'),
  ('a1000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-00000000000a', extensions.st_point(3.3500, 6.5900, 4326)::extensions.geography, 'Slipped out of the gate in Ikeja GRA', now() - interval '3 days'),
  ('a1000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-00000000000b', extensions.st_point(3.3500, 6.5000, 4326)::extensions.geography, 'Missing in Surulere', now() - interval '5 hours');
insert into public.sightings (lost_alert_id, reporter_user_id, point, note)
select 'a1000000-0000-0000-0000-000000000002', u, extensions.st_point(3.351, 6.591, 4326)::extensions.geography, 'Saw a dog like Simba'
  from (values ('a0000000-0000-0000-0000-000000000001'::uuid), ('a0000000-0000-0000-0000-000000000005'), ('a0000000-0000-0000-0000-000000000003'), ('a0000000-0000-0000-0000-000000000004')) r(u);
insert into public.sightings (lost_alert_id, reporter_user_id, point, note)
values ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000005', extensions.st_point(3.471, 6.441, 4326)::extensions.geography, 'Near the market');
insert into public.reports (reporter_user_id, target_type, target_id, reason) values
  ('a0000000-0000-0000-0000-000000000005', 'lost_alert', 'a1000000-0000-0000-0000-000000000002', 'Possible theft'),
  ('a0000000-0000-0000-0000-000000000001', 'lost_alert', 'a1000000-0000-0000-0000-000000000003', 'Fake: asks for reward first');
insert into public.qr_tag_orders (user_id, pet_id, created_at) values
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', now() - interval '4 days'),
  ('a0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005', now() - interval '4 days'),
  ('a0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000008', now() - interval '1 day'),
  ('a0000000-0000-0000-0000-000000000016', 'c0000000-0000-0000-0000-000000000006', now() - interval '3 hours');
update public.pets set tag_code = 'PP-' || upper(right(replace(id::text, '-', ''), 4)) where tag_code is null and id in ('c0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000005');

-- Support inbox ------------------------------------------------------------------------------------
insert into public.support_tickets (id, user_id, topic, subject, status, linked_type, created_at) values
  ('51000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000017', 'Payments & refunds', 'When will my booking refund arrive?', 'open', 'dispute', now() - interval '40 minutes'),
  ('51000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 'Partner account', 'How do I add a second branch?', 'open', null, now() - interval '2 hours'),
  ('51000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000005', 'Passport', 'Vet added the wrong vaccine date', 'open', null, now() - interval '5 hours'),
  ('51000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'QR tags', 'QR tag delivery date', 'waiting_user', null, now() - interval '3 days');
insert into public.support_messages (ticket_id, author_user_id, body) values
  ('51000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000017', 'The trainer never showed up for 3 sessions. I reported it on Monday. When do I get my ₦62,500 back?'),
  ('51000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 'We opened a second clinic in Yaba. How do I add it?'),
  ('51000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000005', 'The DHPP date on Luna''s passport is wrong.'),
  ('51000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'When will my QR tag arrive?');
