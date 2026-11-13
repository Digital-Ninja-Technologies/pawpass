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

## Courses

The **Courses** page manages the puppy and dog courses shown in the app (Home, then Courses).

- **Who:** full admins create, edit, publish and delete courses. Read only staff can look. Everyone else does not see the page.
- **A course** has a title, a short description, who it is for (puppies, dogs, both), a level, an order, a colour and an
  illustration. A cover picture is optional (JPG, PNG or WebP, up to 5 MB) and replaces the illustration.
- **Lessons** are written in the form: add, edit, move up or down and remove. Leave a blank line between paragraphs, start a
  line with `- ` for a bullet and a paragraph with `Tip: ` for a tip card. Editing a lesson keeps its id, so people keep
  their progress; removing a lesson removes the ticks on it.
- **Free or paid:** a course is free (everyone with the app reads it all) or paid. A paid course has a price from ₦100 to
  ₦1,000,000. People pay once on Paystack and keep the course (no subscription). Until they pay, its lessons stay locked,
  and the database itself holds the text back, so it cannot be read by asking for it. Tick **Free preview** on any lesson to
  let everyone read it first. Changing the price never changes what someone already paid, and a payment that is already
  open keeps the price it started with.
- **Sales:** the list shows each paid course's buyers and what they paid, and the page header shows total course sales.
  Purchases are payment records: a course that people have paid for **cannot be deleted** (unpublish it instead), and
  making a paid course free opens it to everyone while keeping the payments on record.
- **Draft or published:** drafts are hidden from the app. Publishing needs at least one lesson and takes effect at once.
  Unpublish takes a course out without deleting it. Delete removes the course, its lessons, everyone's progress and its cover.
- **Every change is written to the audit log** (`course.create`, `course.update`, `course.publish`, `course.unpublish`,
  `course.delete`), and price changes record the old and new price.
- **Illustrations** come from `tools/make_course_art.py`, which writes the same files to the app and to
  `apps/admin/public/course-art`. To add one, add it to the script, to the `art` check in
  `supabase/migrations/20261118100000_courses.sql` (a new migration) and to `ART` in `lib/courses.ts`, then run the script.

## Develop

```bash
pnpm --filter @pawpass/admin dev        # needs apps/admin/.env.local, see .env.example
pnpm --filter @pawpass/admin test
pnpm --filter @pawpass/admin typecheck
pnpm --filter @pawpass/admin lint
```
