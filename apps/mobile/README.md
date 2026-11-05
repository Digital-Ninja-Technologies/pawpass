# apps/mobile

PawPass mobile app for owners and partners, built with Flutter (Dart).

```bash
cp .env.example .env.local
flutter pub get
flutter run --dart-define-from-file=.env.local
flutter analyze && flutter test
```

Design tokens live in `lib/theme/tokens.dart` and mirror `packages/shared/src/tokens.ts`.
