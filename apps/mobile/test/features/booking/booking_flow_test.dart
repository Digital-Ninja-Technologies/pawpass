import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/booking/domain/models.dart';
import 'package:pawpass/features/booking/ui/booking_widgets.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/health/ui/health_widgets.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/ui/ui.dart';

final _today = DateTime.utc(2026, 11, 5, 8); // 9am in Lagos

class _Rig {
  _Rig() {
    profiles = InMemoryProfileRepository();
    bookings = InMemoryBookingsRepository(now: () => _today);
    payments = InMemoryPaymentsRepository(bookings);
    links = FakeLinkLauncher();
    photos = NoPhotoPicker();
    services = AppServices(
      auth: InMemoryAuthRepository(signedInAs: 'tolu@example.com'),
      profiles: profiles,
      pets: pets = InMemoryPetRepository(profiles: profiles, now: () => _today),
      photos: photos,
      emailApp: NoEmailApp(),
      health: InMemoryHealthRepository(now: () => _today),
      notifications: InMemoryNotificationsRepository(),
      vets: InMemoryVetsRepository(),
      location: FakeLocationService(),
      links: links,
      bookings: bookings,
      payments: payments,
      now: () => _today,
    );
  }

  late final InMemoryProfileRepository profiles;
  late final InMemoryPetRepository pets;
  late final InMemoryBookingsRepository bookings;
  late final InMemoryPaymentsRepository payments;
  late final FakeLinkLauncher links;
  late final NoPhotoPicker photos;
  late final AppServices services;
  late Pet bingo;
  late Pet mimi;

  Future<void> seed() async {
    await profiles.save(
      firstName: 'Tolu',
      lastName: 'Adeyemi',
      area: 'Lekki Phase 1',
    );
    profiles.markOnboarded(_today);
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
    bookings.knowPets([bingo, mimi]);
  }

