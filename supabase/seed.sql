-- Sample data from the designs. For LOCAL DEVELOPMENT ONLY (runs on `supabase db reset`).
-- Do not run against production: it creates fake auth users.
-- Names, prices and dates are the sample values used in design/screens.
-- Users have no password; sign in with an email one time code in local dev.

-- Fixed ids so tests and docs can refer to them.
--   users     a0000000-...-0001 Tolu (owner)           -0002 Dr. Amina Bello (vet)
--             -0003 Chidi (Royal Paws)                 -0004 Ngozi (Lagos Paws Rescue)
--             -0005 Kemi (community)                   -0006 Bola (new partner, pending)
--             -0007 Staff admin
--   partners  b0000000-...-0001 Paws & Claws Vet Clinic -0002 Royal Paws Kennels
--             -0003 Lagos Paws Rescue                    -0004 Bola's Grooming (submitted)
--   pets      c0000000-...-0001 Bingo -0002 Mimi -0003 Duke (puppy) -0004 Biscuit (rescue) -0005 Luna

insert into auth.users (id, email, aud, role, email_confirmed_at, raw_user_meta_data) values
  ('a0000000-0000-0000-0000-000000000001', 'tolu@example.com',   'authenticated', 'authenticated', now(), '{"first_name":"Tolu","last_name":"Adeyemi"}'),
  ('a0000000-0000-0000-0000-000000000002', 'amina@pawsandclaws.example', 'authenticated', 'authenticated', now(), '{"first_name":"Amina","last_name":"Bello"}'),
  ('a0000000-0000-0000-0000-000000000003', 'chidi@royalpaws.example',    'authenticated', 'authenticated', now(), '{"first_name":"Chidi","last_name":"Okafor"}'),
  ('a0000000-0000-0000-0000-000000000004', 'ngozi@lagospawsrescue.example', 'authenticated', 'authenticated', now(), '{"first_name":"Ngozi","last_name":"Eze"}'),
  ('a0000000-0000-0000-0000-000000000005', 'kemi@example.com',   'authenticated', 'authenticated', now(), '{"first_name":"Kemi","last_name":"Balogun"}'),
  ('a0000000-0000-0000-0000-000000000006', 'bola@example.com',   'authenticated', 'authenticated', now(), '{"first_name":"Bola","last_name":"Ajayi"}'),
  ('a0000000-0000-0000-0000-000000000007', 'admin@pawpass.example', 'authenticated', 'authenticated', now(), '{"first_name":"Ops","last_name":"Admin"}');

-- Profiles are created by the on_auth_user_created trigger; fill in the area.
update public.profiles set area = 'Lekki'    where user_id = 'a0000000-0000-0000-0000-000000000001';
update public.profiles set area = 'Yaba'     where user_id = 'a0000000-0000-0000-0000-000000000005';
update public.profiles set area = 'Ikeja'    where user_id in ('a0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003');
update public.profiles set area = 'Surulere' where user_id = 'a0000000-0000-0000-0000-000000000004';

insert into public.staff_members (user_id, role) values
  ('a0000000-0000-0000-0000-000000000007', 'full_admin');

-- ---------------------------------------------------------------------------
-- Partners
-- ---------------------------------------------------------------------------
insert into public.partner_accounts (id, owner_user_id, type, business_name, area, point, status, verified_at) values
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'vet',     'Paws & Claws Vet Clinic', 'Ikeja',
     extensions.st_point(3.3515, 6.6018, 4326)::extensions.geography, 'approved', now() - interval '60 days'),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003', 'breeder', 'Royal Paws Kennels', 'Ikeja',
     extensions.st_point(3.3400, 6.5950, 4326)::extensions.geography, 'approved', now() - interval '90 days'),
  ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000004', 'shelter', 'Lagos Paws Rescue', 'Surulere',
     extensions.st_point(3.3550, 6.5000, 4326)::extensions.geography, 'approved', now() - interval '120 days'),
  ('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000006', 'service', 'Bola''s Grooming', 'Yaba',
     null, 'submitted', null);

insert into public.partner_documents (partner_account_id, kind, storage_path, status) values
  ('b0000000-0000-0000-0000-000000000004', 'owner_id',       'a0000000-0000-0000-0000-000000000006/owner-id.jpg', 'submitted'),
  ('b0000000-0000-0000-0000-000000000004', 'facility_photo', 'a0000000-0000-0000-0000-000000000006/facility.jpg', 'submitted');

