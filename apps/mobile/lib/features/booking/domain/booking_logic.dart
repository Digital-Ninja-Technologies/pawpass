import '../../../core/money.dart';
import 'models.dart';

/// Lagos is UTC+1 all year (no daylight saving), so wall clock time is a fixed shift from UTC.
DateTime lagos(DateTime t) => t.toUtc().add(const Duration(hours: 1));

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "4:30pm", "10am" style times in Lagos time. Exact hours drop the minutes.
String timeLabel(DateTime t) {
  final l = lagos(t);
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute == 0 ? '' : ':${l.minute.toString().padLeft(2, '0')}';
  return '$h$m${l.hour < 12 ? 'am' : 'pm'}';
}

/// Always with minutes: "2:00", "4:30" for the time chips.
String chipTime(DateTime t) {
  final l = lagos(t);
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:${l.minute.toString().padLeft(2, '0')}';
}

/// "Thu 5 Nov"
String dayLabel(DateTime t) {
  final l = lagos(t);
  return '${_weekdays[l.weekday - 1]} ${l.day} ${_months[l.month - 1]}';
}

/// "Thu 5 Nov · 4:30pm"
String whenLabel(DateTime t) => '${dayLabel(t)} · ${timeLabel(t)}';

/// "Today 4:30pm", "Tomorrow 10am", or "Sat 9am".
String nextLabel(DateTime t, DateTime now) {
  final days = lagosDay(t).difference(lagosDay(now)).inDays;
  final time = timeLabel(t);
  if (days == 0) return 'Today $time';
  if (days == 1) return 'Tomorrow $time';
  final l = lagos(t);
  return '${_weekdays[l.weekday - 1]} $time';
}

/// The Lagos calendar day as a UTC midnight.
DateTime lagosDay(DateTime t) {
  final l = lagos(t);
  return DateTime.utc(l.year, l.month, l.day);
}

/// "₦15,000" from kobo.
String nairaFromKobo(int kobo) => formatNaira(kobo / 100);

/// "from ₦10,000"
String fromPrice(int? kobo) =>
    kobo == null ? '' : 'from ${nairaFromKobo(kobo)}';

