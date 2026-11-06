import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/adopt/data/in_memory_adopt.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/community/data/in_memory_community.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/partner/data/in_memory_partner.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';

/// Today in every test, so dates in the schedule are stable.
final _today = DateTime(2026, 11, 5, 9, 0);

class _App {
  _App({String? signedInAs}) {
    profiles = InMemoryProfileRepository();
    auth = InMemoryAuthRepository(signedInAs: signedInAs);
    pets = InMemoryPetRepository(profiles: profiles, now: () => _today);
    photos = NoPhotoPicker();
    mail = NoEmailApp();
    services = AppServices(
      auth: auth,
      profiles: profiles,
      pets: pets,
      photos: photos,
      emailApp: mail,
      health: InMemoryHealthRepository(now: () => _today),
      notifications: InMemoryNotificationsRepository(),
      vets: InMemoryVetsRepository(),
      location: FakeLocationService(),
      links: FakeLinkLauncher(),
      bookings: InMemoryBookingsRepository(),
      payments: InMemoryPaymentsRepository(InMemoryBookingsRepository()),
      community: InMemoryCommunityRepository(),
      adopt: InMemoryAdoptRepository(),
      partner: InMemoryPartnerRepository(),
      now: () => _today,
    );
  }

  late final InMemoryProfileRepository profiles;
  late final InMemoryAuthRepository auth;
  late final InMemoryPetRepository pets;
  late final NoPhotoPicker photos;
  late final NoEmailApp mail;
  late final AppServices services;
}