insert into public.services (partner_account_id, name, price_kobo, duration_min) values
  ('b0000000-0000-0000-0000-000000000001', 'Vet consultation', 1500000, 30),
  ('b0000000-0000-0000-0000-000000000001', 'Vaccination',        800000, 20),
  ('b0000000-0000-0000-0000-000000000004', 'Full groom',        1200000, 90);

insert into public.availability_slots (partner_account_id, starts_at, ends_at, capacity) values
  ('b0000000-0000-0000-0000-000000000001', '2026-11-09 09:00+01', '2026-11-09 13:00+01', 4),
  ('b0000000-0000-0000-0000-000000000001', '2026-11-10 09:00+01', '2026-11-10 13:00+01', 4);

-- ---------------------------------------------------------------------------
-- Pets and passports
-- ---------------------------------------------------------------------------
insert into public.pets (id, owner_user_id, name, species, breed, sex, date_of_birth, colour_markings, tag_code, origin_partner_id) values
  ('c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Bingo',   'dog', 'Boerboel', 'male',   '2024-08-14', 'Fawn with black mask', 'PP-4821-LK', 'b0000000-0000-0000-0000-000000000002'),
  ('c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Mimi',    'cat', 'Domestic shorthair', 'female', '2023-05-02', 'Grey tabby', null, null),
  ('c0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000003', 'Duke',    'dog', 'Boerboel', 'male',   current_date - 63, 'Fawn', null, 'b0000000-0000-0000-0000-000000000002'),
  ('c0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000004', 'Biscuit', 'dog', 'Mixed breed', 'female', '2025-02-10', 'Tan and white', null, null),
  ('c0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000005', 'Luna',    'cat', 'Persian', 'female', '2023-09-20', 'White', null, null);

-- Tolu wants reminders on the app and WhatsApp (set before the records, which create the reminders).
update public.profiles set reminder_channels = array['push', 'whatsapp'] where user_id = 'a0000000-0000-0000-0000-000000000001';

insert into public.health_records
  (pet_id, type, name, given_on, next_due_on, value, given_by_partner_id, verified_by_partner_id, verified_at, added_by_user_id) values
  -- Vet verified by Paws & Claws (Dr. Amina Bello).
  ('c0000000-0000-0000-0000-000000000001', 'vaccine',   'DHPP vaccine',     '2026-03-12', '2027-03-12', null,
     'b0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', '2026-03-12 11:00+01', 'a0000000-0000-0000-0000-000000000002'),
  -- Added by the owner, so no "Vet verified" badge.
  ('c0000000-0000-0000-0000-000000000001', 'vaccine',   'Rabies booster',   '2025-11-12', '2026-11-12', null,
     null, null, null, 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000001', 'deworming', 'Deworming',        '2026-10-20', null, null,
     null, null, null, 'a0000000-0000-0000-0000-000000000001'),
  ('c0000000-0000-0000-0000-000000000001', 'weight',    'Weight',           '2026-10-01', null, '41 kg',
     null, null, null, 'a0000000-0000-0000-0000-000000000001');

-- Reminders are created from the records above by a trigger, using the owner's reminder_channels.

-- ---------------------------------------------------------------------------
-- Listings, community
-- ---------------------------------------------------------------------------
insert into public.listings (partner_account_id, pet_id, kind, price_kobo, status, handover_by) values
  ('b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003', 'sale',     45000000, 'live', '2026-11-12 12:00+01'),
  ('b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000004', 'adoption', null,     'live', null);

insert into public.posts (author_user_id, pet_id, body, visibility, area) values
  ('a0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005', 'Luna loves the window seat this morning.', 'everyone', 'Yaba'),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Bingo met the new puppy next door.', 'nearby', 'Lekki');

-- ---------------------------------------------------------------------------
-- Emergency vet details (milestone 2). Phone numbers are placeholders, not real lines.
-- ---------------------------------------------------------------------------
update public.partner_accounts
   set phone = '+2340000000001', opens_at = '08:00', closes_at = '20:00', emergency_care = true
 where id = 'b0000000-0000-0000-0000-000000000001';

insert into public.partner_accounts
  (id, owner_user_id, type, business_name, area, point, status, verified_at, phone, open_24h, emergency_care, home_visits)
values
  ('b0000000-0000-0000-0000-0000000000a1', 'a0000000-0000-0000-0000-000000000002', 'vet', 'Lekki Animal Hospital', 'Lekki',
     extensions.st_point(3.4720, 6.4400, 4326)::extensions.geography, 'approved', now() - interval '45 days',
     '+2340000000002', true, true, false);
