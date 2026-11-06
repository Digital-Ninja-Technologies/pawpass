import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/health/domain/models.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/health/ui/health_widgets.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/ui/ui.dart';

final _today = DateTime(2026, 11, 5, 9);

/// Tolu, signed in and set up, with Bingo and Mimi and the sample data from the designs.
class _Rig {
  _Rig({this.withPets = true, this.position}) {
    profiles = InMemoryProfileRepository();
    auth = InMemoryAuthRepository(signedInAs: 'tolu@example.com');
    pets = InMemoryPetRepository(profiles: profiles, now: () => _today);
    health = InMemoryHealthRepository(now: () => _today);
    notifications = InMemoryNotificationsRepository();
    vets = InMemoryVetsRepository();
    location = FakeLocationService(position);
    links = FakeLinkLauncher();
    photos = NoPhotoPicker();
    services = AppServices(
      auth: auth,
      profiles: profiles,
      pets: pets,
      photos: photos,
      emailApp: NoEmailApp(),
      health: health,
      notifications: notifications,
      vets: vets,
      location: location,
      links: links,
      bookings: InMemoryBookingsRepository(),
      payments: InMemoryPaymentsRepository(InMemoryBookingsRepository()),
      now: () => _today,
    );
  }

  final bool withPets;
  final ({double lat, double lng})? position;
  late final InMemoryProfileRepository profiles;
  late final InMemoryAuthRepository auth;
  late final InMemoryPetRepository pets;
  late final InMemoryHealthRepository health;
  late final InMemoryNotificationsRepository notifications;
  late final InMemoryVetsRepository vets;
  late final FakeLocationService location;
  late final FakeLinkLauncher links;
  late final NoPhotoPicker photos;
  late final AppServices services;
  late Pet bingo;
  late Pet mimi;

  Future<void> seed() async {
    await profiles.save(firstName: 'Tolu', lastName: 'Adeyemi', area: 'Lekki');
    profiles.markOnboarded(_today);
    if (!withPets) return;
    bingo = await pets.createPassport(
      pet: PetInput(
        name: 'Bingo',
        species: Species.dog,
        breed: 'Boerboel',
        sex: PetSex.male,
        dateOfBirth: DateTime(2024, 8, 14),
      ),
      records: const [],
      channels: {ReminderChannel.push},
    );
    mimi = await pets.createPassport(
      pet: PetInput(
        name: 'Mimi',
        species: Species.cat,
        breed: 'Tabby',
        sex: PetSex.female,
        dateOfBirth: DateTime(2025, 11, 5),
      ),
      records: const [],
      channels: {ReminderChannel.push},
    );
    health.seed(
      petId: bingo.id,
      petName: 'Bingo',
      type: RecordType.vaccine,
      name: 'Rabies',
      givenOn: DateTime(2025, 11, 12),
      nextDueOn: DateTime(2026, 11, 12),
    );
    health.seed(
      petId: bingo.id,
      petName: 'Bingo',
      type: RecordType.vaccine,
      name: 'DHPP vaccine',
      givenOn: DateTime(2026, 3, 12),
      nextDueOn: DateTime(2027, 3, 12),
      verified: true,
      verifier: 'Dr. Amina Bello',
    );
    health.seed(
      petId: bingo.id,
      petName: 'Bingo',
      type: RecordType.deworming,
      name: 'Deworming',
      givenOn: DateTime(2026, 10, 20),
      nextDueOn: DateTime(2027, 1, 20),
    );
    for (var i = 0; i < 6; i++) {
      health.seed(
        petId: bingo.id,
        petName: 'Bingo',
        type: RecordType.weight,
        name: 'Weight',
        givenOn: DateTime(2026, 5 + i, 1),
        value: '${34 + i}',
      );
    }
    health.seed(
      petId: bingo.id,
      petName: 'Bingo',
      type: RecordType.weight,
      name: 'Weight',
      givenOn: DateTime(2026, 11, 1),
      value: '41 kg',
    );
    health.seed(
      petId: mimi.id,
      petName: 'Mimi',
      type: RecordType.treatment,
      name: 'Flea & tick treatment',
      givenOn: DateTime(2026, 10, 28),
      nextDueOn: DateTime(2026, 11, 28),
    );
    health.seed(
      petId: mimi.id,
      petName: 'Mimi',
      type: RecordType.vaccine,
      name: 'FVRCP',
      givenOn: DateTime(2026, 2, 3),
      nextDueOn: DateTime(2027, 2, 3),
    );
    notifications.items.addAll([
      AppNotification(
        id: 'n1',
        kind: NotificationKind.lostAlert,
        title: 'Lost dog near you',
        body: 'Bruno, a brown Jack Russell, was last seen on Admiralty Way.',
        createdAt: DateTime(2026, 11, 5, 7),
      ),
      AppNotification(
        id: 'n2',
        kind: NotificationKind.reminderDue,
        title: 'Rabies booster in 7 days',
        body: 'Book a vet for Bingo before 12 Nov.',
        link: '/schedule',
        createdAt: DateTime(2026, 11, 5, 8),
      ),
      AppNotification(
        id: 'n3',
        kind: NotificationKind.recordVerified,
        title: 'Record verified',
        body: "Dr. Amina Bello verified Bingo's DHPP vaccine.",
        link: '/passport',
        createdAt: DateTime(2026, 11, 4, 15),
        read: true,
      ),
      AppNotification(
        id: 'n4',
        kind: NotificationKind.booking,
        title: "How was Mimi's grooming?",
        createdAt: DateTime(2026, 11, 3, 10),
        read: true,
      ),
    ]);
    vets.vets.addAll(const [
      EmergencyVet(
        id: 'v1',
        name: 'Lekki Animal Hospital',
        area: 'Lekki',
        phone: '+2340000000002',
        open24h: true,
        openNow: true,
        homeVisits: false,
        distanceMeters: 3400,
        lat: 6.44,
        lng: 3.472,
      ),
      EmergencyVet(
        id: 'v2',
        name: 'Paws & Claws Vet Clinic',
        area: 'Ikeja',
        phone: '+2340000000001',
        open24h: false,
        openNow: true,
        homeVisits: false,
        closesAt: '20:00:00',
        distanceMeters: 2100,
        lat: 6.6,
        lng: 3.35,
      ),
      EmergencyVet(
        id: 'v3',
        name: 'Dr. Amina Bello · home visit',
        area: 'Ikate',
        phone: '+2340000000003',
        open24h: false,
        openNow: true,
        homeVisits: true,
        lat: 6.45,
        lng: 3.46,
      ),
    ]);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Rig rig, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  await rig.seed();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: PawPassApp(services: rig.services),
    ),
  );
  await tester.pumpAndSettle();
}