/// "2.1 km" or "850 m".
String distanceLabel(int? metres) {
  if (metres == null) return '';
  if (metres < 1000) return '${(metres / 10).round() * 10} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

/// "Open 24 hours", "Open till 8pm", or "" if unknown or closed now.
String openLabel(ProviderSummary p) {
  if (p.open24h) return 'Open 24 hours';
  final c = p.closesAt;
  if (!p.openNow || c == null) return '';
  final parts = c.split(':');
  final h = int.tryParse(parts.first) ?? 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final hh = h % 12 == 0 ? 12 : h % 12;
  final mm = m == 0 ? '' : ':${m.toString().padLeft(2, '0')}';
  return 'Open till $hh$mm${h < 12 ? 'am' : 'pm'}';
}

/// "★ 4.8 (126)" or "New" when nobody has rated yet.
String ratingLabel(double? avg, int count) =>
    avg == null || count == 0 ? 'New' : '★ ${avg.toStringAsFixed(1)} ($count)';

/// The day strip and the times under it.
class SlotDay {
  const SlotDay(this.day, this.slots);
  final DateTime day;
  final List<Slot> slots;

  bool get hasFree => slots.any((s) => s.isFree);
}

/// Groups bookable times by Lagos calendar day, earliest first. Past times are dropped.
List<SlotDay> groupSlots(List<Slot> slots, DateTime now) {
  final by = <DateTime, List<Slot>>{};
  final cutoff = now.toUtc();
  for (final s in slots) {
    if (!s.startsAt.isAfter(cutoff)) continue;
    by.putIfAbsent(lagosDay(s.startsAt), () => []).add(s);
  }
  final days = by.keys.toList()..sort();
  return [
    for (final d in days)
      SlotDay(d, by[d]!..sort((a, b) => a.startsAt.compareTo(b.startsAt))),
  ];
}

// ---------------------------------------------------------------------------
// Escrow. The database is the source of truth for these rules (see
// supabase/migrations/20261106200000_services_escrow.sql); this mirror lets the app hide buttons that
// could never work and lets tests pin the rules.
// ---------------------------------------------------------------------------

const _escrowMoves = {
  EscrowStatus.held: {
    EscrowStatus.ready,
    EscrowStatus.paused,
    EscrowStatus.refunded,
  },
  EscrowStatus.ready: {EscrowStatus.paused, EscrowStatus.released},
  EscrowStatus.paused: {
    EscrowStatus.ready,
    EscrowStatus.refunded,
    EscrowStatus.partiallyRefunded,
  },
};

bool escrowCanMove(EscrowStatus from, EscrowStatus to) =>
    _escrowMoves[from]?.contains(to) ?? false;

const _bookingMoves = {
  BookingStatus.pendingPayment: {
    BookingStatus.confirmed,
    BookingStatus.cancelled,
  },
  BookingStatus.confirmed: {
    BookingStatus.completedAwaitingOwner,
    BookingStatus.completed,
    BookingStatus.cancelled,
    BookingStatus.disputed,
  },
  BookingStatus.completedAwaitingOwner: {
    BookingStatus.completed,
    BookingStatus.disputed,
  },
  BookingStatus.completed: {BookingStatus.disputed},
  BookingStatus.disputed: {BookingStatus.completed, BookingStatus.cancelled},
};

bool bookingCanMove(BookingStatus from, BookingStatus to) =>
    _bookingMoves[from]?.contains(to) ?? false;

/// Where a booking shows on the Bookings screen.
enum BookingGroup { needsAction, upcoming, past }

BookingGroup groupOf(Booking b, DateTime now) {
  switch (b.status) {
    case BookingStatus.completedAwaitingOwner:
      return BookingGroup.needsAction;
    case BookingStatus.confirmed:
      return b.startsAt.isAfter(now.toUtc())
          ? BookingGroup.upcoming
          : BookingGroup.needsAction;
    case BookingStatus.disputed:
    case BookingStatus.pendingPayment:
      return BookingGroup.upcoming;
    case BookingStatus.completed:
    case BookingStatus.cancelled:
      return BookingGroup.past;
  }
}

/// Free cancellation: only while the booking is confirmed and before the cut off.
bool canCancel(Booking b, DateTime now) {
  if (b.status != BookingStatus.confirmed) return false;
  final until = b.canCancelUntil;
  return until == null
      ? b.startsAt.isAfter(now.toUtc())
      : !now.toUtc().isAfter(until);
}

/// The owner can confirm once the visit has started (or the provider marked it done).
bool canConfirm(Booking b, DateTime now) =>
    groupOf(b, now) == BookingGroup.needsAction;

/// A problem can be reported while the money is still held or ready (not paid out or refunded).
bool canReport(Booking b, DateTime now) {
  final started = b.status == BookingStatus.confirmed
      ? !b.startsAt.isAfter(now.toUtc())
      : b.status == BookingStatus.completedAwaitingOwner ||
            b.status == BookingStatus.completed;
  return started &&
      (b.escrow == EscrowStatus.held || b.escrow == EscrowStatus.ready);
}

/// "₦12,000 held", "waiting for your confirmation", and so on, for the booking card.
String escrowLine(Booking b, DateTime now) {
  final amount = nairaFromKobo(b.amountKobo);
  switch (b.status) {
    case BookingStatus.confirmed:
      return groupOf(b, now) == BookingGroup.needsAction
          ? '$amount waiting for your confirmation'
          : '$amount held';
    case BookingStatus.completedAwaitingOwner:
      return '$amount waiting for your confirmation';
    case BookingStatus.disputed:
      return '$amount on hold while OurPawPass reviews';
    case BookingStatus.completed:
      return b.rating != null
          ? 'You rated ${'★' * b.rating!}'
          : 'Payment released';
    case BookingStatus.cancelled:
      return b.escrow == null ? 'Cancelled' : 'Cancelled, $amount refunded';
    case BookingStatus.pendingPayment:
      return 'Waiting for payment';
  }
}
