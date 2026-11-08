# Deployment

Two Vercel projects in the team "Ifeoluwa's projects", both linked to this repository (monorepo, pnpm):

| Project         | Root directory | What                                           | Vercel Authentication            |
| --------------- | -------------- | ---------------------------------------------- | -------------------------------- |
| `pawpass-web`   | `apps/web`     | Public landing site                            | Off (public site)                |
| `pawpass-admin` | `apps/admin`   | Ops console, staff sign in through Supabase    | On (extra gate; see below)       |

Both use the Next.js preset, Node 22, and "include source files outside the root directory" (the apps import
`packages/shared`).

## Environment

Only public values are needed, and they are committed in `apps/*/.env.production`. `apps/admin` needs:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` (the Supabase **publishable** key, designed for browsers; RLS protects the data)

`apps/web` needs no Supabase values. It uses `NEXT_PUBLIC_AGENCY_URL` (footer link) and, when the app is live, `NEXT_PUBLIC_APP_STORE_URL` and `NEXT_PUBLIC_PLAY_STORE_URL`.

Optional, set in the Vercel dashboard (Settings, Environment Variables):

- `apps/admin`: `STAFF_EMAIL_DOMAIN` (for example `pawpass.ng`) limits which email domains can be invited.
- `apps/web`: `NEXT_PUBLIC_SITE_URL` (the public address, used for sharing cards and the sitemap).

Never put a service role key or any other secret in a committed file. The apps do not use one.

## Releasing

Vercel deploys on every push. Production builds come from the production branch (`main`). Until the work on
`claude/brave-fermi-6cy2xl` is merged into `main`, production was deployed from that branch directly:

1. Merge the branch into `main`. After that, every push to `main` deploys production and every other branch gets a preview.
2. Add custom domains to each project (Settings, Domains), for example `pawpass.ng` for web and `admin.pawpass.ng` for admin.
3. Then set `NEXT_PUBLIC_SITE_URL` for web and redeploy.

## Admin access

`pawpass-admin` still has Vercel Authentication on, so only people in the Vercel team can open it. Turn it off
(Settings, Deployment Protection) when staff outside the team need access. The console has its own sign in and
is marked `noindex`, but the extra gate is a sensible default until MFA is added.

## Database

Migrations are applied with the Supabase MCP tools or `supabase db push`; see `supabase/README.md`.

## Payments (Paystack)

Four edge functions in `supabase/functions/` handle money. Paystack's secret key only ever exists in the
Supabase project's function secrets; the app never sees it.

| Function            | Who calls it                | What it does                                                                                                   |
| ------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `paystack-initialize` | The app (signed in owner) | Reads the booking's amount from the database and asks Paystack for a checkout page                             |
| `paystack-verify`   | The app, after paying       | Asks Paystack whether the exact amount arrived, then records it with `confirm_booking_payment`                 |
| `paystack-webhook`  | Paystack                    | Checks the HMAC SHA512 signature, then records `charge.success` the same way (safe if both run)               |
| `process-refunds`   | A schedule (service role)   | Sends queued refunds to Paystack, and makes visits the owner never confirmed ready for payout                  |
| `delete-account`    | The app (signed in person)  | Not about money: erases a person's data through `erase_account`, removes their files, then soft deletes the sign in. Refuses while a payment or handover is unfinished. Deploy with JWT verification off |

Setup, once the `20261106200000_services_escrow` migration is applied:

1. Supabase dashboard, Edge Functions, Secrets: add `PAYSTACK_SECRET_KEY` (use the **test** key first).
2. Deploy all four functions with JWT verification **off** (each one checks who is calling itself).
3. Paystack dashboard, Settings, API Keys and Webhooks: set the webhook URL to
   `https://<project-ref>.supabase.co/functions/v1/paystack-webhook`.
4. Schedule `process-refunds` every 5 minutes (Supabase Cron, an HTTP `POST` with the service role key).
5. Pay a test booking with a Paystack test card, then check the booking is `confirmed` and an
   `escrow_transactions` row is `held`.

Money rules enforced in code: the amount always comes from the booking row; a payment only counts when
Paystack says `success`, in `NGN`, for exactly that amount; the same payment can be reported any number of times
and is recorded once; a payment for a time that was taken meanwhile is refunded in full.
Puppy deposits (`pd_`) and balances (`pb_`) go through the same functions as bookings (`pp_`).
The scheduled `process-refunds` run also releases puppy sales whose 72 hour vet check window ended with no problem.
Tests: `pnpm --filter @pawpass/edge-functions test`.

### Weekly payouts

A fifth function, `payout-run`, sends partners their money. Deploy it with JWT verification **off** (it only accepts the
service role key, like `process-refunds`) and schedule it **every hour** with an HTTP `POST` and that key.

- It keeps a draft run for the next payout day (`settings.payout_weekday`) up to date. Staff review and approve it in the
  admin console under Escrow & payouts, Payout run. Nothing is sent from a draft.
- Once a run is approved and its day has come, it releases each partner's escrow rows and asks Paystack for the transfers.
  Partners with no payout account are held, and paid in a later run once they add one.
- Transfers use Paystack **balance**, so keep enough in it, and turn **transfer OTP off** in the Paystack settings
  (a transfer that asks for an OTP is recorded as failed). Add `transfer.failed` and `transfer.reversed` to the events
  sent to the webhook so a bounced transfer shows up as Failed in the console.
- A failed transfer is retried up to three times with the same reference, so it can never be paid twice. After that the
  money has already left escrow: pay it by hand from the Paystack dashboard.

## Partner mode

Becoming a partner needs no setup beyond the `20261109100000_partner_mode` migration. Things worth knowing:

- Verification documents go to the private `partner-documents` bucket, inside the applicant's own folder; only the
  applicant and the PawPass verifications team can read them.
- The payout account (`partner_payout_accounts`) is readable by its owner and by payouts or verifications staff. The app
  only ever gets the bank name and last four digits back. Nobody writes it directly: `partner_save_payout_account` checks
  the shape (10 digit account number, bank code) first. Changing it after approval goes through support for now.
- A partner can submit only when every step is done (`submit_partner_for_review`). The team's decision (approved, needs
  more info, rejected) reaches the partner as a notification.
- Not designed yet, so shown as "coming soon": the vet and service Calendar tab, QR tags, and privacy and sharing.
  Vets still cannot open a shared passport or add a verified record from the dashboard; that stays on the share link.
