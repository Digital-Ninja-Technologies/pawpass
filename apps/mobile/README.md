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
