# apps/mobile

PawPass mobile app for owners and partners, built with Flutter (Dart).

```bash
cp .env.example .env.local
flutter pub get
flutter run --dart-define-from-file=.env.local
flutter analyze && flutter test
```

Design tokens live in `lib/theme/tokens.dart` and mirror `packages/shared/src/tokens.ts`.

## Design system

Import everything from `package:pawpass/ui/ui.dart`.

| Component                         | Notes                                                                                |
| --------------------------------- | ------------------------------------------------------------------------------------ |
| `PawButton`                       | primary, secondary, warm (lost pet only), danger; disabled when `onPressed` is null  |
| `PawChip`                         | 40 tall (filters) or 48 (`PawChipSize.large`, species picker); 44 point tap area     |
| `PawBadge`                        | verified, upcoming, lost, danger, neutral; status is always in the text              |
| `PawSegmented`                    | tab like control on a subtle track                                                   |
| `PawTextField`                    | label above, 52 tall, 2px primary focus, danger border and message on error          |
| `PawToggleRow`                    | bordered row with a checkbox; the whole row toggles                                  |
| `PawCard`, `PawListRow`           | surface cards (radius 18 to 24) and 52 tall settings rows                            |
| `PawBackButton`, `PawStepProgress`| 44 circle back button; onboarding progress ("Step 5 of 6")                           |
| `PawStickyFooter`, `PawTabBar`    | pinned action bar; the five tab owner bar (80 tall plus the home indicator inset)    |
| `PawIcon`                         | the 24px, 1.8 stroke line icons from the designs                                     |

Tokens are in `lib/theme/tokens.dart` (colour, spacing, radius, sizes) and
`lib/theme/typography.dart` (type scale). Fonts are bundled in `assets/fonts`, so nothing is fetched at runtime.

Run the app and open the component gallery at `/gallery` (linked from the home screen in debug builds).

Widget tests load the real fonts (`test/flutter_test_config.dart`) so layout is measured with true text widths.
`test/theme/contrast_test.dart` checks every text and background pair against WCAG AA (4.5:1).

## Onboarding (milestone 1)

Welcome, email, 6 digit code, account type, profile, first pet, health history, reminders and "passport ready"
(`lib/features/onboarding`). Sign in is an email one time code through Supabase Auth: no passwords.

```
lib/features/onboarding/
  domain/   pure Dart: models, the reminder schedule rules, age and phone helpers (unit tested)
  data/     repositories: Supabase versions, device services (photos, mail app) and in memory stand ins
  state/    SessionController (who is signed in, finished or not) and OnboardingController (the draft)
  ui/       the nine screens and the shared page frame
lib/router.dart   go_router with the sign in and "resume where you left off" rules
```

How it behaves:

- **Nothing about the pet is saved until the last step** ("Turn on reminders"). Then one database call
  (`create_pet_passport`) creates the pet, its tag code, its records and their reminders together, or nothing.
  Account type and profile details save as the person goes, so coming back later resumes at "account type".
- **Reminder dates** come from `domain/reminder_schedule.dart` (yearly vaccines, deworming every 3 months, tick and
  flea monthly). These are sensible defaults to review with a vet, not veterinary advice.
- The reminders themselves are only *stored* for now. Sending them (push, WhatsApp, email) is milestone 2.
- Signing out clears everything typed so far.

Run it:

```bash
# With the real project (see .env.example):
flutter run --dart-define-from-file=.env.local

# With no Supabase project, a debug build runs on in memory stand ins with a DEMO corner.
# The sign in code is 123456 and nothing is sent or saved.
flutter run
```

Left out on purpose, until what they need exists:

| Left out | Why | Comes with |
| --- | --- | --- |
| Google and Apple sign in | Needs provider setup in Supabase and both stores. Build with `--dart-define=SOCIAL_SIGN_IN=true` to see the buttons | When the providers are set up |
| "Scan vaccine card" | Needs a text recognition service to read the dates | Milestone 2 (Add record) |
| "Use my current location" | Needs a geocoding key to turn a position into an area name | Milestone 4 (maps) |
| "Order" a QR collar tag | Needs payment. Shown as "Coming soon" | Milestone 3 (Paystack) |
| Links on "Terms" and "Privacy Policy" | The pages do not exist yet. Shown as plain text | When the pages are published |

Photos use the official `image_picker`; the mail app button uses `url_launcher` (iPhone) and `android_intent_plus` (Android).
