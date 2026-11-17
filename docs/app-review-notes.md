# App Store review notes

Paste the text between the lines into the **Notes** field of App Review Information in App Store Connect (the field takes
4,000 characters). Fill in the two bracketed login lines first. Also attach the screen recording described below.

Before resubmitting, read "Things to fix first" at the bottom.

-----

OurPawPass is a free app for pet owners in Lagos, Nigeria. Every pet gets one Pet Passport (identity, vaccine and treatment records, origin) so owners can keep health on track, find trusted pet services, and report or find lost pets. Audience: adults (18+) who own or look after a dog or cat. It solves lost paper vaccine cards, hard to find trusted vets and groomers, and unsafe puppy sales.

HOW TO SIGN IN
The app normally signs in with a 6 digit emailed code. For review, use the demo account:
Email: [DEMO EMAIL]
Password: [DEMO PASSWORD]
Tap "Sign in with a password" on the email screen. The account is already set up with two pets (Bingo, Mimi) and records.
[PARTNER DEMO: if a partner account is supplied, add it here: email, password, and "Me > Switch to partner mode".]

MAIN FEATURES
1. Home and Passport: pets, vaccine and treatment records, reminders (Passport tab).
2. Share with a vet: Passport > share icon makes a time limited link and QR code.
3. Emergency vets: sorted by distance. Location is optional, approximate, and only used if allowed.
4. Services: browse and book vets, groomers, trainers and boarding. Payment is held until the owner confirms the visit.
5. Community: posts, comments, messages. Every post and person has Report and Block. Staff moderate reports.
6. Lost pet alerts: report a lost pet, notify people nearby; finders use in app chat and never see the owner's phone number.
7. Adopt: listings from verified breeders and shelters.
8. Courses: puppy and dog guides with progress.
9. Account deletion: Me > Privacy and sharing > Delete my account, then type DELETE. A web page also exists: ourpawpass.com/delete-account.
Payments open Paystack's secure page. You can review every screen without paying; stop at the Paystack page.

EXTERNAL SERVICES
Supabase (sign in, database, file storage, realtime). Paystack (payments for services, puppy deposits, QR collar tags; partner payouts). Firebase Cloud Messaging (push notifications). Resend (reminder emails). Device camera, photo library and approximate location (all optional). No AI services. No advertising or tracking SDKs.

REGIONS
Built for Nigeria. Prices are in naira and payments use Paystack (cards, bank transfer, USSD). Partner listings are in Lagos. The app works the same in every region, but services and listings outside Lagos are limited today.

REGULATION
Not a regulated service. Pet health records are kept by owners. A "Vet verified" badge appears only on records added by a vet we have verified: partners upload identity and business documents and our staff approve them before they go live. The app gives no veterinary advice, and course lessons say so.

## The screen recording (you record this on a real iPhone)

Apple wants it captured on a physical device on the latest iOS, starting from launching the app. Record one take of about
3 to 4 minutes, in this order:
1. Launch the app, sign in (show the "Sign in with a password" route for the demo account).
2. Passport: open a pet, show records and a reminder, then the share with vet screen.
3. Emergency vets (allow location when asked).
4. Services: open a provider and start a booking, stopping at the Paystack page.
5. Community: open a post, tap Report, then Block a person.
6. A paid course if the paid course is still shown (see below), up to the Paystack page.
7. Delete the account: Me, Privacy and sharing, Delete my account, type DELETE, confirm. Use a throwaway account for
   this take, not the demo account.

## Things to fix first

1. **Demo login.** The sign in screen has no password route today, and the demo account (appreview@ourpawpass.com) cannot
   receive an emailed code. Apple will reject the build again without a working login. The password sign in screen must be
   rebuilt and shipped in the build you submit.
2. **Paid courses break Guideline 3.1.1.** Courses are digital content unlocked inside the app, and they are paid with
   Paystack. Apple requires In-App Purchase for that. Safest fix for iOS: hide paid courses on iPhone (show the free
   courses only). Services, puppy deposits and QR collar tags are real world goods and services, so Paystack is fine
   for those.
3. **The marketplace is empty.** The sample partners and listings were removed from the live database. Reviewers will see no
   vets, groomers or listings under Services and Adopt, which looks like an unfinished app. Add a few approved partners and
   listings before resubmitting.
4. **Account types.** If you supply a partner demo account, it needs an approved partner profile with at least one service.
5. **Screenshots** must show the app in use, not only the sign in or splash screen.
