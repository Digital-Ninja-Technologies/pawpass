# Data model (starting point)

Postgres on Supabase. All tables have `id uuid primary key default gen_random_uuid()`, `created_at timestamptz default now()` and `updated_at`. Money is stored as integer kobo (`amount_kobo bigint`). Enable Row Level Security on every table.

## People and accounts

| Table | Key columns | Notes |
| --- | --- | --- |
| `profiles` | `user_id` (auth.users), `first_name`, `last_name`, `area`, `phone` (optional), `avatar_path` | One per user |
| `partner_accounts` | `owner_user_id`, `type` (vet, service, breeder, shelter), `business_name`, `area`, `status` (draft, submitted, needs_info, approved, rejected, suspended), `verified_at` | A user can own several |
| `partner_documents` | `partner_account_id`, `kind` (owner_id, cac, licence, facility_photo, vet_reference, payout_account), `storage_path`, `status`, `review_note` | Private storage bucket |
| `staff_members` | `user_id`, `role` (full_admin, payouts_disputes, support_reports, verifications, read_only), `status` | Admin console users |
| `staff_invites` | `email`, `role`, `invited_by`, `note`, `token_hash`, `expires_at`, `accepted_at`, `revoked_at` | 48 hour expiry |

## Pets and passports

| Table | Key columns | Notes |
| --- | --- | --- |
| `pets` | `owner_user_id`, `name`, `species`, `breed`, `sex`, `date_of_birth`, `colour_markings`, `photo_path`, `tag_code`, `origin_partner_id`, `mother_pet_id`, `father_pet_id` | The Pet Passport root |
| `health_records` | `pet_id`, `type` (vaccine, deworming, treatment, vet_visit, weight, allergy), `name`, `given_on`, `next_due_on`, `value`, `given_by_partner_id`, `verified_by_partner_id`, `verified_at`, `attachment_path`, `added_by_user_id` | Vet verified when `verified_by_partner_id` set |
| `reminders` | `pet_id`, `health_record_id`, `due_on`, `channels` (push, email, whatsapp, sms), `status` (scheduled, done, snoozed) | Generated from schedules |
| `passport_shares` | `pet_id`, `partner_account_id` (nullable), `token_hash`, `scopes` (health, origin, write), `expires_at`, `revoked_at` | Time-limited links and QR |
| `ownership_transfers` | `pet_id`, `from_user_id`, `from_partner_id`, `to_user_id`, `escrow_transaction_id`, `completed_at` | Previous owner keeps read access to the transfer record |

## Services and bookings

| Table | Key columns |
| --- | --- |
| `services` | `partner_account_id`, `name`, `price_kobo`, `duration_min`, `active` |
| `availability_slots` | `partner_account_id`, `starts_at`, `ends_at`, `capacity` |
| `bookings` | `owner_user_id`, `pet_id`, `partner_account_id`, `service_id`, `starts_at`, `status` (pending_payment, confirmed, completed_awaiting_owner, completed, cancelled, disputed), `escrow_transaction_id`, `passport_share_id` |
| `reviews` | `booking_id`, `rating`, `tags`, `body`, `status` (published, hidden) |

## Trust: listings and adoption

| Table | Key columns |
| --- | --- |
| `listings` | `partner_account_id`, `pet_id`, `kind` (sale, adoption), `price_kobo`, `status` (draft, live, reserved, sold, adopted, removed), `handover_by` |
| `adoption_applications` | `listing_id`, `applicant_user_id`, `answers jsonb`, `status` (submitted, home_visit, approved, declined) |

## Money

| Table | Key columns | Notes |
| --- | --- | --- |
| `escrow_transactions` | `payer_user_id`, `payee_partner_id`, `kind` (booking, puppy_deposit, puppy_balance), `amount_kobo`, `fee_kobo`, `status` (held, ready, paused, released, refunded, partially_refunded), `release_after`, `paystack_reference` | One row per payment |
| `disputes` | `escrow_transaction_id`, `opened_by_user_id`, `reason`, `details`, `evidence_paths`, `partner_response`, `status` (open, awaiting_partner, decided), `decision` (refund, split, release), `decided_by_staff_id`, `due_at` | Opening a dispute sets the transaction to `paused` |
| `payout_runs` | `run_on`, `status`, `total_kobo` | Weekly, Monday |
| `payout_items` | `payout_run_id`, `partner_account_id`, `amount_kobo`, `paystack_transfer_code`, `status` | |

## Community and safety

| Table | Key columns |
| --- | --- |
| `posts` | `author_user_id`, `pet_id`, `body`, `media_paths`, `visibility` (everyone, nearby, followers), `area`, `status` |
| `follows` | `follower_user_id`, `pet_id` |
| `lost_alerts` | `pet_id`, `last_seen_at`, `last_seen_point geography`, `radius_m`, `description`, `status` (active, found, closed), `closes_at` |
| `sightings` | `lost_alert_id`, `reporter_user_id`, `point geography`, `seen_at`, `note` |
| `conversations`, `messages` | `context_type` (lost_alert, booking, listing, adoption, support), `context_id`; members table; messages with `body`, `attachment_path`, `location` |
| `reports` | `reporter_user_id`, `target_type` (post, profile, listing, review, user, lost_alert), `target_id`, `reason`, `status`, `decided_by_staff_id`, `action` |
| `blocks` | `user_id`, `blocked_user_id` |
| `qr_tag_orders` | `user_id`, `pet_id`, `status` (paid, shipped, delivered), `shipped_at` |

## Support and ops

| Table | Key columns |
| --- | --- |
| `support_tickets` | `user_id`, `topic`, `subject`, `status` (open, waiting_user, closed), `linked_type`, `linked_id` |
| `support_messages` | `ticket_id`, `author_user_id` or `author_staff_id`, `body`, `internal boolean` |
| `settings` | single row: `booking_commission_bps`, `puppy_escrow_fee_bps`, `deposit_fraction`, `vet_check_hours`, `free_cancel_hours`, `kyc_target_hours`, `lost_radius_m`, `lost_autoclose_days`, `payout_weekday` |
| `audit_log` | `staff_id`, `action`, `target_type`, `target_id`, `details jsonb`, `at` |
