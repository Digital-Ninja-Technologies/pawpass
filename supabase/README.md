# supabase

Database schema, row level security, storage rules and seed data for PawPass.

## Layout

| Path                                               | What it holds                                                                                             |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `migrations/20261105100000_core_tables.sql`        | All tables from `docs/data-model.md`, plus the single row `settings` table                                |
| `migrations/20261105110000_functions_triggers.sql` | RLS helper functions (schema `private`), `updated_at`, guards, lost alert defaults                        |
| `migrations/20261105120000_rls.sql`                | Row Level Security policies, column grants and the `public_profiles` view                                 |
| `migrations/20261105130000_storage_realtime.sql`   | Storage buckets and policies, realtime publication                                                        |
| `migrations/20261105140000_admin_console.sql`      | Staff read views (`admin_*_v`) and audited write functions (`admin_*`) for the admin console              |
| `migrations/20261105150000_waitlist.sql`           | Public waitlist table (no longer used by the landing page; kept)                                          |
| `migrations/20261105180000_onboarding.sql`         | `profiles.account_types` and `onboarded_at`, `create_pet_passport()`, owners read their pet rows directly |
| `seed.sql`                                         | Sample data from the designs (Tolu, Bingo, Mimi and the three partners). Local dev only                   |
| `tests/rls.test.sql`                               | Plain SQL tests for the privacy and business rules                                                        |
| `tests/admin.test.sql`                             | Tests for the admin functions: roles, state changes, audit trail, invites                                 |
| `tests/onboarding.test.sql`                        | Tests for the account type fields and `create_pet_passport` (all or nothing, privacy, validation)         |

## How access works

- Every table has RLS. `anon` has no access to anything.
- Owners see their own data. Partners see only what is shared with them through `passport_shares`.
- Staff can read through role scoped policies but never write through the client. Admin actions run in
  server functions with the service role and write `audit_log` (append only).
- These are written **server side only** (no client write policies): `escrow_transactions`, `disputes`,
  `payout_runs`, `payout_items`, `ownership_transfers`, `conversations`, `qr_tag_orders`, `audit_log`,
  `staff_members`, `staff_invites`. Booking status changes, payment, dispute opening and handover are
  edge functions (milestones 3 to 5).
- Health records are private, including from staff. A vet verified record cannot be edited or deleted
  from the client, and only an approved vet with a live `write` share can mark a record verified.
- Phone numbers live in `profiles`, which is readable by the owner only. Other users read
  `public_profiles`, which has no phone column.
- Business rules (commission, escrow fee, deposit, windows, radius, payout day) are in `settings`.

## App sign in (email one time code)

The app signs people in with a 6 digit code, so the Supabase **Magic Link** email template must show the code,
not only a link. In the Supabase dashboard go to Authentication, Emails, Templates, Magic link (and Confirm signup)
and make the body include `{{ .Token }}`, for example:

```html
<h2>Your PawPass code</h2>
<p>Enter this code in the app: <strong>{{ .Token }}</strong></p>
<p>It works once and expires soon. If you did not ask for it, ignore this email.</p>
```

Authentication, Sign In / Providers, Email: keep "Confirm email" on and the OTP length at 6.
The built in email service is limited to a few emails an hour, which is fine for testing but not for launch: set up
custom SMTP (Authentication, Emails, SMTP Settings) with a verified sending domain before real users arrive.

## Creating a pet's passport

The app calls `create_pet_passport(p_pet, p_records, p_channels)`. It runs as the signed in user (so RLS still applies),
in one transaction: the pet with a tag code like `PP-4821-LK`, its health records (never vet verified, they are the
owner's own), a reminder for each record that has a next due date, and `profiles.onboarded_at`. The reminder dates come
from the app's schedule rules; the database only checks them.

## Admin console access

- Staff read through views with `security_invoker`, so each role sees only what RLS allows it.
- Staff write only through `admin_*` functions. Each checks the role, changes the data and writes `audit_log`.
  The web app uses the signed in user's session and never needs the service role key.
- Reviewer notes live in `partner_reviews` (staff only), not on `partner_accounts`, because partner owners can read their own row.
- Suspending a user sets `auth.users.banned_until`, flags the profile, suspends their partner accounts and removes live listings.

## Demo data

`supabase/demo/demo_data.sql` (run after `seed.sql`) adds the sample numbers from the admin designs: partners waiting for
review, escrow in every state, disputes, reports, lost alerts, QR orders and support tickets. `supabase/demo/cleanup.sql`
removes everything `seed.sql` and the demo script created. Do not load either into production.

## Not done yet

- `status` transitions on `bookings` and `escrow_transactions` are not enforced in the database. The
  tested escrow state machine module (milestone 3) owns them.
- Reminder generation from health records (milestone 2).
- `private.close_expired_lost_alerts()` exists but is not scheduled yet (pg_cron or an edge function cron).
- Seed data is not applied to the hosted project.

## Running the tests locally

With the Supabase CLI and Docker:

```bash
supabase start
supabase db reset
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -q -f supabase/tests/rls.test.sql
```

The script runs in one transaction and rolls back. It prints `RLS tests passed` on success.
