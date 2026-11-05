# supabase

Database schema, row level security, storage rules and seed data for PawPass.

## Layout

| Path                                               | What it holds                                                                                |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `migrations/20261105100000_core_tables.sql`        | All tables from `docs/data-model.md`, plus the single row `settings` table                   |
| `migrations/20261105110000_functions_triggers.sql` | RLS helper functions (schema `private`), `updated_at`, guards, lost alert defaults           |
| `migrations/20261105120000_rls.sql`                | Row Level Security policies, column grants and the `public_profiles` view                    |
| `migrations/20261105130000_storage_realtime.sql`   | Storage buckets and policies, realtime publication                                           |
| `migrations/20261105140000_admin_console.sql`      | Staff read views (`admin_*_v`) and audited write functions (`admin_*`) for the admin console |
| `migrations/20261105150000_waitlist.sql`           | Public waitlist table for the landing page                                                   |
| `seed.sql`                                         | Sample data from the designs (Tolu, Bingo, Mimi and the three partners). Local dev only      |
| `tests/rls.test.sql`                               | Plain SQL tests for the privacy and business rules                                           |
| `tests/admin.test.sql`                             | Tests for the admin functions: roles, state changes, audit trail, invites                    |

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

## Admin console access

- Staff read through views with `security_invoker`, so each role sees only what RLS allows it.
- Staff write only through `admin_*` functions. Each checks the role, changes the data and writes `audit_log`.
  The web app uses the signed in user's session and never needs the service role key.
- Reviewer notes live in `partner_reviews` (staff only), not on `partner_accounts`, because partner owners can read their own row.
- Suspending a user sets `auth.users.banned_until`, flags the profile, suspends their partner accounts and removes live listings.

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