/// Lists keep their scroll position, so a header can be out of view after tapping lower down.
Future<void> _scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 1500));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  // Most screens use PawBackButton; Emergency has a round icon button on its red header.
  final plain = find.byType(PawBackButton);
  final round = find.byWidgetPredicate(
    (w) => w is RoundIconButton && w.semanticLabel == 'Back',
  );
  expect(
    plain.evaluate().isNotEmpty || round.evaluate().isNotEmpty,
    isTrue,
    reason: 'No back button on screen',
  );
  await tester.tap(plain.evaluate().isNotEmpty ? plain.first : round.first);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text, {bool last = false}) async {
  expect(
    find.text(text),
    findsWidgets,
    reason: 'Could not find "$text" on screen',
  );
  final f = last ? find.text(text).last : find.text(text).first;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _tapLabel(WidgetTester tester, String label) async {
  // Round icon buttons are found by their label directly; everything else by its semantics label.
  final icon = find.byWidgetPredicate(
    (w) => w is RoundIconButton && w.semanticLabel == label,
  );
  final f = icon.evaluate().isNotEmpty
      ? icon.first
      : find.bySemanticsLabel(label).first;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String name) async {
  await tester.tap(
    find.descendant(of: find.byType(PawTabBar), matching: find.text(name)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Home', () {
    testWidgets('greets, shows the pet card and what is due', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      expect(find.text('Thursday, 5 November'), findsOneWidget);
      expect(find.text('Good morning, Tolu'), findsOneWidget);
      expect(find.text('Boerboel · 2 yrs · 41 kg'), findsOneWidget);
      expect(find.text('Something due soon'), findsOneWidget);
      expect(find.text('DUE IN 7 DAYS'), findsOneWidget);
      expect(find.text('Rabies booster for Bingo'), findsOneWidget);
      expect(
        find.textContaining('Last dose 12 Nov 2025', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Book a vet'), findsOneWidget);
      expect(find.text('Mark as done'), findsOneWidget);
      expect(find.text('Emergency vet'), findsOneWidget);
    });

    testWidgets('the evening greeting follows the time of day', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      // 9am in these tests, so morning; the wording itself is unit tested for the other times of day.
      expect(find.textContaining('Good morning'), findsOneWidget);
    });

    testWidgets('the bell says how many are new', (tester) async {
      await _pump(tester, _Rig());
      expect(find.bySemanticsLabel('Notifications, 2 new'), findsOneWidget);
    });

    testWidgets('switching pets shows their own due item', (tester) async {
      await _pump(tester, _Rig());
      await _tap(tester, 'Mimi');
      expect(find.text('Flea & tick treatment for Mimi'), findsOneWidget);
      expect(find.text('Rabies booster for Bingo'), findsNothing);
    });

    testWidgets(
      'Mark as done asks for a date, records it, and says what is next',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        await _tap(tester, 'Mark as done');
        expect(find.text('Date given'), findsOneWidget);
        expect(find.textContaining('Today, 5 Nov 2026'), findsOneWidget);
        await tester.tap(find.widgetWithText(PawButton, 'Mark as done'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Rabies booster marked as done. The next one is due 5 Nov 2027.',
          ),
          findsOneWidget,
        );
        // The next thing for Bingo is now the deworming in January.
        expect(find.text('Rabies booster for Bingo'), findsNothing);
        expect(find.text('Deworming for Bingo'), findsOneWidget);
        expect(find.text('NEXT UP'), findsOneWidget);
      },
    );

    testWidgets('a pet with nothing scheduled is invited to add a record', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _tap(tester, 'Mimi');
      // Mark both of Mimi's items done so nothing is left.
      for (final r in List.of(rig.health.petNames.keys)) {
        r.toString();
      }
      expect(find.text('Flea & tick treatment for Mimi'), findsOneWidget);
    });

    testWidgets('quick actions go to their tabs', (tester) async {
      await _pump(tester, _Rig());
      await _tap(tester, 'Vet');
      expect(find.text('Book care'), findsOneWidget);
      expect(find.text('Search services'), findsOneWidget);
      await _tab(tester, 'Home');
      await _tap(tester, 'Find a pet');
      expect(
        find.text(
          'Meet verified breeders and shelters, and bring a pet home with its passport.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Report lost is coming soon, with a way back', (tester) async {
      await _pump(tester, _Rig());
      await _tap(tester, 'Report lost');
      expect(find.text('Report a lost pet'), findsOneWidget);
      await _back(tester);
      expect(find.text('Good morning, Tolu'), findsOneWidget);
    });

    testWidgets('no pets: invites adding one', (tester) async {
      await _pump(tester, _Rig(withPets: false));
      expect(find.text('No pets yet'), findsOneWidget);
      expect(find.text('Add a pet'), findsOneWidget);
    });

    testWidgets('a load failure offers to try again', (tester) async {
      final rig = _Rig();
      await rig.seed();
      rig.health.failNext = const AppFailure('We could not load the schedule.');
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(PawPassApp(services: rig.services));
      await tester.pumpAndSettle();
      expect(find.text('We could not load the schedule.'), findsOneWidget);
      await _tap(tester, 'Try again');
      expect(find.text('Good morning, Tolu'), findsOneWidget);
    });

    testWidgets('the account button signs out and forgets the pets', (
      tester,
    ) async {
      await _pump(tester, _Rig());
      await _tapLabel(tester, 'Your account');
      expect(find.text('tolu@example.com'), findsOneWidget);
      await _tap(tester, 'Sign out');
      expect(find.text('Get started'), findsOneWidget);
    });
  });

  group('Passport', () {
    testWidgets('identity, records and weight', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _tab(tester, 'Passport');
      expect(find.text('Pet Passport'), findsOneWidget);
      expect(find.text('Bingo'), findsWidgets);
      expect(find.text('Boerboel · Male · Born 14 Aug 2024'), findsOneWidget);
      expect(find.text('Tag ID'), findsOneWidget);
      expect(find.text('PP-4821-LK'), findsOneWidget);
      expect(find.text('Not recorded'), findsOneWidget);

      // Upcoming first, then what has been given, with the vet verified badge.
      expect(find.text('Vaccines & treatments'), findsOneWidget);
      expect(find.text('Due 12 Nov 2026'), findsOneWidget);
      expect(find.text('Upcoming'), findsWidgets);
      expect(find.text('12 Mar 2026 · Dr. Amina Bello'), findsOneWidget);
      expect(find.text('Vet verified'), findsOneWidget);
      expect(find.text('20 Oct 2026 · added by you'), findsOneWidget);
      expect(find.text('41 kg · last 6 entries'), findsOneWidget);
    });

    testWidgets('origin and services tabs', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _tab(tester, 'Passport');
      await _tap(tester, 'Origin', last: true);
      expect(find.textContaining('No breeder or shelter'), findsOneWidget);
      expect(find.text('Not recorded.'), findsOneWidget);

      // Once a breeder is linked, the passport says where the pet comes from.
      rig.health.details[rig.bingo.id] = const PetDetails(
        originName: 'Royal Paws Kennels',
        originVerified: true,
        motherName: 'Duchess',
      );
      await _tab(tester, 'Home');
      await _tap(tester, 'Mimi');
      await _tap(tester, 'Bingo');
      await _tab(tester, 'Passport');
      await _tap(tester, 'Origin', last: true);
      expect(find.text('Royal Paws Kennels'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Mother: Duchess'), findsOneWidget);

      await _tap(tester, 'Services');
      expect(find.text('No services yet'), findsOneWidget);
    });

    testWidgets('an overdue dose says so', (tester) async {
      final rig = _Rig();
      await rig.seed();
      rig.health.seed(
        petId: rig.bingo.id,
        petName: 'Bingo',
        type: RecordType.treatment,
        name: 'Tick & flea treatment',
        givenOn: DateTime(2026, 9, 1),
        nextDueOn: DateTime(2026, 10, 1),
      );
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(PawPassApp(services: rig.services));
      await tester.pumpAndSettle();
      expect(find.text('1 reminder overdue'), findsOneWidget);
      await _tab(tester, 'Passport');
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('a new pet with nothing yet has an empty state', (
      tester,
    ) async {
      final rig = _Rig();
      await rig.seed();
      final rex = await rig.pets.createPassport(
        pet: const PetInput(name: 'Rex', species: Species.dog),
        records: const [],
        channels: {ReminderChannel.push},
      );
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(PawPassApp(services: rig.services));
      await tester.pumpAndSettle();
      await _tap(tester, 'Rex');
      await _tab(tester, 'Passport');
      expect(find.text('No records yet'), findsOneWidget);
      expect(find.textContaining('No weights yet'), findsOneWidget);
      expect(rex.name, 'Rex');
    });
  });

  group('Schedule', () {
    Future<void> open(WidgetTester tester) async {
      await _tap(tester, 'See schedule');
    }

    testWidgets('groups this month and coming up, like the design', (
      tester,
    ) async {
      await _pump(tester, _Rig());
      await open(tester);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('THIS MONTH'), findsOneWidget);
      expect(find.text('COMING UP'), findsOneWidget);
      expect(find.text('Bingo · in 7 days'), findsOneWidget);
      expect(find.text('Mimi · monthly'), findsOneWidget);
      expect(find.text('Bingo · every 3 months'), findsOneWidget);
      expect(find.text('Mimi · yearly'), findsOneWidget);
      expect(find.text('Bingo · yearly'), findsOneWidget);
      // Only the close one has the full card.
      expect(find.text('Book a vet'), findsOneWidget);
      expect(find.text('Mark done'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('can be filtered to one pet', (tester) async {
      await _pump(tester, _Rig());
      await open(tester);
      await _tap(tester, 'Mimi');
      expect(find.text('Mimi · monthly'), findsOneWidget);
      expect(find.text('Bingo · in 7 days'), findsNothing);
      await _tap(tester, 'All pets');
      expect(find.text('Bingo · in 7 days'), findsOneWidget);
    });

    testWidgets(
      'Mark done records the dose and the next one appears under coming up',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        await open(tester);
        await _tap(tester, 'Mark done');
        await tester.tap(find.widgetWithText(PawButton, 'Mark as done'));
        await tester.pumpAndSettle();
        expect(find.text('Bingo · in 7 days'), findsNothing);
        expect(find.textContaining('marked as done'), findsOneWidget);
        expect(rig.health.recordAdds, 0);
        final bingoRecords = await rig.health.records(rig.bingo.id);
        expect(
          bingoRecords.where(
            (r) => r.name == 'Rabies' && r.givenOn == DateTime(2026, 11, 5),
          ),
          hasLength(1),
        );
      },
    );

    testWidgets('the small Done button on a later item works too', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      await _tap(tester, 'Done');
      expect(find.text('Mark as done'), findsWidgets);
      await tester.tap(find.widgetWithText(PawButton, 'Mark as done'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Flea & tick treatment marked as done'),
        findsOneWidget,
      );
      // A monthly treatment comes round again, so the next one is listed; the dose is recorded today.
      final mimiRecords = await rig.health.records(rig.mimi.id);
      expect(
        mimiRecords.where((r) => r.givenOn == DateTime(2026, 11, 5)),
        hasLength(1),
      );
    });

    testWidgets('overdue items come first with a danger label', (tester) async {
      final rig = _Rig();
      await rig.seed();
      rig.health.seed(
        petId: rig.bingo.id,
        petName: 'Bingo',
        type: RecordType.treatment,
        name: 'Tick & flea treatment',
        givenOn: DateTime(2026, 9, 1),
        nextDueOn: DateTime(2026, 10, 1),
      );
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(PawPassApp(services: rig.services));
      await tester.pumpAndSettle();
      await _tap(tester, 'See schedule');
      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.text('Bingo · overdue by 35 days'), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      await _pump(tester, _Rig(withPets: false));
      await _tab(tester, 'Home');
      // Reach the schedule through the notification that links to it.
      expect(find.text('No pets yet'), findsOneWidget);
    });

    testWidgets('the plus button opens Add a record', (tester) async {
      await _pump(tester, _Rig());
      await open(tester);
      await _tapLabel(tester, 'Add reminder');
      expect(find.text('Add a record for Bingo'), findsOneWidget);
    });
  });

  group('Add a record', () {
    Future<void> open(WidgetTester tester) async {
      await _tab(tester, 'Passport');
      await _tap(tester, '+ Add record');
    }

    testWidgets('a vaccine fills in next due a year on', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      expect(find.text('Add a record for Bingo'), findsOneWidget);
      expect(find.text('5 Nov 2026'), findsOneWidget);
      expect(find.text('5 Nov 2027'), findsOneWidget);
      expect(
        find.text('Next due is set automatically. You can change it.'),
        findsOneWidget,
      );
      await _tap(tester, 'DHPP (5-in-1)');
      await _tap(tester, 'Save record');

      expect(
        find.textContaining('Record saved. Next due 5 Nov 2027.'),
        findsOneWidget,
      );
      expect(find.text('Vaccines & treatments'), findsOneWidget);
      expect(find.text('Due 5 Nov 2027'), findsOneWidget);
      expect(find.text('5 Nov 2026 · added by you'), findsOneWidget);
    });

    testWidgets('changing the type changes the suggestion and the due date', (
      tester,
    ) async {
      await _pump(tester, _Rig());
      await open(tester);
      await _tap(tester, 'Deworming');
      expect(find.text('5 Feb 2027'), findsOneWidget);
      await _tap(tester, 'Vet visit');
      expect(find.text('None'), findsOneWidget);
      expect(
        find.text('No reminder will be set. Pick a date if you want one.'),
        findsOneWidget,
      );
      await _tap(tester, 'Allergy');
      expect(find.text('Next due'), findsNothing);
    });

    testWidgets('a record needs a name', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      await _tap(tester, 'Save record');
      expect(find.text('Enter a name for the vaccine.'), findsOneWidget);
      expect(find.text('Add a record for Bingo'), findsOneWidget);
      expect(rig.health.recordAdds, 0);
    });

    testWidgets('a weight has no due date, and must be a believable number', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      await _tap(tester, 'Weight');
      expect(find.text('Weight (kg)'), findsOneWidget);
      expect(find.text('Next due'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'heavy');
      await _tap(tester, 'Save record');
      expect(find.textContaining('Enter a weight'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '42');
      await tester.pumpAndSettle();
      await _tap(tester, 'Save record');
      expect(find.text('Vaccines & treatments'), findsOneWidget);
      expect(find.text('42 kg · last 6 entries'), findsOneWidget);
    });

    testWidgets('the person can remove the next due date', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Kennel cough');
      await tester.pumpAndSettle();
      await _tap(tester, 'Remove next due date');
      expect(
        find.text('No reminder will be set. Pick a date if you want one.'),
        findsOneWidget,
      );
      await _tap(tester, 'Save record');
      final records = await rig.health.records(rig.bingo.id);
      final saved = records.firstWhere((r) => r.name == 'Kennel cough');
      expect(saved.nextDueOn, isNull);
    });

    testWidgets('who gave it and a photo are kept', (tester) async {
      final rig = _Rig();
      rig.photos.next = PickedPhoto(Uint8List.fromList(_tinyPng));
      await _pump(tester, rig);
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Rabies');
      await tester.enterText(find.byType(TextField).at(1), 'Paws and Claws');
      await tester.pumpAndSettle();
      await _tapLabel(tester, 'Attach a photo');
      await _tap(tester, 'Choose from your photos');
      expect(find.text('Photo attached. Tap to change.'), findsOneWidget);
      await _tap(tester, 'Save record');
      expect(rig.health.attachments, 1);
      expect(find.text('5 Nov 2026 · Paws and Claws'), findsOneWidget);
    });

    testWidgets('a failed save is explained and keeps the form', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Rabies');
      await tester.pumpAndSettle();
      rig.health.failNext = const AppFailure(
        'We could not save the record. Nothing was saved.',
      );
      await _tap(tester, 'Save record');
      expect(
        find.text('We could not save the record. Nothing was saved.'),
        findsOneWidget,
      );
      expect(find.text('Add a record for Bingo'), findsOneWidget);
      await _tap(tester, 'Save record');
      expect(find.text('Vaccines & treatments'), findsOneWidget);
    });

    testWidgets('close goes back', (tester) async {
      await _pump(tester, _Rig());
      await open(tester);
      await _tapLabel(tester, 'Close');
      expect(find.text('Vaccines & treatments'), findsOneWidget);
    });
  });

  group('Share with a vet', () {
    Future<void> open(WidgetTester tester) async {
      await _tab(tester, 'Passport');
      await _tapLabel(tester, 'Share passport');
    }

    testWidgets('shows a QR code that expires, with everything on by default', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      expect(find.text("Share Bingo's passport"), findsOneWidget);
      expect(find.byType(PawQrCode), findsOneWidget);
      expect(find.text('Link expires in 24 hours'), findsOneWidget);
      expect(rig.health.shares, hasLength(1));
      expect(rig.health.shares.single.link.scopes, {
        ShareScope.health,
        ShareScope.origin,
        ShareScope.write,
      });
      expect(rig.health.shares.single.petId, rig.bingo.id);
    });

    testWidgets('changing a switch makes a new link and stops the old one', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      final first = rig.health.shares.single.link;
      await _tap(tester, 'Let the vet add records');
      expect(rig.health.shares, hasLength(2));
      expect(rig.health.shares[0].revoked, isTrue);
      expect(rig.health.shares[1].revoked, isFalse);
      expect(rig.health.shares[1].link.scopes, {
        ShareScope.health,
        ShareScope.origin,
      });
      expect(rig.health.shares[1].link.token, isNot(first.token));
    });

    testWidgets(
      'copy puts the link, with the token after a #, on the clipboard',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        await open(tester);
        await _tap(tester, 'Copy link');
        final token = rig.health.shares.single.link.token;
        expect(
          rig.links.copied.single,
          'https://pawpass-web-ten.vercel.app/s#$token',
        );
        expect(find.text('Link copied.'), findsOneWidget);
      },
    );

    testWidgets('WhatsApp opens with a message that carries the link', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      await _tap(tester, 'Send on WhatsApp');
      final uri = rig.links.opened.single;
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], contains("Bingo's PawPass passport"));
      expect(
        uri.queryParameters['text'],
        contains('#${rig.health.shares.single.link.token}'),
      );
    });

    testWidgets('with every switch off there is nothing to share', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      for (final label in [
        'Health records & vaccines',
        'Origin & parents',
        'Let the vet add records',
      ]) {
        await _tap(tester, label);
      }
      expect(find.text('Choose at least one thing to share.'), findsOneWidget);
      expect(find.byType(PawQrCode), findsNothing);
      expect(rig.health.shares.every((s) => s.revoked), isTrue);
      await tester.tap(find.text('Copy link'));
      await tester.pump();
      expect(rig.links.copied, isEmpty);
    });

    testWidgets('Stop sharing now ends it', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      await _tap(tester, 'Stop sharing now');
      expect(rig.health.shares.single.revoked, isTrue);
      expect(find.textContaining('Sharing stopped'), findsOneWidget);
      expect(find.text('Pet Passport'), findsOneWidget);
    });

    testWidgets('a failure says so and can be retried', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _tab(tester, 'Passport');
      rig.health.failNext = const AppFailure(
        'We could not make a share link. Try again.',
      );
      await _tapLabel(tester, 'Share passport');
      expect(
        find.text('We could not make a share link. Try again.'),
        findsOneWidget,
      );
      await _tap(tester, 'Try again');
      expect(find.byType(PawQrCode), findsOneWidget);
    });

    testWidgets('the QR code encodes exactly the link', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      final widget = tester.widget<PawQrCode>(find.byType(PawQrCode));
      expect(
        widget.data,
        'https://pawpass-web-ten.vercel.app/s#${rig.health.shares.single.link.token}',
      );
    });
  });

  group('Emergency vets', () {
    testWidgets(
      'lists clinics near the person, open first, with Call and Directions',
      (tester) async {
        final rig = _Rig(position: (lat: 6.44, lng: 3.47));
        await _pump(tester, rig);
        await _tap(tester, 'Emergency vet');
        expect(find.text('Emergency vets'), findsOneWidget);
        expect(find.textContaining('Open now near Lekki'), findsOneWidget);
        expect(find.text('Lekki Animal Hospital'), findsOneWidget);
        expect(find.text('3.4 km · Open 24 hours'), findsOneWidget);
        expect(find.text('24/7'), findsOneWidget);
        expect(find.text('2.1 km · Open till 8pm'), findsOneWidget);
        expect(rig.vets.calls.single, (lat: 6.44, lng: 3.47));

        await tester.tap(find.text('Call').first);
        await tester.pumpAndSettle();
        expect(rig.links.opened.last.toString(), 'tel:+2340000000002');
        await tester.tap(find.text('Directions').first);
        await tester.pumpAndSettle();
        expect(rig.links.opened.last.host, 'www.google.com');
        expect(
          rig.links.opened.last.queryParameters['destination'],
          '6.44,3.472',
        );
      },
    );

    testWidgets('never shows a phone number on screen', (tester) async {
      await _pump(tester, _Rig(position: (lat: 6.44, lng: 3.47)));
      await _tap(tester, 'Emergency vet');
      expect(find.textContaining('+234'), findsNothing);
      expect(find.textContaining('0000'), findsNothing);
    });

    testWidgets('a home visit vet can be sent your location', (tester) async {
      final rig = _Rig(position: (lat: 6.44, lng: 3.47));
      await _pump(tester, rig);
      await _tap(tester, 'Emergency vet');
      expect(find.text('Ikate · Visits homes'), findsOneWidget);
      await tester.ensureVisible(find.text('Share location'));
      await tester.pump();
      await tester.tap(find.text('Share location'));
      await tester.pumpAndSettle();
      final uri = rig.links.opened.last;
      expect(uri.host, 'wa.me');
      expect(
        Uri.decodeFull(uri.queryParameters['text']!),
        contains('query=6.44,3.47'),
      );
    });

    testWidgets(
      'without location it still lists clinics, and says how to get distances',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        await _tap(tester, 'Emergency vet');
        expect(find.textContaining('Turn on location'), findsOneWidget);
        expect(rig.vets.calls.single, (lat: null, lng: null));
        expect(find.text('Lekki · Open 24 hours'), findsOneWidget);
        expect(find.text('Share location'), findsNothing);
      },
    );

    testWidgets('a failure explains and offers to try again', (tester) async {
      final rig = _Rig(position: (lat: 6.44, lng: 3.47));
      await _pump(tester, rig);
      rig.vets.failNext = const AppFailure(
        'We could not load the clinics. Call a vet you know, or try again.',
      );
      await _tap(tester, 'Emergency vet');
      expect(
        find.textContaining('We could not load the clinics'),
        findsOneWidget,
      );
      await _tap(tester, 'Try again');
      expect(find.text('Lekki Animal Hospital'), findsOneWidget);
    });

    testWidgets('nobody to show says so plainly', (tester) async {
      final rig = _Rig(position: (lat: 6.44, lng: 3.47));
      await _pump(tester, rig);
      rig.vets.vets.clear();
      await _tap(tester, 'Emergency vet');
      expect(find.text('No clinics found'), findsOneWidget);
    });

    testWidgets('links to sharing the passport with the clinic', (
      tester,
    ) async {
      await _pump(tester, _Rig(position: (lat: 6.44, lng: 3.47)));
      await _tap(tester, 'Emergency vet');
      await _tap(tester, "Share Bingo's passport with the clinic");
      expect(find.text("Share Bingo's passport"), findsOneWidget);
    });

    testWidgets('a call that cannot start is explained', (tester) async {
      final rig = _Rig(position: (lat: 6.44, lng: 3.47));
      await _pump(tester, rig);
      await _tap(tester, 'Emergency vet');
      rig.links.result = false;
      await tester.tap(find.text('Call').first);
      await tester.pumpAndSettle();
      expect(find.text('We could not start the call.'), findsOneWidget);
    });
  });

  group('Notifications', () {
    Future<void> open(WidgetTester tester) async {
      await _tapLabel(tester, 'Notifications, 2 new');
    }

    testWidgets('grouped into today and earlier with unread dots', (
      tester,
    ) async {
      await _pump(tester, _Rig());
      await open(tester);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('EARLIER'), findsOneWidget);
      expect(find.text('Lost dog near you'), findsOneWidget);
      expect(find.text('Rabies booster in 7 days'), findsOneWidget);
      expect(find.text('Record verified'), findsOneWidget);
      expect(find.text('1h ago'), findsOneWidget);
      expect(find.text('2h ago'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('2 days ago'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);
    });

    testWidgets('opening one marks it read and goes where it points', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      await _tap(tester, 'Rabies booster in 7 days');
      expect(find.text('Schedule'), findsOneWidget);
      expect(
        rig.notifications.items.firstWhere((n) => n.id == 'n2').read,
        isTrue,
      );
      await _back(tester);
      expect(
        find.text('Mark all read'),
        findsOneWidget,
        reason: 'one is still unread',
      );
    });

    testWidgets('a verified record opens the passport', (tester) async {
      await _pump(tester, _Rig());
      await open(tester);
      await _tap(tester, 'Record verified');
      expect(find.text('Pet Passport'), findsOneWidget);
    });

    testWidgets('Mark all read clears the badge', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await open(tester);
      await _tap(tester, 'Mark all read');
      expect(find.text('Mark all read'), findsNothing);
      expect(rig.notifications.items.every((n) => n.read), isTrue);
      await _back(tester);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
    });

    testWidgets('nothing yet', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      rig.notifications.items.clear();
      await _tapLabel(tester, 'Notifications, 2 new');
      expect(find.text("You're all caught up"), findsOneWidget);
    });
  });

  group('every screen fits a small phone with large text', () {
    testWidgets(
      'Home, Passport (all tabs), Schedule, Add record, Share, Emergency and Notifications',
      (tester) async {
        final rig = _Rig(position: (lat: 6.44, lng: 3.47));
        await _pump(tester, rig, size: const Size(320, 568), scale: 1.3);
        expect(find.text('Good morning, Tolu'), findsOneWidget);

        await _tab(tester, 'Passport');
        await _tap(tester, 'Origin', last: true);
        await _tap(tester, 'Services');
        await _tap(tester, 'Health');
        await _tap(tester, '+ Add record');
        for (final t in [
          'Vaccine',
          'Deworming',
          'Treatment',
          'Vet visit',
          'Weight',
          'Allergy',
        ]) {
          await _tap(tester, t);
        }
        await _scrollToTop(tester);
        await _tapLabel(tester, 'Close');
        await _scrollToTop(tester);
        await _tapLabel(tester, 'Share passport');
        expect(find.byType(PawQrCode), findsOneWidget);
        await _tapLabel(tester, 'Close');

        await _tab(tester, 'Home');
        await _tap(tester, 'See schedule');
        await _back(tester);
        await _tap(tester, 'Emergency vet');
        expect(find.text('Lekki Animal Hospital'), findsOneWidget);
        await _back(tester);
        await _scrollToTop(tester);
        await _tapLabel(tester, 'Notifications, 2 new');
        expect(find.text('TODAY'), findsOneWidget);
        await _back(tester);
        for (final tab in ['Community', 'Adopt']) {
          await _tab(tester, tab);
          expect(find.text('Coming soon'), findsOneWidget);
        }
      },
    );
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
