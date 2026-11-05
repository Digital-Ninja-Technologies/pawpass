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
