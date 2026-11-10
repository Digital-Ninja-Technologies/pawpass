import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/booking/domain/booking_logic.dart';
import 'package:pawpass/features/booking/domain/models.dart';

/// 4:30pm in Lagos on Thu 5 Nov 2026 is 15:30 UTC.
final _now = DateTime.utc(2026, 11, 5, 8); // 9am in Lagos

Booking _b({
  BookingStatus status = BookingStatus.confirmed,
  EscrowStatus? escrow = EscrowStatus.held,
  DateTime? startsAt,
  DateTime? cancelUntil,
  int? rating,
  int amountKobo = 1200000,
}) => Booking(
  id: 'b',
  status: status,
  startsAt: startsAt ?? DateTime.utc(2026, 11, 5, 15, 30),
  serviceName: 'Full groom',
  amountKobo: amountKobo,
  partnerId: 'p',
  partnerName: 'Glam Paws Grooming',
  petId: 'pet',
  petName: 'Mimi',
  escrow: escrow,
  rating: rating,
  canCancelUntil: cancelUntil,
);

void main() {
  group('escrow state machine (mirrors the database)', () {
    const allowed = {
      (EscrowStatus.held, EscrowStatus.ready),
      (EscrowStatus.held, EscrowStatus.paused),
      (EscrowStatus.held, EscrowStatus.refunded),
      (EscrowStatus.ready, EscrowStatus.paused),
      (EscrowStatus.ready, EscrowStatus.released),
      (EscrowStatus.paused, EscrowStatus.ready),
      (EscrowStatus.paused, EscrowStatus.refunded),
      (EscrowStatus.paused, EscrowStatus.partiallyRefunded),
    };

    test('exactly the eight allowed moves, out of all 36 pairs', () {
      var checked = 0;
      for (final from in EscrowStatus.values) {
        for (final to in EscrowStatus.values) {
          if (from == to) continue;
          checked++;
          expect(
            escrowCanMove(from, to),
            allowed.contains((from, to)),
            reason: '$from -> $to',
          );
        }
      }
      expect(checked, 30);
    });

    test('money that is paid out or sent back never moves again', () {
      for (final end in [
        EscrowStatus.released,
        EscrowStatus.refunded,
        EscrowStatus.partiallyRefunded,
      ]) {
        for (final to in EscrowStatus.values) {
          expect(escrowCanMove(end, to), isFalse, reason: '$end -> $to');
        }
      }
    });

    test('a booking cannot skip payment or come back from cancelled', () {
      expect(
        bookingCanMove(BookingStatus.pendingPayment, BookingStatus.completed),
        isFalse,
      );
      expect(
        bookingCanMove(BookingStatus.cancelled, BookingStatus.confirmed),
        isFalse,
      );
      expect(
        bookingCanMove(BookingStatus.completed, BookingStatus.cancelled),
        isFalse,
      );
      expect(
        bookingCanMove(BookingStatus.confirmed, BookingStatus.disputed),
        isTrue,
      );
      expect(
        bookingCanMove(BookingStatus.disputed, BookingStatus.completed),
        isTrue,
      );
    });
  });

  group('which list a booking is in', () {
    test('a future confirmed booking is upcoming', () {
      expect(groupOf(_b(), _now), BookingGroup.upcoming);
    });

    test('a confirmed booking whose time has come needs the owner', () {
      expect(
        groupOf(_b(startsAt: _now.subtract(const Duration(hours: 1))), _now),
        BookingGroup.needsAction,
      );
    });

    test('the provider marking it done needs the owner', () {
      expect(
        groupOf(_b(status: BookingStatus.completedAwaitingOwner), _now),
        BookingGroup.needsAction,
      );
    });

    test('finished and cancelled bookings are past; disputes stay up top', () {
      expect(
        groupOf(_b(status: BookingStatus.completed), _now),
        BookingGroup.past,
      );
      expect(
        groupOf(_b(status: BookingStatus.cancelled), _now),
        BookingGroup.past,
      );
      expect(
        groupOf(_b(status: BookingStatus.disputed), _now),
        BookingGroup.upcoming,
      );
    });
  });

  group('what the owner may do', () {
    test('cancel is free until the cut off, then gone', () {
      final cut = DateTime.utc(2026, 11, 5, 13, 30);
      expect(canCancel(_b(cancelUntil: cut), _now), isTrue);
      expect(canCancel(_b(cancelUntil: cut), cut), isTrue);
      expect(
        canCancel(_b(cancelUntil: cut), cut.add(const Duration(minutes: 1))),
        isFalse,
      );
      expect(
        canCancel(_b(status: BookingStatus.completed, cancelUntil: cut), _now),
        isFalse,
      );
    });

    test('confirm only once the visit has started', () {
      expect(canConfirm(_b(), _now), isFalse);
      expect(
        canConfirm(
          _b(startsAt: _now.subtract(const Duration(minutes: 5))),
          _now,
        ),
        isTrue,
      );
    });

    test('report a problem only while the money is still with OurPawPass', () {
      final started = _now.subtract(const Duration(hours: 1));
      expect(canReport(_b(), _now), isFalse, reason: 'not started');
      expect(canReport(_b(startsAt: started), _now), isTrue);
      expect(
        canReport(
          _b(status: BookingStatus.completed, escrow: EscrowStatus.ready),
          _now,
        ),
        isTrue,
      );
      for (final e in [
        EscrowStatus.released,
        EscrowStatus.refunded,
        EscrowStatus.paused,
        EscrowStatus.partiallyRefunded,
      ]) {
        expect(
          canReport(_b(status: BookingStatus.completed, escrow: e), _now),
          isFalse,
          reason: '$e',
        );
      }
    });
  });

  group('words and times in Lagos time', () {
    final t = DateTime.utc(2026, 11, 5, 15, 30); // 4:30pm Lagos

    test('time and day', () {
      expect(timeLabel(t), '4:30pm');
      expect(timeLabel(DateTime.utc(2026, 11, 5, 9)), '10am');
      expect(timeLabel(DateTime.utc(2026, 11, 5, 11, 0)), '12pm');
      expect(timeLabel(DateTime.utc(2026, 11, 4, 23, 0)), '12am');
      expect(chipTime(t), '4:30');
      expect(chipTime(DateTime.utc(2026, 11, 5, 13)), '2:00');
      expect(dayLabel(t), 'Thu 5 Nov');
      expect(whenLabel(t), 'Thu 5 Nov · 4:30pm');
    });

    test('a late evening UTC time is already tomorrow in Lagos', () {
      expect(dayLabel(DateTime.utc(2026, 11, 5, 23, 30)), 'Fri 6 Nov');
    });

    test('next slot wording', () {
      expect(nextLabel(t, _now), 'Today 4:30pm');
      expect(nextLabel(DateTime.utc(2026, 11, 6, 9), _now), 'Tomorrow 10am');
      expect(nextLabel(DateTime.utc(2026, 11, 7, 8), _now), 'Sat 9am');
    });

    test('money, distance, rating and opening hours', () {
      expect(nairaFromKobo(1500000), '₦15,000');
      expect(fromPrice(1000000), 'from ₦10,000');
      expect(fromPrice(null), '');
      expect(distanceLabel(2100), '2.1 km');
      expect(distanceLabel(850), '850 m');
      expect(distanceLabel(null), '');
      expect(ratingLabel(4.8, 126), '★ 4.8 (126)');
      expect(ratingLabel(null, 0), 'New');
      expect(
        openLabel(const ProviderSummary(id: 'a', name: 'A', open24h: true)),
        'Open 24 hours',
      );
      expect(
        openLabel(
          const ProviderSummary(
            id: 'a',
            name: 'A',
            openNow: true,
            closesAt: '20:00:00',
          ),
        ),
        'Open till 8pm',
      );
      expect(
        openLabel(
          const ProviderSummary(id: 'a', name: 'A', closesAt: '20:00:00'),
        ),
        '',
        reason: 'closed now',
      );
    });

    test('booking lines on the card', () {
      expect(
        escrowLine(_b(startsAt: _now.add(const Duration(days: 1))), _now),
        '₦12,000 held',
      );
      expect(
        escrowLine(_b(startsAt: _now.subtract(const Duration(hours: 1))), _now),
        '₦12,000 waiting for your confirmation',
      );
      expect(
        escrowLine(_b(status: BookingStatus.completed, rating: 5), _now),
        'You rated ★★★★★',
      );
      expect(
        escrowLine(
          _b(status: BookingStatus.cancelled, escrow: EscrowStatus.refunded),
          _now,
        ),
        'Cancelled, ₦12,000 refunded',
      );
      expect(
        escrowLine(
          _b(status: BookingStatus.disputed, escrow: EscrowStatus.paused),
          _now,
        ),
        '₦12,000 on hold while OurPawPass reviews',
      );
    });
  });

  group('picking a time', () {
    test('groups by Lagos day, drops the past, keeps full times visible', () {
      final slots = [
        Slot(
          startsAt: DateTime.utc(2026, 11, 5, 7),
          endsAt: DateTime.utc(2026, 11, 5, 8),
          free: 1,
        ),
        Slot(
          startsAt: DateTime.utc(2026, 11, 5, 13),
          endsAt: DateTime.utc(2026, 11, 5, 14),
          free: 1,
        ),
        Slot(
          startsAt: DateTime.utc(2026, 11, 5, 15, 30),
          endsAt: DateTime.utc(2026, 11, 5, 16),
          free: 0,
        ),
        Slot(
          startsAt: DateTime.utc(2026, 11, 6, 9),
          endsAt: DateTime.utc(2026, 11, 6, 10),
          free: 1,
        ),
      ];
      final days = groupSlots(slots, _now);
      expect(days.length, 2);
      expect(days.first.slots.length, 2);
      expect(days.first.slots.first.startsAt.hour, 13);
      expect(days.first.hasFree, isTrue);
      expect(days.last.day, DateTime.utc(2026, 11, 6));
    });

    test('a day with every time taken is not bookable', () {
      final days = groupSlots([
        Slot(
          startsAt: DateTime.utc(2026, 11, 6, 9),
          endsAt: DateTime.utc(2026, 11, 6, 10),
          free: 0,
        ),
      ], _now);
      expect(days.single.hasFree, isFalse);
    });
  });

  test('rating words', () {
    expect(
      [for (var i = 1; i <= 5; i++) ratingWord(i)],
      ['Poor', 'Fair', 'Good', 'Great', 'Excellent'],
    );
  });
}
