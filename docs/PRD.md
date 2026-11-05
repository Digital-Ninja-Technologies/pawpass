# PawPass PRD (Phase 1)

Working name: PawPass. Owner: Digital Ninja Technologies. Launch market: Lagos, Nigeria. Platforms: iOS and Android app, plus a web admin console. Payments in NGN. The living version of this PRD is the "Pet App PRD" doc; this file is the build copy.

## Problem

Lagos pet owners keep records on paper vaccine cards and in WhatsApp chats, struggle to find trusted vets after hours, and risk scams when buying puppies from online sellers. Lost pets are found through flyers and broadcasts. No local app combines health, trusted services and safe pet sales.

## Users

| Persona | Needs |
| --- | --- |
| Pet parent (Tolu, Lekki, a dog and a cat) | Reminders, a trusted vet and groomer, a nice pet profile |
| Guard dog owner (Chidi, Ikeja, two Boerboels) | Quick vet access, training, buying a healthy pup |
| First time buyer | Verified breeder, health proof, safe payment |
| Vet clinic, groomer, trainer, boarding | Bookings, patient history, payouts |
| Breeder | Credibility, listings, safe payment |
| Shelter or rescue | Reach adopters, screen applications |
| PawPass ops team | Verify partners, settle disputes, moderate, pay out, support users |

## Phase 1 scope: all four pillars

### Accounts and onboarding
- Sign up with email and a 6 digit code (no password); Google or Apple optional.
- Account type: owner, provider, breeder, shelter (more than one allowed).
- Profile: name, area, optional phone for WhatsApp or SMS reminders.
- Add first pet; add past vaccines by scanning the card or ticking common vaccines; set reminders.

### Health
- Pet Passport: identity, QR tag ID, origin, vaccines, treatments, vet visits, weight, documents.
- Add record; suggested schedules by species and age; reminders by push, email and WhatsApp.
- Share with a vet by time-limited link or QR, with control over what is shared.
- Vet-verified records. Emergency vets open now.

### Services marketplace
- Categories at launch: vet clinic, groomer, trainer, boarding.
- Provider profile, services and prices, date and time slots, pay in app (held in escrow).
- Booking confirmed, my bookings (upcoming, needs action, completed), reschedule, cancel.
- Confirm the visit to release payment; rate and review; report a problem to open a dispute.

### Community
- Feed, new post, public pet profile, follow.
- Lost & found: report lost, alert people nearby, finder view, sightings, in-app chat, QR tag lost mode.
- Report a post, profile or listing; block an account.

### Trust
- Verified breeder and shelter listings with passports.
- Escrow deposit (one third), handover, 72 hour vet check, balance release, passport transfer.
- Shelter adoption applications.

### Partners
- Become a partner, choose type, business verification (KYC), verification status with "more info needed".
- Dashboards: provider (today's visits), breeder (listings, enquiries), shelter (applications).
- Earnings: next payout, held amounts, history. Switch between owner and partner mode.

### Help
- Help topics, contact support, view replies.

### Admin web app
- Sign in for staff; invite team members with roles; accept invite.
- Overview: key numbers and work queues.
- Verifications queue with documents and checks; approve, ask for more info, reject.
- Disputes with both statements, timeline, policy match and decision.
- Reports and moderation; lost & found and QR tag orders.
- Escrow and payouts; users and partners directory; support inbox.
- Settings: fees, policies, payout day, team and roles, audit log.

## Release plan

1. Phase 1 launch (all of the above), about 20 to 24 weeks with a small team, after a 4 week closed beta in Lekki, VI and Ikeja with 50 to 80 founding providers and 15 to 20 breeders and shelters.
2. Phase 2: household sharing, passport PDF export, local groups, mobile vets, sitters and walkers, subscriptions.
3. Phase 3: teleconsults, symptom checker, breeder trust score, rehoming, recurring bookings, pet commerce, new cities.

## Success metrics (12 months)

20,000 pets with at least one record; 40% monthly active owners; 60% of reminders acted on within 7 days; 3,000 completed bookings a month; 300 verified providers; 50 verified breeders and shelters; 35% of lost pet reports resolved as found.

## Non functional

Cold start under 3 s on a mid range Android; passport and reminders readable offline; app under 40 MB; NDPA 2023 compliance; encryption in transit and at rest; 99.5% uptime; WCAG 2.1 AA.

## Open questions

Final product name; market size validation; escrow licensing (hold funds directly or through a licensed partner); species at launch; KYC and moderation staffing; QR tag supplier.
