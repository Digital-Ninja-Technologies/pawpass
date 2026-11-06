# Build plan for Claude Code

Work through these milestones in order. Start each one in a fresh Claude Code session with the prompt shown, review the result on a device, then commit. Every milestone ends with lint, type check and tests passing.

## 0. Foundations

> Read CLAUDE.md, docs/PRD.md and docs/data-model.md. Set up a pnpm workspace with apps/mobile (Flutter, Dart, go_router), apps/admin (Next.js App Router, TypeScript) and packages/shared (TypeScript types, design tokens, Supabase client for the admin app). Add ESLint, Prettier, Vitest/Jest and a GitHub Actions workflow that runs lint, type check and tests. Add .env.example files. Do not build screens yet.

> Create the Supabase schema from docs/data-model.md as migrations in supabase/migrations, with Row Level Security policies for owners, partners and staff, and a seed file using the sample data from the designs (Tolu, Bingo, Mimi, Paws & Claws Vet Clinic, Royal Paws Kennels, Lagos Paws Rescue).

> Build the mobile design system from CLAUDE.md tokens and design/screens/Specs.dc.html: colours, typography, Button (primary, secondary, warm, danger, disabled), Chip, Badge, Segmented control, TextField, ToggleRow, Card, ListRow, BackButton, StepProgress, StickyFooter, and the bottom TabBar from design/screens/TabBar.dc.html. Add a component gallery screen for review.

## 1. Onboarding and auth

> Build the onboarding flow to match design/screens Welcome, SignUp, Verify, AccountType, ProfileSetup, AddPet, PetHealth, Reminders and AllSet. Use Supabase email one-time codes. Creating the first pet creates its passport and reminder schedule.

## 2. Health

> Build Home (Main), Passport, AddRecord, Schedule, ShareVet, Emergency and Notifications. Reminders are generated from health records; ShareVet creates a time-limited passport_shares token and QR code.

## 3. Services and escrow

> Integrate Paystack. Build Services, Provider, Booked, Bookings, Review and OpenDispute. Payments create escrow_transactions with status held; confirming a visit sets ready; opening a dispute sets paused. Write the escrow state machine as a tested module.

## 4. Community, lost & found, chat

> Build Community, CreatePost, PetProfile, ReportContent, LostPet, LostAlert and Chat with Supabase Realtime. Lost alerts notify users inside the radius through an edge function and never expose phone numbers.

## 5. Trust: breeders, shelters, transfer

> Build Adopt, Listing, Checkout, Transfer and AdoptApply. Handover triggers the 72 hour vet check window and the ownership transfer of the passport.

## 6. Partner mode

> Build Profile (Me), BecomePartner, KYC, PartnerReview, ProviderDash, BreederDash, ShelterDash, BreederListing, PartnerEarnings and HelpSupport, plus the Home partner bar for approved partners and the owner/partner mode switch.

## 7. Admin web app

> Build apps/admin to match design/screens Admin*.dc.html with the AdminNav sidebar: AdminLogin, AdminInvite, AdminAcceptInvite, AdminOverview, AdminKYC, AdminDisputes, AdminModeration, AdminLostFound, AdminPayouts, AdminUsers, AdminSupport and AdminSettings. Enforce staff roles server side and write every action to audit_log. The weekly payout run is a scheduled edge function that admins review before it sends.

## 8. Launch readiness

> Add empty, loading and error states to every screen, offline caching for the passport and reminders, analytics events for the PRD success metrics, and app store assets. Run an accessibility pass against WCAG 2.1 AA.

## Known gaps in the designs

Designed and listed in `design/README.md` under "Added later": QR tag ordering, privacy and sharing settings, help articles, partner calendar, shelter applications list, full audit log, and empty and error states. They are designs only; none is built yet. Build them as a follow up to milestone 8, and wire the entry points listed in that README.
