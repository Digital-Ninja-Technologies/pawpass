# PawPass · project brief for Claude Code

PawPass is a mobile app for pet owners in Lagos, Nigeria, plus a web admin console for the PawPass ops team. It is a DNT (Digital Ninja Technologies) product. Every pet gets one **Pet Passport**: identity, health records, origin and ownership history. Four pillars ship together in Phase 1:

1. **Health**: passport, vaccine and treatment records, reminders, share with vet, emergency vets.
2. **Services marketplace**: book vets, groomers, trainers and boarding; payment held in escrow until the owner confirms.
3. **Community**: pet profiles, feed, lost & found alerts with QR collar tags, in-app chat.
4. **Trust**: verified breeders and shelters, puppy sales through escrow, passport ownership transfer, adoption applications.

Full product requirements: `docs/PRD.md`. Data model: `docs/data-model.md`. Build order and ready-made prompts: `docs/build-plan.md`.

## Repository layout

```
apps/mobile     Flutter (Dart) app for owners and partners
apps/admin      Next.js (App Router, TypeScript) admin web app
supabase        migrations, seed data, RLS policies, edge functions
design          source designs exported from the PawPass canvas (read only)
docs            PRD, data model, build plan
```

Use one package manager across the repo (pnpm workspaces). pnpm covers the TypeScript side (`apps/admin`, `packages/shared`); the Flutter app uses `pub` and sits outside the pnpm workspace. Types and design tokens cannot be shared across Dart and TypeScript, so the Flutter tokens in `apps/mobile/lib/theme/tokens.dart` mirror `packages/shared/src/tokens.ts`; keep the two in step.

## Stack

| Layer         | Choice                                                                                                                                |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Mobile        | Flutter (stable), Dart, go_router, supabase_flutter                                                                                   |
| Admin web     | Next.js App Router, TypeScript, server components where possible                                                                      |
| Backend       | Supabase: Postgres, Auth, Storage, Realtime, Edge Functions                                                                           |
| Auth          | Email one-time code (6 digits, no password) for app users; Google/Apple optional. Admin staff use work email + password, invite only  |
| Payments      | Paystack (card, bank transfer, USSD). Funds are held by PawPass and released by a payout run; never pay partners directly at checkout |
| Notifications | Firebase Cloud Messaging push; WhatsApp and email reminders through a provider called from an edge function                           |
| Maps          | Google Maps (google_maps_flutter)                                                                                                     |

Confirm any new dependency is actively maintained before adding it. Do not add a UI kit; build components from the design tokens below.

## Designs: how to read `design/`

`design/screens/*.dc.html` are the source designs, one file per screen. They are HTML with **inline styles**, so every size, colour, radius and spacing value is exact and can be copied. Open them in a browser for a rough preview (the canvas runtime is not included, so `{{...}}` placeholders will show as text).

- `{{accent}}` means the primary colour `#0E6B63`.
- `<dc-import name="TabBar" active="home">` mounts `TabBar.dc.html` (the owner bottom tab bar). `AdminNav.dc.html` is the admin sidebar, `active` picks the highlighted item.
- `<a href="X.dc.html">` links show the navigation: that element opens screen X.
- Photos live in `design/assets/`. They are placeholder stock photos; in the app they are user uploads.
- Names, prices and numbers in the designs are sample data.
- `design/README.md` lists every screen by flow, and `design/screens/NavMap.dc.html` is the navigation map. `Specs.dc.html` documents tokens and components.

Match the designs closely. When a design and this file disagree, follow this file and flag it.

## Design tokens

Colours: ground `#FFF8F1`, surface `#FFFFFF`, ink `#1F1A17`, ink2 `#4A433E`, muted `#6B625B`, border `#EDE3D9`, subtle `#F3EBE2`, primary `#0E6B63`, primarySoft `#E3F1EE`, primaryText `#0B5650`, warm `#B4501C` (lost pet actions), warmSoft `#FFEBD9`, warmText `#9A3F0F`, danger `#A3261B`, dangerSoft `#FDEAE7`, dot `#E0662A` (unread dots, stars, decoration only). Pet tints for photo fallbacks: `#F3D9C4`, `#DCE7F7`, `#F1E8FB`, `#CFE6E1`.

Type: headings Bricolage Grotesque 700 (36, 30, 28, 22); body Plus Jakarta Sans (16 and 15 buttons at 700; 15 and 14 body at 500 to 600; 13 and 12 meta; overline 12 at 700 with 4% tracking).

Layout: mobile base frame 390 × 844; side padding 20 (onboarding 24); touch targets at least 44; primary buttons 52 to 54 tall, pill shaped; inputs radius 16; cards radius 18 to 24; bottom tab bar 80 tall. Icons are 24px line icons, 1.8 stroke, round caps (the lucide_icons_flutter package fits).

Accessibility: text contrast WCAG AA, real buttons and labels, screen reader labels on icon buttons, never colour alone for status.

## Business rules (from admin Settings; make them configurable, not hard coded)

- Booking commission 12%. Puppy sale escrow fee 5%. Puppy deposit is one third of the price.
- Service payments are held until the owner confirms the visit. Free cancellation up to 2 hours before.
- Puppy sales: deposit and balance are held; a 72-hour vet check window follows handover. A vet-verified health problem found in that window qualifies for a full refund.
- Disputes pause the related payout until an admin decides: full refund, split, or release.
- Partner verification target is 48 hours. Partners (vet, groomer/trainer/boarding, breeder, shelter) cannot go live until approved. Admin can approve, ask for more info, or reject.
- Payout run every Monday.
- Lost pet alerts notify people within a radius (default 5 km), auto-close after 14 days, and never reveal the owner's phone number; finders use in-app chat.
- Health records are private by default. Sharing with a vet uses a time-limited link or QR code. Records added by a verified vet get a "Vet verified" badge.
- Passport ownership transfers to the buyer or adopter on handover; the previous owner keeps a read-only record.
- Admin roles: Full admin, Payouts & disputes, Support & reports, Verifications, Read only. Every admin action is written to an audit log.

## Copy rules

- Plain, friendly British English spelling (Nigeria). Currency is naira, shown as `₦15,000`.
- No em dashes in user-facing copy. Avoid hyphens in UI text where a plain phrase works ("6 digit code", "72 hour check").
- Never show full phone numbers, card numbers or government ID numbers in the UI. Card and bank accounts show the last four digits only.

## Working agreements

- Build one flow at a time, in the order in `docs/build-plan.md`. Each flow is done when it matches its design files, works on iOS and Android, and has tests for its business logic.
- Keep secrets in `.env.local` files (never committed). Provide `.env.example` files.
- Row Level Security on every Supabase table. Owners see their own data; partners see only data shared with them; admins act through server-side functions that write the audit log.
- Commit small, descriptive commits. Run lint, type check and tests before each commit.