  /// A paid booking at Glam Paws Grooming for Mimi, optionally already started or marked done.
  Future<String> groom({
    bool started = false,
    bool done = false,
    int day = 2,
  }) async {
    final intent = await bookings.createBooking(
      serviceId: 's6',
      petId: mimi.id,
      startsAt: bookings.at(day, 14),
    );
    bookings.markPaid(intent.reference);
    if (started) bookings.startVisit(intent.bookingId, providerDone: done);
    return intent.bookingId;
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
  final f = find.bySemanticsLabel(label).first;
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

Future<void> _openBookings(WidgetTester tester) async {
  await _tab(tester, 'Book');
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'RoundIconButton',
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Services', () {
    testWidgets(
      'lists verified vets with rating, distance, next time and price',
      (tester) async {
        await _pump(tester, _Rig());
        await _tab(tester, 'Book');
        expect(find.text('Book care'), findsOneWidget);
        expect(find.text('Lekki Phase 1'), findsOneWidget);
        expect(find.text('VERIFIED VETS NEAR YOU'), findsOneWidget);
        expect(find.text('Paws & Claws Vet Clinic'), findsOneWidget);
        expect(find.text('Lekki Animal Hospital'), findsOneWidget);
        expect(find.text('Emergency? Show clinics open now'), findsOneWidget);
        expect(find.textContaining('★ 4.8 (126)'), findsOneWidget);
        expect(find.textContaining('Next: Today 10am'), findsWidgets);
        expect(find.text('from ₦10,000'), findsOneWidget);
      },
    );

    testWidgets('categories change the list', (tester) async {
      await _pump(tester, _Rig());
      await _tab(tester, 'Book');
      await _tap(tester, 'Grooming');
      expect(find.text('Glam Paws Grooming'), findsOneWidget);
      expect(find.text('Paws & Claws Vet Clinic'), findsNothing);
      await _tap(tester, 'Boarding');
      expect(find.text('Nobody found'), findsOneWidget);
    });

    testWidgets('searching by name', (tester) async {
      await _pump(tester, _Rig());
      await _tab(tester, 'Book');
      await tester.enterText(find.byType(TextField).first, 'amina');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Dr. Amina Bello'), findsOneWidget);
      expect(find.text('Lekki Animal Hospital'), findsNothing);
    });

    testWidgets('the emergency banner opens the emergency screen', (
      tester,
    ) async {
      await _pump(tester, _Rig());
      await _tab(tester, 'Book');
      await _tap(tester, 'Emergency? Show clinics open now');
      expect(find.text('Emergency vets'), findsOneWidget);
    });

    testWidgets('a load failure offers to try again', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      rig.bookings.failNextLoad = const AppFailure(
        'No connection. Check your internet and try again.',
      );
      await _tab(tester, 'Book');
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      await _tap(tester, 'Try again');
      expect(find.text('Paws & Claws Vet Clinic'), findsOneWidget);
    });
  });

  group('Booking a visit', () {
    Future<void> openClinic(WidgetTester tester) async {
      await _tab(tester, 'Book');
      await _tap(tester, 'Paws & Claws Vet Clinic');
    }

    testWidgets('shows the provider, its services, days and times', (
      tester,
    ) async {
      await _pump(tester, _Rig());
      await openClinic(tester);
      expect(find.text('Book Paws & Claws Vet Clinic'), findsOneWidget);
      expect(find.text('Vaccination (rabies)'), findsOneWidget);
      expect(find.text('₦15,000'), findsOneWidget);
      expect(find.text('Consultation'), findsOneWidget);
      expect(find.text('Full check-up'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Choose a service and time'), findsOneWidget);
      expect(
        find.textContaining('Payment held safely until your visit is done'),
        findsOneWidget,
      );
    });

    testWidgets('pay stays off until a service and a time are chosen', (
      tester,
    ) async {
      await _pump(tester, _Rig());
      await openClinic(tester);
      PawButton pay() => tester.widget<PawButton>(find.byType(PawButton).last);
      expect(pay().onPressed, isNull);
      await _tap(tester, 'Vaccination (rabies)');
      expect(pay().onPressed, isNull);
      await _tap(tester, '2:00');
      expect(pay().onPressed, isNotNull);
      expect(pay().label, 'Pay ₦15,000 & book · Thu 2pm');
    });

    testWidgets('a time that is taken cannot be chosen', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      final intent = await rig.bookings.createBooking(
        serviceId: 's2',
        petId: rig.mimi.id,
        startsAt: rig.bookings.at(0, 14),
      );
      rig.bookings.markPaid(intent.reference);
      await openClinic(tester);
      expect(find.bySemanticsLabel('2pm, taken'), findsOneWidget);
      await tester.tap(find.text('2:00'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a service and time'), findsOneWidget);
    });

    testWidgets('with two pets you choose who it is for', (tester) async {
      await _pump(tester, _Rig());
      await openClinic(tester);
      await tester.scrollUntilVisible(
        find.text('WHO IS IT FOR'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('WHO IS IT FOR'), findsOneWidget);
    });

    testWidgets('pay, come back, and you are booked', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await openClinic(tester);
      await _tap(tester, 'Vaccination (rabies)');
      await _tap(tester, '4:00');
      await _tap(tester, 'Pay ₦15,000 & book · Thu 4pm');
      expect(rig.links.opened.single.host, 'checkout.paystack.com');
      expect(
        find.textContaining('Finish paying on the Paystack page'),
        findsOneWidget,
      );
      expect(find.text("I've paid"), findsOneWidget);

      await _tap(tester, "I've paid");
      expect(find.text("You're booked"), findsOneWidget);
      expect(find.text('Paws & Claws Vet Clinic'), findsOneWidget);
      expect(find.text('Vaccination (rabies)'), findsOneWidget);
      expect(find.text('Thu 5 Nov · 4pm'), findsOneWidget);
      expect(find.text('Bingo'), findsOneWidget);
      expect(find.text('₦15,000'), findsOneWidget);
      expect(
        find.textContaining('held until you confirm the visit'),
        findsOneWidget,
      );
    });

    testWidgets('payment not received yet keeps the person on the page', (
      tester,
    ) async {
      final rig = _Rig()..payments.outcome = PaymentOutcome.pending;
      await _pump(tester, rig);
      await openClinic(tester);
      await _tap(tester, 'Vaccination (rabies)');
      await _tap(tester, '4:00');
      await _tap(tester, 'Pay ₦15,000 & book · Thu 4pm');
      await _tap(tester, "I've paid");
      expect(
        find.textContaining('not received your payment yet'),
        findsOneWidget,
      );
      expect(find.text("You're booked"), findsNothing);
    });

    testWidgets('cancelling the payment returns to the form', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await openClinic(tester);
      await _tap(tester, 'Vaccination (rabies)');
      await _tap(tester, '4:00');
      await _tap(tester, 'Pay ₦15,000 & book · Thu 4pm');
      await _tap(tester, 'Cancel this booking');
      expect(find.text("I've paid"), findsNothing);
      expect(find.text('Pay ₦15,000 & book · Thu 4pm'), findsOneWidget);
    });

    testWidgets('a payment error is shown and can be retried', (tester) async {
      final rig = _Rig()
        ..payments.failNextStart = const AppFailure(
          'We could not open the payment page. Please try again.',
        );
      await _pump(tester, rig);
      await openClinic(tester);
      await _tap(tester, 'Vaccination (rabies)');
      await _tap(tester, '4:00');
      await _tap(tester, 'Pay ₦15,000 & book · Thu 4pm');
      expect(
        find.text('We could not open the payment page. Please try again.'),
        findsOneWidget,
      );
      await _tap(tester, 'Pay ₦15,000 & book · Thu 4pm');
      expect(find.text("I've paid"), findsOneWidget);
    });

    testWidgets(
      'Booked: calendar and directions open outside the app, then to bookings',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        await openClinic(tester);
        await _tap(tester, 'Vaccination (rabies)');
        await _tap(tester, '4:00');
        await _tap(tester, 'Pay ₦15,000 & book · Thu 4pm');
        await _tap(tester, "I've paid");
        rig.links.opened.clear();
        await _tap(tester, 'Add to calendar');
        expect(rig.links.opened.single.host, 'calendar.google.com');
        expect(
          rig.links.opened.single.queryParameters['text'],
          'Vaccination (rabies) at Paws & Claws Vet Clinic',
        );
        await _tap(tester, 'Directions');
        expect(rig.links.opened.last.host, 'www.google.com');
        await _tap(tester, 'View my bookings');
        expect(find.text('My bookings'), findsOneWidget);
        expect(find.text('Upcoming (1)'), findsOneWidget);
        expect(find.text('Vaccination (rabies) for Bingo'), findsOneWidget);
      },
    );
  });

  group('My bookings', () {
    testWidgets('upcoming booking: held money, cancel with a confirmation', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await rig.groom();
      await _openBookings(tester);
      expect(find.text('Upcoming (1)'), findsOneWidget);
      expect(find.text('Full groom for Mimi'), findsOneWidget);
      expect(find.text('₦12,000 held'), findsOneWidget);
      await _tap(tester, 'Cancel');
      expect(find.text('Cancel this booking?'), findsOneWidget);
      await _tap(tester, 'Keep booking');
      expect(find.text('Full groom for Mimi'), findsOneWidget);
      await _tap(tester, 'Cancel');
      await _tap(tester, 'Cancel booking');
      expect(find.text('Nothing booked'), findsOneWidget);
      await _tap(tester, 'Past');
      expect(find.text('Cancelled, ₦12,000 refunded'), findsOneWidget);
      expect(find.text('Book again'), findsOneWidget);
    });

    testWidgets('inside the last two hours there is no cancel button', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      final intent = await rig.bookings.createBooking(
        serviceId: 's6',
        petId: rig.mimi.id,
        startsAt: rig.bookings.at(0, 10),
      );
      rig.bookings.markPaid(intent.reference);
      await _openBookings(tester);
      expect(find.text('Full groom for Mimi'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('a finished visit needs the owner: confirm and rate', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await rig.groom(started: true, done: true);
      await _openBookings(tester);
      expect(find.text('Needs your action'), findsOneWidget);
      expect(
        find.text('₦12,000 waiting for your confirmation'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsNothing);
      await _tap(tester, 'Confirm visit & rate');
      expect(find.text('Rate and review'), findsOneWidget);
      expect(find.text("How was Mimi's full groom?"), findsOneWidget);
      expect(find.text('Confirm visit & release ₦12,000'), findsOneWidget);
    });

    testWidgets('empty states', (tester) async {
      await _pump(tester, _Rig());
      await _openBookings(tester);
      expect(find.text('Nothing booked'), findsOneWidget);
      await _tap(tester, 'Past');
      expect(find.text('No past bookings'), findsOneWidget);
    });
  });

  group('Review', () {
    testWidgets('rating, tags and a note release the payment', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      final id = await rig.groom(started: true, done: true);
      await _openBookings(tester);
      await _tap(tester, 'Confirm visit & rate');
      expect(find.text('Tap a star (optional)'), findsOneWidget);
      await _tapLabel(tester, '4 of 5 stars');
      expect(find.text('Great'), findsOneWidget);
      await _tap(tester, 'On time');
      await _tap(tester, 'Gentle');
      await tester.enterText(
        find.byType(TextField),
        'Mimi came back fluffy and calm.',
      );
      await _tap(tester, 'Confirm visit & release ₦12,000');
      expect(find.text('My bookings'), findsOneWidget);
      expect(
        find.text('Thank you. The payment has been released.'),
        findsOneWidget,
      );
      final review = (await rig.bookings.reviews('p4')).single;
      expect(review.rating, 4);
      expect(review.tags, ['On time', 'Gentle']);
      expect(review.body, 'Mimi came back fluffy and calm.');
      expect(
        (await rig.bookings.myBookings()).single.escrow,
        EscrowStatus.ready,
      );
      expect(id, isNotEmpty);
      await tester.pump(const Duration(seconds: 5));
      await _tap(tester, 'Past');
      expect(find.text('You rated ★★★★'), findsOneWidget);
    });

    testWidgets('a rating is optional', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await rig.groom(started: true);
      await _openBookings(tester);
      await _tap(tester, 'Confirm visit & rate');
      await _tap(tester, 'Confirm visit & release ₦12,000');
      expect(await rig.bookings.reviews('p4'), isEmpty);
      expect(
        (await rig.bookings.myBookings()).single.status,
        BookingStatus.completed,
      );
    });

    testWidgets('an error is shown and the person can try again', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await rig.groom(started: true);
      await _openBookings(tester);
      await _tap(tester, 'Confirm visit & rate');
      rig.bookings.failNextConfirm = const AppFailure(
        'No connection. Check your internet and try again.',
      );
      await _tap(tester, 'Confirm visit & release ₦12,000');
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      expect(find.text('Rate and review'), findsOneWidget);
      await _tap(tester, 'Confirm visit & release ₦12,000');
      expect(find.text('Rate and review'), findsNothing);
    });
  });

  group('Report a problem', () {
    Future<void> openDispute(WidgetTester tester, _Rig rig) async {
      await _pump(tester, rig);
      await rig.groom(started: true, done: true);
      await _openBookings(tester);
      await _tap(tester, 'Confirm visit & rate');
      await _tap(tester, 'Something went wrong');
    }

    testWidgets('from the review screen, with the four reasons', (
      tester,
    ) async {
      await openDispute(tester, _Rig());
      expect(find.text('Report a problem'), findsWidgets);
      for (final r in DisputeReason.values) {
        expect(find.text(r.label), findsOneWidget);
      }
      expect(find.textContaining('₦12,000 stays on hold'), findsOneWidget);
      expect(find.textContaining('decides within 72 hours'), findsOneWidget);
    });

    testWidgets('send needs a reason, then holds the money', (tester) async {
      final rig = _Rig();
      await openDispute(tester, rig);
      PawButton send() => tester.widget<PawButton>(find.byType(PawButton).last);
      expect(send().onPressed, isNull);
      await _tap(tester, 'My pet was hurt or got sick');
      expect(send().onPressed, isNotNull);
      await tester.enterText(
        find.byType(TextField),
        'Mimi has a small cut near her ear.',
      );
      await _tap(tester, 'Send to PawPass');
      expect(find.text('My bookings'), findsOneWidget);
      expect(find.text('Under review'), findsOneWidget);
      expect(
        find.textContaining('on hold while PawPass reviews'),
        findsOneWidget,
      );
      expect(find.textContaining('PawPass decides by'), findsOneWidget);
      expect(rig.bookings.disputes.single.reason, DisputeReason.hurtOrSick);
      expect(
        rig.bookings.disputes.single.details,
        'Mimi has a small cut near her ear.',
      );
      expect(
        (await rig.bookings.myBookings()).single.escrow,
        EscrowStatus.paused,
      );
      expect(find.text('Confirm visit & rate'), findsNothing);
    });

    testWidgets('photos can be added and removed, up to five', (tester) async {
      final rig = _Rig();
      rig.photos.next = PickedPhoto(Uint8List.fromList(List.filled(8, 1)));
      await openDispute(tester, rig);
      for (var i = 0; i < 5; i++) {
        await tester.ensureVisible(find.byKey(const Key('add-photo')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('add-photo')));
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const Key('add-photo')),
        findsNothing,
        reason: 'five is the limit',
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RoundIconButton && w.semanticLabel == 'Remove photo 1',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-photo')), findsOneWidget);
      await _tap(tester, 'Something else');
      await _tap(tester, 'Send to PawPass');
      expect(rig.bookings.disputes.single.photos, 4);
    });

    testWidgets('a failure keeps the form and says why', (tester) async {
      final rig = _Rig();
      await openDispute(tester, rig);
      rig.bookings.failNextDispute = const AppFailure(
        'No connection. Check your internet and try again.',
      );
      await _tap(tester, 'Something else');
      await _tap(tester, 'Send to PawPass');
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      expect(find.text('Send to PawPass'), findsOneWidget);
    });

    testWidgets('reachable from a booking card after the visit', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      final id = await rig.groom(started: true, done: true);
      await rig.bookings.confirmVisit(id);
      await _openBookings(tester);
      await _tap(tester, 'Past');
      await _tap(tester, 'Report a problem');
      expect(find.text('What went wrong?'), findsOneWidget);
    });
  });

  group('every screen fits a small phone with large text', () {
    testWidgets(
      'Services, Provider (form and waiting), Booked, Bookings, Review, Report',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig, size: const Size(320, 568), scale: 1.3);
        await rig.groom(started: true, done: true, day: 3);
        await rig.groom(day: 4);

        await _tab(tester, 'Book');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Paws & Claws Vet Clinic');
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Vaccination (rabies)'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await _tap(tester, 'Vaccination (rabies)');
        await tester.scrollUntilVisible(
          find.text('4:00'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await _tap(tester, '4:00');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Pay ₦15,000 & book · Thu 4pm');
        expect(tester.takeException(), isNull);
        await _tap(tester, "I've paid");
        expect(tester.takeException(), isNull);
        expect(find.text("You're booked"), findsOneWidget);
        await _tap(tester, 'View my bookings');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Confirm visit & rate');
        expect(tester.takeException(), isNull);
        await _tapLabel(tester, '5 of 5 stars');
        await _tap(tester, 'Something went wrong');
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Something else'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await _tap(tester, 'Something else');
        expect(tester.takeException(), isNull);
      },
    );
  });

  test('the star row labels each star', () {
    expect(ratingWord(5), 'Excellent');
    expect(const StarRow(value: 3).value, 3);
  });
}