Future<void> _pump(
  WidgetTester tester,
  _App app, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: PawPassApp(services: app.services),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _signIn(
  WidgetTester tester, {
  String email = 'tolu@example.com',
}) async {
  await _tap(tester, 'Get started');
  await tester.enterText(find.byType(TextField), email);
  await _tap(tester, 'Send code');
  await tester.enterText(find.byType(TextField), '123456');
  await tester.pumpAndSettle();
}

void main() {
  group('welcome and sign in', () {
    testWidgets('welcome offers both ways in', (tester) async {
      await _pump(tester, _App());
      expect(find.text('PawPass'), findsOneWidget);
      expect(find.text("Every pet's life,\nin one place."), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
    });

    testWidgets('an email that is not an email is refused', (tester) async {
      final app = _App();
      await _pump(tester, app);
      await _tap(tester, 'Get started');
      expect(find.text("What's your email?"), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'tolu@');
      await _tap(tester, 'Send code');
      expect(find.textContaining('Enter a valid email'), findsOneWidget);
      expect(app.auth.sentTo, isEmpty);
    });

    testWidgets(
      'the code goes to the cleaned up address and is asked for next',
      (tester) async {
        final app = _App();
        await _pump(tester, app);
        await _tap(tester, 'Get started');
        await tester.enterText(find.byType(TextField), '  Tolu@Example.com ');
        await _tap(tester, 'Send code');
        expect(app.auth.sentTo, ['tolu@example.com']);
        expect(find.text('Enter the code'), findsOneWidget);
        expect(
          find.textContaining('tolu@example.com', findRichText: true),
          findsOneWidget,
        );
      },
    );

    testWidgets('a wrong code says so and clears the boxes', (tester) async {
      final app = _App();
      await _pump(tester, app);
      await _tap(tester, 'Get started');
      await tester.enterText(find.byType(TextField), 'tolu@example.com');
      await _tap(tester, 'Send code');
      await tester.enterText(find.byType(TextField), '000000');
      await tester.pumpAndSettle();
      expect(find.textContaining('wrong or has expired'), findsOneWidget);
      expect(find.text('Enter the code'), findsOneWidget);
      expect(app.auth.signedIn, isFalse);
    });

    testWidgets('Verify with too few digits asks for all six', (tester) async {
      final app = _App();
      await _pump(tester, app);
      await _tap(tester, 'Get started');
      await tester.enterText(find.byType(TextField), 'tolu@example.com');
      await _tap(tester, 'Send code');
      await tester.enterText(find.byType(TextField), '123');
      await _tap(tester, 'Verify');
      expect(find.text('Enter all 6 digits.'), findsOneWidget);
    });

    testWidgets('the right code signs in and goes on to account type', (
      tester,
    ) async {
      final app = _App();
      await _pump(tester, app);
      await _signIn(tester);
      expect(find.text('How will you use PawPass?'), findsOneWidget);
      expect(app.auth.signedIn, isTrue);
    });

    testWidgets('a send failure is shown and the person stays put', (
      tester,
    ) async {
      final app = _App();
      app.auth.failNextSend = const AppFailure(
        'Too many tries. Wait a minute, then try again.',
      );
      await _pump(tester, app);
      await _tap(tester, 'Get started');
      await tester.enterText(find.byType(TextField), 'tolu@example.com');
      await _tap(tester, 'Send code');
      expect(find.textContaining('Too many tries'), findsOneWidget);
      expect(find.text("What's your email?"), findsOneWidget);
    });

    testWidgets('resend is locked for a minute, then asks for a new code', (
      tester,
    ) async {
      final app = _App();
      await _pump(tester, app);
      await _tap(tester, 'Get started');
      await tester.enterText(find.byType(TextField), 'tolu@example.com');
      await _tap(tester, 'Send code');
      expect(find.textContaining('Resend in 1:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.textContaining('Resend in 0:30'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('Resend code'), findsOneWidget);
      await _tap(tester, 'Resend code');
      expect(app.auth.sentTo, ['tolu@example.com', 'tolu@example.com']);
      expect(find.text('We sent a new code.'), findsOneWidget);
      expect(find.textContaining('Resend in 1:00'), findsOneWidget);
    });

    testWidgets('Open email app calls the phone, and explains if it cannot', (
      tester,
    ) async {
      final app = _App();
      await _pump(tester, app);
      await _tap(tester, 'Get started');
      await tester.enterText(find.byType(TextField), 'tolu@example.com');
      await _tap(tester, 'Send code');
      await _tap(tester, 'Open email app');
      expect(app.mail.opened, 1);
      app.mail.result = false;
      await _tap(tester, 'Open email app');
      expect(find.textContaining('Open your email app'), findsOneWidget);
    });

    testWidgets('Google and Apple stay hidden until they are set up', (
      tester,
    ) async {
      await _pump(tester, _App());
      await _tap(tester, 'Get started');
      expect(find.text('Google'), findsNothing);
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('the back button goes back', (tester) async {
      await _pump(tester, _App());
      await _tap(tester, 'Get started');
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
    });
  });

  group('account type and profile', () {
    testWidgets(
      'owner is ticked, several can be picked, at least one is needed',
      (tester) async {
        final app = _App(signedInAs: 'tolu@example.com');
        await _pump(tester, app);
        expect(find.text('How will you use PawPass?'), findsOneWidget);
        await _tap(tester, 'Breeder');
        await _tap(tester, 'Continue');
        expect(find.text('Tell us about you'), findsOneWidget);
        expect((await app.profiles.load()).accountTypes, {
          AccountType.owner,
          AccountType.breeder,
        });
      },
    );

    testWidgets('with nothing ticked Continue is off', (tester) async {
      await _pump(tester, _App(signedInAs: 'tolu@example.com'));
      await _tap(tester, 'Pet owner');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('How will you use PawPass?'), findsOneWidget);
    });

    testWidgets(
      'profile needs a first name, and saves the phone in international form',
      (tester) async {
        final app = _App(signedInAs: 'tolu@example.com');
        await _pump(tester, app);
        await _tap(tester, 'Continue');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Tell us about you'), findsOneWidget);
        expect(
          app.profiles.saves,
          1,
          reason: 'only the account type save so far',
        );

        await tester.enterText(
          find.widgetWithText(TextField, '').at(0),
          'Tolu',
        );
        await tester.enterText(
          find.widgetWithText(TextField, '').at(1),
          'Adeyemi',
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'Lekki');
        await tester.enterText(find.byType(TextField).at(3), '0803 123 4567');
        await _tap(tester, 'Continue');
        final p = await app.profiles.load();
        expect(p.firstName, 'Tolu');
        expect(p.area, 'Lekki');
        expect(p.phone, '+2348031234567');
        expect(find.text('Add your first pet'), findsOneWidget);
      },
    );

    testWidgets('a bad phone number is explained and nothing moves on', (
      tester,
    ) async {
      final app = _App(signedInAs: 'tolu@example.com');
      await _pump(tester, app);
      await _tap(tester, 'Continue');
      await tester.enterText(find.byType(TextField).at(0), 'Tolu');
      await tester.enterText(find.byType(TextField).at(3), '12345');
      await tester.pumpAndSettle();
      await _tap(tester, 'Continue');
      expect(
        find.textContaining('phone number does not look right'),
        findsOneWidget,
      );
      expect(find.text('Tell us about you'), findsOneWidget);
    });

    testWidgets('a chosen profile photo is uploaded', (tester) async {
      final app = _App(signedInAs: 'tolu@example.com');
      app.photos.next = PickedPhoto(Uint8List.fromList(_tinyPng));
      await _pump(tester, app);
      await _tap(tester, 'Continue');
      await tester.enterText(find.byType(TextField).at(0), 'Tolu');
      await tester.tap(find.bySemanticsLabel('Add your photo'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Choose from your photos');
      expect(find.bySemanticsLabel('Change your photo'), findsOneWidget);
      await _tap(tester, 'Continue');
      expect(app.profiles.avatarUploads, 1);
    });
  });

  for (final (label, size, scale) in [
    ('on a 390 x 844 phone', const Size(390, 844), 1.0),
    ('on a small 320 x 568 phone with large text', const Size(320, 568), 1.3),
  ]) {
    testWidgets('the whole journey, first sign in to passport ready $label', (
      tester,
    ) async {
      final app = _App();
      await _pump(tester, app, size: size, textScale: scale);

      await _signIn(tester);
      expect(find.text('How will you use PawPass?'), findsOneWidget);
      await _tap(tester, 'Continue');

      expect(find.text('Tell us about you'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Tolu');
      await tester.enterText(find.byType(TextField).at(1), 'Adeyemi');
      await tester.pumpAndSettle();
      await _tap(tester, 'Continue');

      expect(find.text('Add your first pet'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Bingo');
      await tester.pumpAndSettle();
      await _tap(tester, 'Choose a breed');
      await _tap(tester, 'Boerboel');
      await _tap(tester, 'Male');
      await _tap(tester, 'Not sure? Enter approximate age');
      await tester.enterText(find.widgetWithText(TextField, '').at(0), '2');
      await tester.pumpAndSettle();
      expect(find.text('About 2 yrs old'), findsOneWidget);
      await _tap(tester, 'Continue');

      expect(find.text("Bingo's health so far"), findsOneWidget);
      await _tap(tester, 'Rabies');
      expect(find.text('Set date'), findsNothing);
      await _tap(tester, 'OK');
      expect(find.text('Last given 5 Nov 2026'), findsOneWidget);
      await _tap(tester, 'Save health history');

      expect(find.text('Never miss a dose'), findsOneWidget);
      expect(find.text('Rabies booster'), findsOneWidget);
      expect(find.text('Yearly'), findsWidgets);
      await _tap(tester, 'Turn on reminders');

      expect(find.text("Bingo's passport is ready"), findsOneWidget);
      expect(find.text('1 record saved and reminders are on.'), findsOneWidget);
      expect(find.text('Tag ID PP-4821-LK'), findsOneWidget);
      expect(find.text('Boerboel · Male · 2 yrs'), findsOneWidget);
      expect(find.text('Coming\nsoon'), findsOneWidget);

      final saved = app.pets.pets.single;
      expect(saved.species, Species.dog);
      expect(saved.breed, 'Boerboel');
      expect(saved.dateOfBirth, DateTime(2024, 11, 5));
      expect(
        app.pets.recordsSaved.single.single.nextDueOn,
        DateTime(2027, 11, 5),
      );

      await _tap(tester, 'Go to home');
      expect(find.text('Good morning, Tolu'), findsOneWidget);
      expect(find.text('Bingo'), findsWidgets);
    });
  }

  group('health history and reminders', () {
    Future<void> toHealth(WidgetTester tester, _App app) async {
      await _pump(tester, app);
      await _tap(tester, 'Continue');
      await tester.enterText(find.byType(TextField).at(0), 'Tolu');
      await tester.pumpAndSettle();
      await _tap(tester, 'Continue');
      await tester.enterText(find.byType(TextField).first, 'Mimi');
      await tester.pumpAndSettle();
      await _tap(tester, 'Cat');
      await _tap(tester, 'Continue');
    }

    testWidgets('the vaccine names follow the species', (tester) async {
      await toHealth(tester, _App(signedInAs: 'tolu@example.com'));
      expect(find.text("Mimi's health so far"), findsOneWidget);
      expect(find.text('FVRCP (3-in-1)'), findsOneWidget);
      expect(find.text('DHPP (5-in-1)'), findsNothing);
    });

    testWidgets('cancelling the date leaves it unticked', (tester) async {
      await toHealth(tester, _App(signedInAs: 'tolu@example.com'));
      await _tap(tester, 'Deworming');
      await _tap(tester, 'Cancel');
      expect(find.text('Not added'), findsNWidgets(4));
    });

    testWidgets('a ticked item can be unticked again', (tester) async {
      await toHealth(tester, _App(signedInAs: 'tolu@example.com'));
      await _tap(tester, 'Deworming');
      await _tap(tester, 'OK');
      expect(find.text('Edit date'), findsOneWidget);
      await _tap(tester, 'Deworming');
      expect(find.text('Edit date'), findsNothing);
    });

    testWidgets(
      'Skip goes to reminders with an empty schedule, and the passport is still made',
      (tester) async {
        final app = _App(signedInAs: 'tolu@example.com');
        await toHealth(tester, app);
        await _tap(tester, 'Skip');
        expect(find.text('Never miss a dose'), findsOneWidget);
        expect(find.textContaining('No schedule yet'), findsOneWidget);
        await _tap(tester, 'Turn on reminders');
        expect(find.text("Mimi's passport is ready"), findsOneWidget);
        expect(find.text('Reminders are on.'), findsOneWidget);
        expect(app.pets.recordsSaved.single, isEmpty);
      },
    );

    testWidgets('turning every channel off changes the button and the result', (
      tester,
    ) async {
      final app = _App(signedInAs: 'tolu@example.com');
      await toHealth(tester, app);
      await _tap(tester, 'Skip');
      await _tap(tester, 'App notifications');
      await _tap(tester, 'WhatsApp');
      await _tap(tester, 'Email');
      expect(find.text('Continue without reminders'), findsOneWidget);
      await _tap(tester, 'Continue without reminders');
      expect(find.text('Reminders are off.'), findsOneWidget);
      expect(app.pets.channelsSaved.single, isEmpty);
    });

    testWidgets('WhatsApp without a phone number gets a hint', (tester) async {
      await toHealth(tester, _App(signedInAs: 'tolu@example.com'));
      await _tap(tester, 'Skip');
      expect(find.textContaining('Add your phone number'), findsOneWidget);
      await _tap(tester, 'WhatsApp');
      expect(find.textContaining('Add your phone number'), findsNothing);
    });

    testWidgets('a failed save is explained and can be retried', (
      tester,
    ) async {
      final app = _App(signedInAs: 'tolu@example.com');
      await toHealth(tester, app);
      await _tap(tester, 'Skip');
      app.pets.failNext = const AppFailure(
        'We could not create the passport. Nothing was saved.',
      );
      await _tap(tester, 'Turn on reminders');
      expect(find.textContaining('Nothing was saved'), findsOneWidget);
      expect(find.text('Never miss a dose'), findsOneWidget);
      expect(app.pets.pets, isEmpty);
      await _tap(tester, 'Turn on reminders');
      expect(find.text("Mimi's passport is ready"), findsOneWidget);
      expect(app.pets.pets, hasLength(1));
    });
  });

  group('coming back', () {
    testWidgets('someone who left half way resumes after signing in again', (
      tester,
    ) async {
      await _pump(tester, _App(signedInAs: 'tolu@example.com'));
      expect(find.text('How will you use PawPass?'), findsOneWidget);
    });

    testWidgets('someone who finished goes straight home', (tester) async {
      final app = _App(signedInAs: 'tolu@example.com');
      await app.profiles.save(firstName: 'Tolu');
      app.profiles.markOnboarded(_today);
      await _pump(tester, app);
      expect(find.text('Good morning, Tolu'), findsOneWidget);
      expect(find.text('Get started'), findsNothing);
    });

    testWidgets(
      'adding another pet works from home and from the end of onboarding',
      (tester) async {
        final app = _App(signedInAs: 'tolu@example.com');
        await app.profiles.save(firstName: 'Tolu');
        app.profiles.markOnboarded(_today);
        await _pump(tester, app);
        await _tap(tester, 'Add a pet');
        expect(find.text('Add another pet'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Step 5 of 6'),
          findsNothing,
          reason: 'no progress bar after the first pet',
        );
        await tester.enterText(find.byType(TextField).first, 'Mimi');
        await tester.pumpAndSettle();
        await _tap(tester, 'Continue');
        await _tap(tester, 'Skip');
        await _tap(tester, 'Turn on reminders');
        expect(find.text("Mimi's passport is ready"), findsOneWidget);
        await _tap(tester, 'Add another pet');
        expect(find.text('Add another pet'), findsOneWidget);
        expect(app.pets.pets, hasLength(1));
      },
    );

    testWidgets('signing out clears what was typed and returns to welcome', (
      tester,
    ) async {
      final app = _App(signedInAs: 'tolu@example.com');
      await app.profiles.save(firstName: 'Tolu');
      app.profiles.markOnboarded(_today);
      await _pump(tester, app);
      await tester.tap(find.bySemanticsLabel('Your account'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Log out');
      expect(find.text('Get started'), findsOneWidget);
      await _tap(tester, 'Get started');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });
  });

  group('accessibility', () {
    testWidgets('screens have a header and labelled controls', (tester) async {
      await _pump(tester, _App());
      await _tap(tester, 'Get started');
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Email address')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Send code')), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'tolu@example.com');
      await _tap(tester, 'Send code');
      expect(find.bySemanticsLabel(RegExp('6 digit code')), findsOneWidget);
      expect(find.bySemanticsLabel('Step 2 of 6'), findsOneWidget);
      handle.dispose();
    });
  });
}

// A 1x1 transparent PNG, enough for Image.memory in tests.
const _tinyPng = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xFF,
  0xFF,
  0x3F,
  0x00,
  0x05,
  0xFE,
  0x02,
  0xFE,
  0xA7,
  0x35,
  0x81,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
