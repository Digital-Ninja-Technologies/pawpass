# Designs

Exported from the PawPass design canvas. One file per screen in `screens/`, photos in `assets/`. See CLAUDE.md for how to read them. Mobile screens are 390 × 844.

## Onboarding

| File | Screen |
| --- | --- |
| `screens/Welcome.dc.html` | Welcome |
| `screens/SignUp.dc.html` | Sign up with email |
| `screens/Verify.dc.html` | 6 digit email code |
| `screens/AccountType.dc.html` | Account type |
| `screens/ProfileSetup.dc.html` | Your profile |
| `screens/AddPet.dc.html` | Add first pet |
| `screens/PetHealth.dc.html` | Health history |
| `screens/Reminders.dc.html` | Reminders |
| `screens/AllSet.dc.html` | Passport ready |

## Health

| File | Screen |
| --- | --- |
| `screens/Main.dc.html` | Home (tab 1) |
| `screens/Passport.dc.html` | Pet Passport (tab 2) |
| `screens/AddRecord.dc.html` | Add health record |
| `screens/Schedule.dc.html` | Reminders and schedule |
| `screens/ShareVet.dc.html` | Share with vet |
| `screens/Emergency.dc.html` | Emergency vets |
| `screens/Notifications.dc.html` | Notifications |

## Services

| File | Screen |
| --- | --- |
| `screens/Services.dc.html` | Book care (tab 3) |
| `screens/Provider.dc.html` | Provider and booking |
| `screens/Booked.dc.html` | Booking confirmed |
| `screens/Bookings.dc.html` | My bookings |
| `screens/Review.dc.html` | Rate and review |
| `screens/OpenDispute.dc.html` | Report a problem (dispute) |

## Community

| File | Screen |
| --- | --- |
| `screens/Community.dc.html` | Feed (tab 4) |
| `screens/CreatePost.dc.html` | New post |
| `screens/PetProfile.dc.html` | Public pet profile |
| `screens/ReportContent.dc.html` | Report a post, profile or listing |
| `screens/LostPet.dc.html` | Report lost pet |
| `screens/LostAlert.dc.html` | Lost alert, finder view |
| `screens/Chat.dc.html` | In-app chat |

## Trust

| File | Screen |
| --- | --- |
| `screens/Adopt.dc.html` | Find a pet (tab 5) |
| `screens/Listing.dc.html` | Verified puppy listing |
| `screens/Checkout.dc.html` | Escrow deposit |
| `screens/Transfer.dc.html` | Passport transfer and escrow |
| `screens/AdoptApply.dc.html` | Shelter adoption application |

## Account and partners

| File | Screen |
| --- | --- |
| `screens/Profile.dc.html` | Me |
| `screens/HelpSupport.dc.html` | Help and support |
| `screens/BecomePartner.dc.html` | Become a partner |
| `screens/KYC.dc.html` | Business verification |
| `screens/PartnerReview.dc.html` | Verification status |
| `screens/ProviderDash.dc.html` | Provider dashboard |
| `screens/BreederDash.dc.html` | Breeder dashboard |
| `screens/ShelterDash.dc.html` | Shelter dashboard |
| `screens/BreederListing.dc.html` | Breeder new listing |
| `screens/PartnerEarnings.dc.html` | Partner earnings |

## Admin web app (1440 wide, responsive)

| File | Screen |
| --- | --- |
| `screens/AdminLogin.dc.html` | Staff sign in |
| `screens/AdminInvite.dc.html` | Invite team member |
| `screens/AdminAcceptInvite.dc.html` | Accept invite |
| `screens/AdminOverview.dc.html` | Overview |
| `screens/AdminKYC.dc.html` | Verifications |
| `screens/AdminDisputes.dc.html` | Disputes |
| `screens/AdminModeration.dc.html` | Reports and moderation |
| `screens/AdminLostFound.dc.html` | Lost & found and QR tag orders |
| `screens/AdminPayouts.dc.html` | Escrow and payouts |
| `screens/AdminUsers.dc.html` | Users and partners |
| `screens/AdminSupport.dc.html` | Support inbox |
| `screens/AdminSettings.dc.html` | Settings, team, audit log |

## Added later (design gaps filled)

These were missing from the first export and were drawn afterwards in the same style. All of them are now built in the app and admin, with the differences noted in the last column of the build notes below. Sample data and prices (for example the ₦3,500 tag) are placeholders. The existing screens were not edited, so wire these entry points when building:

| File | Screen | Reached from |
| --- | --- | --- |
| `screens/QrTagOrder.dc.html` | Order a QR tag | Profile, "QR tags" (`#tags`) |
| `screens/PrivacySharing.dc.html` | Privacy and sharing settings | Profile, "Privacy & sharing" (`#privacy`) |
| `screens/HelpArticles.dc.html` | Help articles, by topic | HelpSupport, search and "Popular topics" |
| `screens/HelpArticle.dc.html` | One help article | HelpArticles and HelpSupport topics |
| `screens/PartnerCalendar.dc.html` | Partner calendar (provider) | Provider dashboard tab bar, "Calendar" (`#calendar`) |
| `screens/ShelterApplications.dc.html` | Shelter applications list | Shelter dashboard tab bar, "Applications" |
| `screens/AdminAuditLog.dc.html` | Full audit log (admin, 1440 wide) | AdminSettings, "View full log" (`#audit`) |
| `screens/EmptyStates.dc.html` | Empty states reference sheet | Used by every list screen |
| `screens/ErrorStates.dc.html` | Error states reference sheet | Used app wide |

Built differently from the drawings:

- Privacy and sharing has no "who can see what" switches. Nothing in the database could honour them yet, and a switch that does nothing would be dishonest. It lists what is shared (with Stop sharing), blocked accounts, and two requests (copy of data, delete account) that go to support.
- Shelter applications have All, New, Home visit and Approved tabs. There is no In review or Declined tab, because declined applications are not loaded and there is no in review state.
- The partner calendar "Block" removes an open time (and "Block the rest of this day" removes the day's open times). Times with a booking are never removed.
- The audit log filters by area, team member and date; it does not show a role chip.

The two state files are reference sheets, not single screens: each card shows what replaces a list or page. Open questions for the team: the tag and delivery prices, whether the audit log is Full admin only (drawn that way), and whether a calendar is needed for groomer, trainer and boarding partners beyond the provider layout shown.

## Shared and reference

| File | Screen |
| --- | --- |
| `screens/TabBar.dc.html` | Owner bottom tab bar component (prop active) |
| `screens/AdminNav.dc.html` | Admin sidebar component (prop active) |
| `screens/NavMap.dc.html` | Navigation map of the mobile app |
| `screens/Specs.dc.html` | Design tokens and components |

## Landing page (app download)

`design/landing/` holds the marketing landing page design (live canvas: https://claude.ai/artifact/QTLMDYBXEsLxcYcUMs2v22).

- `Main.dc.html`: fluid page, responsive via a container query at 760px (hamburger menu below it). Sections: nav, hero with dog/cat/both pet picker, city marquee, pain-point cards, feature tabs (Health, Book care, Community, Find a pet), lost & found tag demo, 3-step setup, partner section (download the app, then Profile > Become a partner), FAQ accordion, download CTA with email form and QR, footer.
- `Mobile.dc.html`: the same page at 390px.
- Images point to `../assets/*.jpg`.
- Placeholders to replace before launch: store badges, QR code, email form backend.
- Positioning: made in Lagos, for pet owners in Lagos and beyond.
