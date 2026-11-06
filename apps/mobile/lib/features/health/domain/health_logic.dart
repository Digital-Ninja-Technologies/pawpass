import '../../../core/dates.dart';
import '../../onboarding/domain/models.dart';
import 'models.dart';

// ---------------------------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------------------------

/// Reminders due within this many days (or overdue) get the full card with "Book a vet" and "Mark done".
const soonDays = 14;

class ScheduleGroups {
  const ScheduleGroups({
    required this.overdue,
    required this.thisMonth,
    required this.later,
  });

  /// Past their due date, oldest first.
  final List<Reminder> overdue;

  /// Due in the current calendar month.
  final List<Reminder> thisMonth;

  /// Due after this month.
  final List<Reminder> later;

  bool get isEmpty => overdue.isEmpty && thisMonth.isEmpty && later.isEmpty;
}

/// Splits open reminders into overdue, this month and coming up, each soonest first.
ScheduleGroups groupReminders(List<Reminder> reminders, DateTime today) {
  final open = reminders.where((r) => !r.done).toList()
    ..sort((a, b) => a.dueOn.compareTo(b.dueOn));
  final overdue = <Reminder>[];
  final thisMonth = <Reminder>[];
  final later = <Reminder>[];
  for (final r in open) {
    if (r.dueOn.isBefore(dateOnly(today))) {
      overdue.add(r);
    } else if (r.dueOn.year == today.year && r.dueOn.month == today.month) {
      thisMonth.add(r);
    } else {
      later.add(r);
    }
  }
  return ScheduleGroups(overdue: overdue, thisMonth: thisMonth, later: later);
}

int daysUntil(Reminder r, DateTime today) => daysBetween(today, r.dueOn);

bool isSoon(Reminder r, DateTime today) => daysUntil(r, today) <= soonDays;

/// "in 7 days", "tomorrow", "today", "overdue by 3 days".
String whenText(Reminder r, DateTime today) {
  final d = daysUntil(r, today);
  if (d < 0) return 'overdue by ${-d} ${-d == 1 ? 'day' : 'days'}';
  if (d == 0) return 'today';
  if (d == 1) return 'tomorrow';
  return 'in $d days';
}

/// "Bingo · in 7 days" for what is close, "Mimi · monthly" for what is further off.
String reminderSubtitle(Reminder r, DateTime today) {
  final tail = isSoon(r, today) || r.cadence == null
      ? whenText(r, today)
      : r.cadence!;
  return '${r.petName} · $tail';
}

// ---------------------------------------------------------------------------------------------
// Passport
// ---------------------------------------------------------------------------------------------

enum PassportState { upToDate, dueSoon, overdue }

class PassportStatus {
  const PassportStatus(this.state, {this.overdueCount = 0, this.next});
  final PassportState state;
  final int overdueCount;

  /// The soonest open reminder, if any.
  final Reminder? next;

  String get label => switch (state) {
    PassportState.upToDate => 'Passport up to date',
    PassportState.dueSoon => 'Something due soon',
    PassportState.overdue =>
      overdueCount == 1
          ? '1 reminder overdue'
          : '$overdueCount reminders overdue',
  };
}

PassportStatus passportStatus(List<Reminder> reminders, DateTime today) {
  final g = groupReminders(reminders, today);
  final all = [...g.overdue, ...g.thisMonth, ...g.later];
  final next = all.isEmpty ? null : all.first;
  if (g.overdue.isNotEmpty) {
    return PassportStatus(
      PassportState.overdue,
      overdueCount: g.overdue.length,
      next: next,
    );
  }
  if (next != null && isSoon(next, today)) {
    return PassportStatus(PassportState.dueSoon, next: next);
  }
  return PassportStatus(PassportState.upToDate, next: next);
}

/// A row in "Vaccines & treatments": something coming up, or a dose already given.
class PassportEntry {
  const PassportEntry.upcoming(Reminder this.reminder) : record = null;
  const PassportEntry.given(HealthRecord this.record) : reminder = null;

  final Reminder? reminder;
  final HealthRecord? record;

  bool get isUpcoming => reminder != null;
}

