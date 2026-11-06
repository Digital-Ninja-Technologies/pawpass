import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/booking/domain/models.dart';
import 'package:pawpass/features/booking/state/booking_controller.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/state/session_controller.dart';

final _today = DateTime.utc(2026, 11, 5, 8);

class _Rig {
  _Rig() {
    services = inMemoryServices(
      now: () => _today,
      signedInAs: 'tolu@example.com',
    );
    bookings = services.bookings as InMemoryBookingsRepository;
    payments = services.payments as InMemoryPaymentsRepository;
    session = SessionController(services);
    c = BookingController(services, session);
  }

  late final AppServices services;
  late final InMemoryBookingsRepository bookings;
  late final InMemoryPaymentsRepository payments;
  late final SessionController session;
  late final BookingController c;

  /// Opens the clinic, picks a service and the first free time at least five hours away, and chooses a pet.
  Future<void> ready({String provider = 'p1', String service = 's2'}) async {
    await c.openProvider(provider);
    c.chooseService(service);
    c.chooseSlot(
      c.slots.firstWhere(
        (s) =>
            s.isFree &&
            s.startsAt.isAfter(_today.add(const Duration(hours: 5))),
      ),
    );
    c.choosePet('pet1');
  }

  /// Pays and gets the booking confirmed, returning its id.
  Future<String> booked() async {
    await ready();
    await c.pay();
    await c.checkPayment();
    return c.booked!.bookingId;
  }
}

