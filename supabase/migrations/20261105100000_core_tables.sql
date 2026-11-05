-- PawPass core schema. Source of truth: docs/data-model.md.
-- Conventions: uuid ids, timestamptz, money as integer kobo (bigint),
-- text columns with check constraints instead of enums (easier to evolve).
-- Row Level Security is enabled in 20261105120000_rls.sql.

create extension if not exists postgis with schema extensions;

create schema if not exists private;
comment on schema private is 'Helper functions used by RLS policies. Not exposed through the API.';

-- ---------------------------------------------------------------------------
-- Settings (single row). Business rules live here, not in code.
-- ---------------------------------------------------------------------------
create table public.settings (
  id uuid primary key default gen_random_uuid(),
  singleton boolean not null default true unique check (singleton),
  booking_commission_bps integer not null default 1200 check (booking_commission_bps between 0 and 10000),
  puppy_escrow_fee_bps integer not null default 500 check (puppy_escrow_fee_bps between 0 and 10000),
  -- One third of the price. Code rounds up to whole kobo.
  deposit_fraction numeric not null default (1.0 / 3.0) check (deposit_fraction > 0 and deposit_fraction <= 1),
  vet_check_hours integer not null default 72 check (vet_check_hours >= 0),
  free_cancel_hours integer not null default 2 check (free_cancel_hours >= 0),
  kyc_target_hours integer not null default 48 check (kyc_target_hours > 0),
  lost_radius_m integer not null default 5000 check (lost_radius_m > 0),
  lost_autoclose_days integer not null default 14 check (lost_autoclose_days > 0),
  -- ISO weekday, 1 = Monday.
  payout_weekday smallint not null default 1 check (payout_weekday between 1 and 7),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
insert into public.settings default values;

-- ---------------------------------------------------------------------------
-- People and accounts
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  first_name text not null default '',
  last_name text not null default '',
  area text,
  phone text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.partner_accounts (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('vet', 'service', 'breeder', 'shelter')),
  business_name text not null,
  area text,
  point extensions.geography(Point, 4326),
  status text not null default 'draft'
    check (status in ('draft', 'submitted', 'needs_info', 'approved', 'rejected', 'suspended')),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.partner_accounts (owner_user_id);
create index on public.partner_accounts (type, status);
create index on public.partner_accounts using gist (point);

create table public.partner_documents (
  id uuid primary key default gen_random_uuid(),
  partner_account_id uuid not null references public.partner_accounts (id) on delete cascade,
  kind text not null
    check (kind in ('owner_id', 'cac', 'licence', 'facility_photo', 'vet_reference', 'payout_account')),
  storage_path text not null,
  status text not null default 'submitted' check (status in ('submitted', 'approved', 'rejected')),
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.partner_documents (partner_account_id);

create table public.staff_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  role text not null
    check (role in ('full_admin', 'payouts_disputes', 'support_reports', 'verifications', 'read_only')),
  status text not null default 'active' check (status in ('active', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.staff_invites (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  role text not null
    check (role in ('full_admin', 'payouts_disputes', 'support_reports', 'verifications', 'read_only')),
  invited_by uuid not null references public.staff_members (id),
  note text,
  token_hash text not null unique,
  -- 48 hour expiry, set by the server function that creates the invite.
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.staff_invites (lower(email));

-- ---------------------------------------------------------------------------
-- Money (before tables that point at escrow rows)
-- ---------------------------------------------------------------------------
create table public.escrow_transactions (
  id uuid primary key default gen_random_uuid(),
  payer_user_id uuid not null references auth.users (id),
  payee_partner_id uuid not null references public.partner_accounts (id),
  kind text not null check (kind in ('booking', 'puppy_deposit', 'puppy_balance')),
  amount_kobo bigint not null check (amount_kobo > 0),
  fee_kobo bigint not null default 0 check (fee_kobo >= 0 and fee_kobo <= amount_kobo),
  status text not null default 'held'
    check (status in ('held', 'ready', 'paused', 'released', 'refunded', 'partially_refunded')),
  release_after timestamptz,
  paystack_reference text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.escrow_transactions (payer_user_id);
create index on public.escrow_transactions (payee_partner_id, status);

-- ---------------------------------------------------------------------------
-- Pets and passports
-- ---------------------------------------------------------------------------
create table public.pets (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users (id),
  name text not null,
  species text not null check (species in ('dog', 'cat', 'other')),
  breed text,
  sex text not null default 'unknown' check (sex in ('male', 'female', 'unknown')),
  date_of_birth date,
  colour_markings text,
  photo_path text,
  tag_code text unique,
  origin_partner_id uuid references public.partner_accounts (id),
  mother_pet_id uuid references public.pets (id),
  father_pet_id uuid references public.pets (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.pets (owner_user_id);
create index on public.pets (origin_partner_id);

create table public.health_records (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  type text not null check (type in ('vaccine', 'deworming', 'treatment', 'vet_visit', 'weight', 'allergy')),
  name text not null,
  given_on date,
  next_due_on date,
  value text,
  given_by_partner_id uuid references public.partner_accounts (id),
  -- "Vet verified" when this is set.
  verified_by_partner_id uuid references public.partner_accounts (id),
  verified_at timestamptz,
  attachment_path text,
  added_by_user_id uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((verified_by_partner_id is null) = (verified_at is null))
);
create index on public.health_records (pet_id, given_on desc);
create index on public.health_records (next_due_on) where next_due_on is not null;

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  health_record_id uuid references public.health_records (id) on delete cascade,
  due_on date not null,
  channels text[] not null default array['push']
    check (channels <@ array['push', 'email', 'whatsapp', 'sms']),
  status text not null default 'scheduled' check (status in ('scheduled', 'done', 'snoozed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.reminders (pet_id);
create index on public.reminders (due_on) where status <> 'done';

create table public.passport_shares (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  partner_account_id uuid references public.partner_accounts (id),
  -- Only the hash is stored; the raw token lives in the link or QR code.
  token_hash text not null unique,
  scopes text[] not null default array['health'] check (scopes <@ array['health', 'origin', 'write']),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.passport_shares (pet_id);
create index on public.passport_shares (partner_account_id);

create table public.ownership_transfers (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id),
  from_user_id uuid references auth.users (id),
  from_partner_id uuid references public.partner_accounts (id),
  to_user_id uuid not null references auth.users (id),
  escrow_transaction_id uuid references public.escrow_transactions (id),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (from_user_id is not null or from_partner_id is not null)
);
create index on public.ownership_transfers (pet_id);
create index on public.ownership_transfers (from_user_id);
create index on public.ownership_transfers (to_user_id);

-- ---------------------------------------------------------------------------
-- Services and bookings
-- ---------------------------------------------------------------------------
create table public.services (
  id uuid primary key default gen_random_uuid(),
  partner_account_id uuid not null references public.partner_accounts (id) on delete cascade,
  name text not null,
  price_kobo bigint not null check (price_kobo >= 0),
  duration_min integer check (duration_min > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.services (partner_account_id);

create table public.availability_slots (
  id uuid primary key default gen_random_uuid(),
  partner_account_id uuid not null references public.partner_accounts (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer not null default 1 check (capacity >= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index on public.availability_slots (partner_account_id, starts_at);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users (id),
  pet_id uuid not null references public.pets (id),
  partner_account_id uuid not null references public.partner_accounts (id),
  service_id uuid not null references public.services (id),
  starts_at timestamptz not null,
  status text not null default 'pending_payment'
    check (status in ('pending_payment', 'confirmed', 'completed_awaiting_owner', 'completed', 'cancelled', 'disputed')),
  escrow_transaction_id uuid references public.escrow_transactions (id),
  passport_share_id uuid references public.passport_shares (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.bookings (owner_user_id, starts_at desc);
create index on public.bookings (partner_account_id, starts_at desc);
create index on public.bookings (pet_id);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  tags text[] not null default '{}',
  body text,
  status text not null default 'published' check (status in ('published', 'hidden')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Trust: listings and adoption
-- ---------------------------------------------------------------------------
create table public.listings (
  id uuid primary key default gen_random_uuid(),
  partner_account_id uuid not null references public.partner_accounts (id) on delete cascade,
  pet_id uuid not null references public.pets (id),
  kind text not null check (kind in ('sale', 'adoption')),
  price_kobo bigint check (price_kobo >= 0),
  status text not null default 'draft'
    check (status in ('draft', 'live', 'reserved', 'sold', 'adopted', 'removed')),
  handover_by timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (kind = 'adoption' or price_kobo is not null)
);
create index on public.listings (partner_account_id);
create index on public.listings (status, kind);
create index on public.listings (pet_id);

create table public.adoption_applications (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  applicant_user_id uuid not null references auth.users (id),
  answers jsonb not null default '{}',
  status text not null default 'submitted' check (status in ('submitted', 'home_visit', 'approved', 'declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (listing_id, applicant_user_id)
);
create index on public.adoption_applications (applicant_user_id);

-- ---------------------------------------------------------------------------
-- Disputes and payouts
-- ---------------------------------------------------------------------------
create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  escrow_transaction_id uuid not null references public.escrow_transactions (id),
  opened_by_user_id uuid not null references auth.users (id),
  reason text not null,
  details text,
  evidence_paths text[] not null default '{}',
  partner_response text,
  status text not null default 'open' check (status in ('open', 'awaiting_partner', 'decided')),
  decision text check (decision in ('refund', 'split', 'release')),
  decided_by_staff_id uuid references public.staff_members (id),
  due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'decided') = (decision is not null))
);
create index on public.disputes (escrow_transaction_id);
create index on public.disputes (opened_by_user_id);
create index on public.disputes (status);

create table public.payout_runs (
  id uuid primary key default gen_random_uuid(),
  run_on date not null unique,
  -- Admins review a draft run before it is approved and sent.
  status text not null default 'draft' check (status in ('draft', 'approved', 'sent', 'failed')),
  total_kobo bigint not null default 0 check (total_kobo >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.payout_items (
  id uuid primary key default gen_random_uuid(),
  payout_run_id uuid not null references public.payout_runs (id) on delete cascade,
  partner_account_id uuid not null references public.partner_accounts (id),
  amount_kobo bigint not null check (amount_kobo > 0),
  paystack_transfer_code text,
  status text not null default 'pending' check (status in ('pending', 'held', 'sent', 'failed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.payout_items (payout_run_id);
create index on public.payout_items (partner_account_id);

-- ---------------------------------------------------------------------------
-- Community and safety
-- ---------------------------------------------------------------------------
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_user_id uuid not null references auth.users (id) on delete cascade,
  pet_id uuid references public.pets (id) on delete set null,
  body text not null default '',
  media_paths text[] not null default '{}',
  visibility text not null default 'everyone' check (visibility in ('everyone', 'nearby', 'followers')),
  area text,
  status text not null default 'published' check (status in ('published', 'hidden', 'removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.posts (author_user_id);
create index on public.posts (status, created_at desc);
create index on public.posts (pet_id);

create table public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_user_id uuid not null references auth.users (id) on delete cascade,
  pet_id uuid not null references public.pets (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (follower_user_id, pet_id)
);
create index on public.follows (pet_id);

create table public.lost_alerts (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  last_seen_at timestamptz not null default now(),
  last_seen_point extensions.geography(Point, 4326) not null,
  -- Filled from settings.lost_radius_m / lost_autoclose_days when left null.
  radius_m integer check (radius_m > 0),
  description text,
  status text not null default 'active' check (status in ('active', 'found', 'closed')),
  closes_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.lost_alerts (pet_id);
create index on public.lost_alerts (status, closes_at);
create index on public.lost_alerts using gist (last_seen_point);

create table public.sightings (
  id uuid primary key default gen_random_uuid(),
  lost_alert_id uuid not null references public.lost_alerts (id) on delete cascade,
  reporter_user_id uuid not null references auth.users (id),
  point extensions.geography(Point, 4326) not null,
  seen_at timestamptz not null default now(),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.sightings (lost_alert_id);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  context_type text not null check (context_type in ('lost_alert', 'booking', 'listing', 'adoption', 'support')),
  context_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.conversations (context_type, context_id);

create table public.conversation_members (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  last_read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (conversation_id, user_id)
);
create index on public.conversation_members (user_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_user_id uuid not null references auth.users (id),
  body text,
  attachment_path text,
  location extensions.geography(Point, 4326),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (body is not null or attachment_path is not null or location is not null)
);
create index on public.messages (conversation_id, created_at);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references auth.users (id),
  target_type text not null check (target_type in ('post', 'profile', 'listing', 'review', 'user', 'lost_alert')),
  target_id uuid not null,
  reason text not null,
  status text not null default 'open' check (status in ('open', 'actioned', 'dismissed')),
  decided_by_staff_id uuid references public.staff_members (id),
  action text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.reports (status);
create index on public.reports (target_type, target_id);

create table public.blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  blocked_user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, blocked_user_id),
  check (user_id <> blocked_user_id)
);
create index on public.blocks (blocked_user_id);

create table public.qr_tag_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  pet_id uuid not null references public.pets (id),
  status text not null default 'paid' check (status in ('paid', 'shipped', 'delivered')),
  shipped_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.qr_tag_orders (user_id);

-- ---------------------------------------------------------------------------
-- Support and ops
-- ---------------------------------------------------------------------------
create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  topic text not null,
  subject text not null,
  status text not null default 'open' check (status in ('open', 'waiting_user', 'closed')),
  linked_type text,
  linked_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.support_tickets (user_id);
create index on public.support_tickets (status);

create table public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets (id) on delete cascade,
  author_user_id uuid references auth.users (id),
  author_staff_id uuid references public.staff_members (id),
  body text not null,
  -- Internal notes are never visible to the ticket owner.
  internal boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((author_user_id is null) <> (author_staff_id is null)),
  check (not internal or author_staff_id is not null)
);
create index on public.support_messages (ticket_id, created_at);

-- Append only. Updates and deletes are blocked by a trigger.
create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid references public.staff_members (id),
  action text not null,
  target_type text,
  target_id uuid,
  details jsonb not null default '{}',
  at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index on public.audit_log (at desc);
create index on public.audit_log (staff_id);
create index on public.audit_log (target_type, target_id);