/// Upcoming doses first (soonest first), then what has been given (latest first). Weights have
/// their own card, so they are left out.
List<PassportEntry> passportEntries(
  List<HealthRecord> records,
  List<Reminder> reminders,
) {
  final upcoming = reminders.where((r) => !r.done).toList()
    ..sort((a, b) => a.dueOn.compareTo(b.dueOn));
  final given = records.where((r) => r.type != RecordType.weight).toList()
    ..sort((a, b) {
      if (a.givenOn == null && b.givenOn == null) return 0;
      if (a.givenOn == null) return 1;
      if (b.givenOn == null) return -1;
      return b.givenOn!.compareTo(a.givenOn!);
    });
  return [
    for (final r in upcoming) PassportEntry.upcoming(r),
    for (final r in given) PassportEntry.given(r),
  ];
}

// ---------------------------------------------------------------------------------------------
// Add a record
// ---------------------------------------------------------------------------------------------

/// How often something comes round again, when it is predictable. Null means no automatic "next due".
int? defaultIntervalMonths(RecordType type, String name) {
  switch (type) {
    case RecordType.vaccine:
      return 12;
    case RecordType.deworming:
      return 3;
    case RecordType.treatment:
      return RegExp('tick|flea', caseSensitive: false).hasMatch(name)
          ? 1
          : null;
    case RecordType.vetVisit:
    case RecordType.weight:
    case RecordType.allergy:
      return null;
  }
}

/// The "Next due" the form fills in for you.
DateTime? suggestedNextDue(RecordType type, String name, DateTime givenOn) {
  final m = defaultIntervalMonths(type, name);
  return m == null ? null : addMonths(dateOnly(givenOn), m);
}

/// Tap to fill suggestions under the name field.
List<String> nameSuggestions(RecordType type, Species species) {
  switch (type) {
    case RecordType.vaccine:
      return switch (species) {
        Species.dog => [
          'Rabies',
          'DHPP (5-in-1)',
          'Kennel cough',
          'Leptospirosis',
        ],
        Species.cat => ['Rabies', 'FVRCP (3-in-1)', 'FeLV'],
        Species.other => ['Rabies'],
      };
    case RecordType.deworming:
      return ['Deworming'];
    case RecordType.treatment:
      return ['Tick & flea treatment'];
    case RecordType.vetVisit:
    case RecordType.weight:
    case RecordType.allergy:
      return const [];
  }
}

/// A weight in kilograms from what the person typed ("41", "41.5", "41 kg"), or null if it is not
/// a believable weight.
double? parseWeightKg(String? text) {
  if (text == null) return null;
  final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
  if (m == null) return null;
  final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
  if (v == null || v <= 0 || v > 200) return null;
  return v;
}

/// "41 kg", "41.5 kg".
String kgText(double kg) =>
    '${kg == kg.roundToDouble() ? kg.round() : kg.toStringAsFixed(1)} kg';

/// Why a record cannot be saved yet, or null when it can.
String? recordProblem({
  required RecordType type,
  required String name,
  required DateTime? givenOn,
  required DateTime? nextDueOn,
  required DateTime today,
  DateTime? petBirthDate,
  String? weightText,
}) {
  if (type == RecordType.weight) {
    if (parseWeightKg(weightText) == null) {
      return 'Enter a weight between 0.1 and 200 kg.';
    }
  } else if (name.trim().isEmpty) {
    return 'Enter a name for the ${type.label.toLowerCase()}.';
  }
  if (givenOn == null) return 'Choose the date.';
  if (givenOn.isAfter(dateOnly(today))) {
    return 'The date cannot be in the future.';
  }
  if (petBirthDate != null && givenOn.isBefore(dateOnly(petBirthDate))) {
    return 'That is before the pet was born.';
  }
  if (nextDueOn != null && !nextDueOn.isAfter(givenOn)) {
    return 'The next due date must be after the date given.';
  }
  return null;
}

// ---------------------------------------------------------------------------------------------
// Weight
// ---------------------------------------------------------------------------------------------

class WeightSeries {
  const WeightSeries(this.points);

  /// Oldest first.
  final List<({DateTime date, double kg})> points;

  bool get isEmpty => points.isEmpty;
  double? get latestKg => points.isEmpty ? null : points.last.kg;

  /// Bar heights from 0.25 to 1 (the tallest), for the little chart.
  List<double> get heights {
    if (points.isEmpty) return const [];
    final top = points.map((p) => p.kg).reduce((a, b) => a > b ? a : b);
    return [for (final p in points) (p.kg / top).clamp(0.25, 1.0)];
  }