void main() {
  test('lists providers by category and search words', () async {
    final r = _Rig();
    await r.c.loadProviders();
    expect(
      r.c.providers.map((p) => p.name),
      containsAll(['Paws & Claws Vet Clinic', 'Lekki Animal Hospital']),
    );
    expect(
      r.c.providers.every((p) => p.categories.contains(ServiceCategory.vet)),
      isTrue,
    );

    await r.c.setCategory(ServiceCategory.grooming);
    expect(r.c.providers.single.name, 'Glam Paws Grooming');

    await r.c.setCategory(ServiceCategory.vet);
    await r.c.search('amina');
    expect(r.c.providers.single.name, 'Dr. Amina Bello');
    await r.c.search('vaccination');
    expect(r.c.providers.single.name, 'Paws & Claws Vet Clinic');
    await r.c.search('zzz');
    expect(r.c.providers, isEmpty);
  });

  test('a load failure is kept so the screen can offer to retry', () async {
    final r = _Rig();
    r.bookings.failNextLoad = const AppFailure('No connection.');
    await r.c.loadProviders();
    expect(r.c.providersError, 'No connection.');
    await r.c.loadProviders();
    expect(r.c.providersError, isNull);
    expect(r.c.providers, isNotEmpty);
  });

  test(
    'providers are nearest first when the phone shares its location',
    () async {
      final r = _Rig();
      (r.services.location as FakeLocationService).position = (
        lat: 6.45,
        lng: 3.47,
      );
      await r.c.loadProviders();
      final d = [for (final p in r.c.providers) p.distanceM ?? 1 << 30];
      expect(d, [...d]..sort());
    },
  );

  test('you cannot pay until a service, a time and a pet are chosen', () async {
    final r = _Rig();
    await r.c.openProvider('p1');
    expect(r.c.canPay, isFalse);
    r.c.chooseService('s2');
    expect(r.c.canPay, isFalse);
    r.c.chooseSlot(r.c.slots.firstWhere((s) => s.isFree));
    expect(r.c.canPay, isFalse, reason: 'no pet yet');
    r.c.choosePet('pet1');
    expect(r.c.canPay, isTrue);
  });

  test('a provider with one service has it chosen already', () async {
    final r = _Rig();
    await r.c.openProvider('p4');
    expect(r.c.service?.name, 'Full groom');
  });

  test('full times cannot be chosen', () async {
    final r = _Rig();
    await r.ready();
    final taken = r.c.slot!;
    await r.c.pay();
    await r.c.checkPayment();
    await r.c.openProvider('p1');
    final full = r.c.slots.firstWhere((s) => s.startsAt == taken.startsAt);
    expect(full.isFree, isFalse);
    r.c.chooseSlot(full);
    expect(r.c.slot, isNull);
  });

  group('paying', () {
    test(
      'opens the Paystack page and waits for the person to come back',
      () async {
        final r = _Rig();
        await r.ready();
        await r.c.pay();
        expect(r.c.stage, PayStage.waiting);
        expect(r.payments.started.single, startsWith('pp_'));
        final link = (r.services.links as FakeLinkLauncher).opened.single;
        expect(link.host, 'checkout.paystack.com');
        expect(
          r.c.booked,
          isNull,
          reason: 'not confirmed until the money is checked',
        );
      },
    );

    test('a confirmed payment becomes a booking in the list', () async {
      final r = _Rig();
      final id = await r.booked();
      expect(r.c.stage, PayStage.idle);
      expect(r.c.booked!.serviceName, 'Vaccination (rabies)');
      expect(r.c.booked!.amountKobo, 1500000);
      final b = r.c.bookingById(id)!;
      expect(b.status, BookingStatus.confirmed);
      expect(b.escrow, EscrowStatus.held);
      expect(r.c.upcoming.single.id, id);
    });

    test('not paid yet keeps waiting and says so', () async {
      final r = _Rig();
      r.payments.outcome = PaymentOutcome.pending;
      await r.ready();
      await r.c.pay();
      await r.c.checkPayment();
      expect(r.c.stage, PayStage.waiting);
      expect(r.c.payNotice, contains('not received your payment yet'));
      expect(r.c.booked, isNull);
      // then it arrives
      r.payments.outcome = PaymentOutcome.paid;
      await r.c.checkPayment();
      expect(r.c.booked, isNotNull);
      expect(r.c.payNotice, isNull);
    });

    test(
      'a failed payment says nothing was charged and lets them try again',
      () async {
        final r = _Rig();
        r.payments.outcome = PaymentOutcome.failed;
        await r.ready();
        await r.c.pay();
        await r.c.checkPayment();
        expect(r.c.stage, PayStage.idle);
        expect(r.c.payError, contains('not been charged'));
        expect(r.c.canPay, isTrue);
      },
    );

    test(
      'a time that was just taken shows the message and clears the choice',
      () async {
        final r = _Rig();
        await r.ready();
        final chosen = r.c.slot!;
        // Someone else books it first.
        final other = await r.bookings.createBooking(
          serviceId: 's2',
          petId: 'someone-else',
          startsAt: chosen.startsAt,
        );
        r.bookings.markPaid(other.reference);
        await r.c.pay();
        expect(r.c.payError, 'That time was just taken. Pick another.');
        expect(r.c.stage, PayStage.idle);
        await Future<void>.delayed(Duration.zero);
        expect(r.c.slot, isNull, reason: 'the taken time is deselected');
      },
    );

    test('tapping Pay twice makes one booking', () async {
      final r = _Rig();
      await r.ready();
      final first = r.c.pay();
      final second = r.c.pay();
      await Future.wait([first, second]);
      expect(r.payments.started.length, 1);
    });

    test('failing to start the payment page can be retried', () async {
      final r = _Rig();
      r.payments.failNextStart = const AppFailure('Paystack is down.');
      await r.ready();
      await r.c.pay();
      expect(r.c.payError, 'Paystack is down.');
      expect(r.c.stage, PayStage.idle);
      await r.c.pay();
      expect(r.c.stage, PayStage.waiting);
    });

    test('a phone that cannot open the page says so', () async {
      final r = _Rig();
      (r.services.links as FakeLinkLauncher).result = false;
      await r.ready();
      await r.c.pay();
      expect(r.c.payError, contains('could not open the payment page'));
      expect(r.c.stage, PayStage.idle);
    });

    test('giving up releases the held time', () async {
      final r = _Rig();
      await r.ready();
      final chosen = r.c.slot!;
      await r.c.pay();
      await r.c.abandonPayment();
      expect(r.c.stage, PayStage.idle);
      final again = (await r.bookings.slots('p1'))
          .firstWhere((s) => s.startsAt == chosen.startsAt);
      expect(again.isFree, isTrue);
    });
  });

  group('after the booking', () {
    test('cancelling inside the free window refunds the booking', () async {
      final r = _Rig();
      final id = await r.booked();
      expect(await r.c.cancel(id), isTrue);
      final b = r.c.bookingById(id)!;
      expect(b.status, BookingStatus.cancelled);
      expect(b.escrow, EscrowStatus.refunded);
      expect(r.c.past.single.id, id);
    });

    test('cancelling too late is refused with the reason', () async {
      final r = _Rig();
      final id = await r.booked();
      r.bookings.startVisit(id);
      expect(await r.c.cancel(id), isFalse);
      expect(r.c.actionError, contains('Free cancellation ended 2 hours'));
      expect(r.c.bookingById(id)!.status, BookingStatus.confirmed);
    });

    test(
      'confirming the visit releases the payment and saves the review',
      () async {
        final r = _Rig();
        final id = await r.booked();
        r.bookings.startVisit(id, providerDone: true);
        await r.c.loadBookings();
        expect(r.c.needsAction.single.id, id);
        expect(
          await r.c.confirmVisit(
            id,
            rating: 5,
            tags: ['On time'],
            body: 'Lovely.',
          ),
          isTrue,
        );
        final b = r.c.bookingById(id)!;
        expect(b.status, BookingStatus.completed);
        expect(b.escrow, EscrowStatus.ready);
        expect(b.rating, 5);
        expect((await r.bookings.reviews('p1')).single.body, 'Lovely.');
      },
    );

    test('confirming works without a rating', () async {
      final r = _Rig();
      final id = await r.booked();
      r.bookings.startVisit(id);
      expect(await r.c.confirmVisit(id), isTrue);
      expect(r.c.bookingById(id)!.rating, isNull);
      expect(await r.bookings.reviews('p1'), isEmpty);
    });

    test('a visit that has not started cannot be confirmed', () async {
      final r = _Rig();
      final id = await r.booked();
      expect(await r.c.confirmVisit(id), isFalse);
      expect(r.c.actionError, contains('once the visit has started'));
    });

    test(
      'reporting a problem holds the money and marks the booking disputed',
      () async {
        final r = _Rig();
        final id = await r.booked();
        r.bookings.startVisit(id, providerDone: true);
        expect(
          await r.c.report(
            id,
            reason: DisputeReason.hurtOrSick,
            details: 'A cut near her ear.',
            evidence: [PickedPhoto(Uint8List(3))],
          ),
          isTrue,
        );
        final b = r.c.bookingById(id)!;
        expect(b.status, BookingStatus.disputed);
        expect(b.escrow, EscrowStatus.paused);
        expect(b.disputeDueAt, _today.add(const Duration(hours: 72)));
        expect(r.bookings.disputes.single.photos, 1);
        expect(r.c.upcoming.single.id, id, reason: 'stays on the main list');
      },
    );

    test('after a dispute the owner cannot confirm or cancel', () async {
      final r = _Rig();
      final id = await r.booked();
      r.bookings.startVisit(id, providerDone: true);
      await r.c.report(id, reason: DisputeReason.other);
      expect(await r.c.confirmVisit(id), isFalse);
      expect(await r.c.cancel(id), isFalse);
    });

    test(
      'a failure leaves the booking as it was and shows the message',
      () async {
        final r = _Rig();
        final id = await r.booked();
        r.bookings.failNextCancel = const AppFailure('No connection.');
        expect(await r.c.cancel(id), isFalse);
        expect(r.c.actionError, 'No connection.');
        expect(r.c.busyId, isNull);
        r.c.clearActionError();
        expect(r.c.actionError, isNull);
      },
    );

    test('signing out forgets the bookings', () async {
      final r = _Rig();
      await r.booked();
      r.c.reset();
      expect(r.c.bookings, isEmpty);
      expect(r.c.booked, isNull);
      expect(r.c.providers, isEmpty);
    });
  });
}
