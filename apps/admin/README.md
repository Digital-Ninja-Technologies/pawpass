# apps/admin

The PawPass ops console (Next.js App Router, TypeScript). Staff sign in with a work email and password; there is no
public sign up. Every page reads through Supabase row level security as the signed in staff member, and every change
goes through an `admin_*` database function that checks the staff role again and writes to `audit_log`.

| Section          | Route            | What it does                                                                      |
| ---------------- | ---------------- | --------------------------------------------------------------------------------- |
| Overview         | `/`              | Counts that need attention                                                        |
| Verifications    | `/verifications` | Partner applications: documents, payout account, checklist, decision with a note  |
| Escrow & payouts | `/payouts`       | Money held, ready, paused, paid; export                                           |
| Payout run       | `/payouts/run`   | Review the weekly draft, approve it. Sending is done by the `payout-run` function |
| Disputes         | `/disputes`      | Decide within 72 hours: refund, release or (bookings only) split                  |
| Reports          | `/reports`       | Moderation queue                                                                  |
| Lost & found     | `/lost-found`    | Alerts and sightings; widen a search                                              |
| Users            | `/users`         | Directory, suspend or restore                                                     |
| Support          | `/support`       | Tickets; internal notes are never shown to the user                               |
| Settings         | `/settings`      | Fees and windows, team and roles, invites, audit log                              |

Roles: `full_admin`, `payouts_disputes`, `support_reports`, `verifications`, `read_only` (see `lib/roles.ts`).

## Payouts, end to end

1. The `payout-run` edge function (scheduled hourly) keeps a **draft** run for the next payout day up to date.
2. Staff open **Payout run**, check who is paid and who is held (no payout account), and **approve**.
3. On the run day the same function claims the items. The database first moves each partner's escrow rows to
   `released` (so a dispute can no longer pause them), then the function asks Paystack for the transfers. Failed
   transfers are retried up to three times with the same reference, so a partner is never paid twice.
4. Partners get a notification when their payout is sent. A transfer Paystack later reports as failed shows as
   **Failed** here with the reason, for staff to handle by hand.

## Develop

```bash
pnpm --filter @pawpass/admin dev        # needs apps/admin/.env.local, see .env.example
pnpm --filter @pawpass/admin test
pnpm --filter @pawpass/admin typecheck
pnpm --filter @pawpass/admin lint
```