  /// For screen readers: "Weight rising from 34 to 41 kilograms over 6 entries".
  String get description {
    if (points.length < 2) {
      return points.isEmpty
          ? 'No weights yet'
          : 'Weight ${kgText(points.first.kg)}';
    }
    final a = points.first.kg;
    final b = points.last.kg;
    final trend = b > a ? 'rising' : (b < a ? 'falling' : 'steady');
    return 'Weight $trend from ${kgText(a)} to ${kgText(b)} over ${points.length} entries';
  }
}

WeightSeries weightSeries(List<HealthRecord> records, {int max = 6}) {
  final pts = <({DateTime date, double kg})>[];
  for (final r in records) {
    if (r.type != RecordType.weight || r.givenOn == null) continue;
    final kg = parseWeightKg(r.value);
    if (kg != null) pts.add((date: r.givenOn!, kg: kg));
  }
  pts.sort((a, b) => a.date.compareTo(b.date));
  return WeightSeries(pts.length > max ? pts.sublist(pts.length - max) : pts);
}

// ---------------------------------------------------------------------------------------------
// Share with a vet
// ---------------------------------------------------------------------------------------------

/// The address in the QR code and the link. The token sits after a `#`, so it is never sent to a web
/// server when someone opens the link in a browser.
String shareUrl(String base, String token) =>
    '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}#$token';

/// "Link expires in 24 hours", "in 3 hours", "in 40 minutes", "Link has expired".
String expiryText(DateTime expiresAt, DateTime now) {
  final left = expiresAt.difference(now);
  if (left.inSeconds <= 0) return 'Link has expired';
  if (left.inMinutes < 60) {
    final m = left.inMinutes < 1 ? 1 : left.inMinutes;
    return 'Link expires in $m ${m == 1 ? 'minute' : 'minutes'}';
  }
  final h = (left.inMinutes / 60).round();
  return 'Link expires in $h ${h == 1 ? 'hour' : 'hours'}';
}

/// The message sent on WhatsApp.
String whatsAppShareText({required String petName, required String url}) =>
    "Here is $petName's PawPass passport. Open it in the PawPass app, or scan the QR code: $url";

Uri whatsAppUri(String text) => Uri.https('wa.me', '/', {'text': text});

// ---------------------------------------------------------------------------------------------
// Emergency vets
// ---------------------------------------------------------------------------------------------

/// "850 m", "3.4 km", or null when the distance is not known.
String? distanceText(int? meters) {
  if (meters == null) return null;
  if (meters < 1000) return '${((meters / 10).round() * 10).clamp(10, 990)} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// "8pm", "8:30pm", "12pm", "midnight" from "20:00".
String closingText(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  if (h == 0 && m == 0) return 'midnight';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final suffix = h < 12 ? 'am' : 'pm';
  return m == 0 ? '$h12$suffix' : '$h12:${m.toString().padLeft(2, '0')}$suffix';
}

String openStatus(EmergencyVet v) {
  if (v.open24h) return 'Open 24 hours';
  if (v.openNow) {
    return v.closesAt == null
        ? 'Open now'
        : 'Open till ${closingText(v.closesAt!)}';
  }
  return 'Closed now';
}

Uri telUri(String phone) =>
    Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s'), ''));

Uri directionsUri(double lat, double lng) => Uri.https(
  'www.google.com',
  '/maps/dir/',
  {'api': '1', 'destination': '$lat,$lng'},
);

/// A link that opens a map at a position, for "Share location".
Uri locationUri(double lat, double lng) => Uri.https(
  'www.google.com',
  '/maps/search/',
  {'api': '1', 'query': '$lat,$lng'},
);

// ---------------------------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------------------------

class NotificationGroups {
  const NotificationGroups({required this.today, required this.earlier});
  final List<AppNotification> today;
  final List<AppNotification> earlier;
  bool get isEmpty => today.isEmpty && earlier.isEmpty;
}

NotificationGroups groupNotifications(List<AppNotification> all, DateTime now) {
  final sorted = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final t = dateOnly(now);
  return NotificationGroups(
    today: [
      for (final n in sorted)
        if (dateOnly(n.createdAt) == t) n,
    ],
    earlier: [
      for (final n in sorted)
        if (dateOnly(n.createdAt) != t) n,
    ],
  );
}

/// "Just now", "12 min ago", "2h ago", "Yesterday", "3 days ago", or the date for older ones.
String relativeTime(DateTime then, DateTime now) {
  final diff = now.difference(then);
  if (diff.inMinutes < 1) return 'Just now';
  final days = daysBetween(then, now);
  if (days == 0) {
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  return formatDate(then);
}

int unreadCount(List<AppNotification> all) => all.where((n) => !n.read).length;
