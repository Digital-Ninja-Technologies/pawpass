import '../../../core/dates.dart';

/// `health_records.type`.
enum RecordType {
  vaccine('vaccine', 'Vaccine'),
  deworming('deworming', 'Deworming'),
  treatment('treatment', 'Treatment'),
  vetVisit('vet_visit', 'Vet visit'),
  weight('weight', 'Weight'),
  allergy('allergy', 'Allergy');

  const RecordType(this.value, this.label);
  final String value;
  final String label;

  static RecordType fromValue(String v) => values.firstWhere(
    (t) => t.value == v,
    orElse: () => RecordType.treatment,
  );

  /// Types that come round again, so a "next due" date makes sense.
  bool get repeats => this == vaccine || this == deworming || this == treatment;
}

/// One entry on a pet's passport.
class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.petId,
    required this.type,
    required this.name,
    this.givenOn,
    this.nextDueOn,
    this.value,
    this.givenByName,
    this.verifiedByName,
    this.verified = false,
    this.addedByMe = true,
    this.attachmentPath,
  });

  final String id;
  final String petId;
  final RecordType type;
  final String name;
  final DateTime? givenOn;
  final DateTime? nextDueOn;

  /// For weights, the number as text ("41" or "41 kg").
  final String? value;

  /// Free text the owner typed ("Paws and Claws"). Null means "added by you".
  final String? givenByName;

  /// The clinic that verified it. Set only by a vet, never by the owner.
  final String? verifiedByName;
  final bool verified;
  final bool addedByMe;
  final String? attachmentPath;

  /// "Dr. Amina Bello", "Paws and Claws" or "added by you".
  String get sourceLabel {
    if (verified && (verifiedByName ?? '').isNotEmpty) return verifiedByName!;
    if ((givenByName ?? '').isNotEmpty) return givenByName!;
    return addedByMe ? 'added by you' : 'added by a clinic';
  }

  factory HealthRecord.fromRow(Map<String, dynamic> row, {String? me}) {
    final verifier = row['verifier'];
    return HealthRecord(
      id: row['id'] as String,
      petId: row['pet_id'] as String,
      type: RecordType.fromValue(row['type'] as String),
      name: row['name'] as String,
      givenOn: _date(row['given_on']),
      nextDueOn: _date(row['next_due_on']),
      value: row['value'] as String?,
      givenByName: row['given_by_name'] as String?,
      verified: row['verified_at'] != null,
      verifiedByName: verifier is Map
          ? verifier['business_name'] as String?
          : null,
      addedByMe: me == null || row['added_by_user_id'] == me,
      attachmentPath: row['attachment_path'] as String?,
    );
  }
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  final d = DateTime.parse(v as String);
  return DateTime(d.year, d.month, d.day);
}

/// A dose or treatment that is coming up (or overdue), from the `reminders` table.
class Reminder {
  const Reminder({
    required this.id,
    required this.petId,
    required this.petName,
    required this.label,
    required this.dueOn,
    this.recordId,
    this.cadence,
    this.givenOn,
    this.done = false,
  });

  final String id;
  final String petId;
  final String petName;
  final String? recordId;

  /// "Rabies booster", "Deworming".
  final String label;
  final DateTime dueOn;

  /// "yearly", "every 3 months", "monthly"; null when the gap is not known.
  final String? cadence;
  final DateTime? givenOn;
  final bool done;

  factory Reminder.fromRow(
    Map<String, dynamic> row, {
    required String petName,
  }) {
    final record = row['health_records'];
    final rec = record is Map ? Map<String, dynamic>.from(record) : null;
    final type = RecordType.fromValue((rec?['type'] as String?) ?? 'treatment');
    final given = _date(rec?['given_on']);
    final due = _date(row['due_on'])!;
    final recNext = _date(rec?['next_due_on']);
    return Reminder(
      id: row['id'] as String,
      petId: row['pet_id'] as String,
      petName: petName,
      recordId: row['health_record_id'] as String?,
      label: reminderLabel(type, (rec?['name'] as String?) ?? 'Reminder'),
      dueOn: due,
      cadence: cadenceLabel(given, recNext),
      givenOn: given,
      done: row['status'] == 'done',
    );
  }
}

/// "Rabies" becomes "Rabies booster"; "DHPP vaccine" and "Deworming" stay as they are.
/// Mirrors the wording the database uses in notifications.
String reminderLabel(RecordType type, String name) {
  if (type == RecordType.vaccine &&
      !RegExp('booster|vaccine', caseSensitive: false).hasMatch(name)) {
    return '$name booster';
  }
  return name;
}

/// "yearly", "monthly", "every 3 months" from the gap between the dose and the next one.
String? cadenceLabel(DateTime? given, DateTime? next) {
  if (given == null || next == null) return null;
  var months = (next.year - given.year) * 12 + (next.month - given.month);
  if (next.day < given.day) months -= 1;
  if (months < 1) return null;
  if (months == 12) return 'yearly';
  if (months == 1) return 'monthly';
  if (months % 12 == 0) return 'every ${months ~/ 12} years';
  return 'every $months months';
}

/// The link or QR code a vet scans. The raw token exists only here, on the owner's phone.
class ShareLink {
  const ShareLink({
    required this.id,
    required this.token,
    required this.expiresAt,
    required this.scopes,
  });

  final String id;
  final String token;
  final DateTime expiresAt;
  final Set<ShareScope> scopes;

  factory ShareLink.fromJson(Map<String, dynamic> j) => ShareLink(
    id: j['id'] as String,
    token: j['token'] as String,
    expiresAt: DateTime.parse(j['expires_at'] as String),
    scopes: {
      for (final s in (j['scopes'] as List)) ?ShareScope.fromValue(s as String),
    },
  );
}

/// What a vet may see or do, one per switch on the share screen.
enum ShareScope {
  health('health', 'Health records & vaccines'),
  origin('origin', 'Origin & parents'),
  write('write', 'Let the vet add records');

  const ShareScope(this.value, this.label);
  final String value;
  final String label;

  static ShareScope? fromValue(String v) {
    for (final s in values) {
      if (s.value == v) return s;
    }
    return null;
  }
}

enum NotificationKind {
  reminderDue('reminder_due'),
  recordVerified('record_verified'),
  lostAlert('lost_alert'),
  booking('booking'),
  community('community');

  const NotificationKind(this.value);
  final String value;

  static NotificationKind fromValue(String v) => values.firstWhere(
    (k) => k.value == v,
    orElse: () => NotificationKind.community,
  );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.link,
    this.read = false,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String? body;

  /// App route to open ("/schedule").
  final String? link;
  final DateTime createdAt;
  final bool read;

  AppNotification asRead() => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    link: link,
    createdAt: createdAt,
    read: true,
  );

  factory AppNotification.fromRow(Map<String, dynamic> row) => AppNotification(
    id: row['id'] as String,
    kind: NotificationKind.fromValue(row['kind'] as String),
    title: row['title'] as String,
    body: row['body'] as String?,
    link: row['link'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    read: row['read_at'] != null,
  );
}

/// An approved vet that takes emergencies, from `emergency_vets()`.
class EmergencyVet {
  const EmergencyVet({
    required this.id,
    required this.name,
    required this.open24h,
    required this.openNow,
    required this.homeVisits,
    this.area,
    this.phone,
    this.closesAt,
    this.distanceMeters,
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final String? area;

  /// Used only to place a call. Never shown on screen.
  final String? phone;
  final bool open24h;
  final bool openNow;
  final bool homeVisits;

  /// Closing time as "20:00", for "Open till 8pm".
  final String? closesAt;
  final int? distanceMeters;
  final double? lat;
  final double? lng;

  factory EmergencyVet.fromRow(Map<String, dynamic> r) => EmergencyVet(
    id: r['id'] as String,
    name: r['business_name'] as String,
    area: r['area'] as String?,
    phone: r['phone'] as String?,
    open24h: r['open_24h'] as bool? ?? false,
    openNow: r['open_now'] as bool? ?? false,
    homeVisits: r['home_visits'] as bool? ?? false,
    closesAt: r['closes_at'] as String?,
    distanceMeters: (r['distance_m'] as num?)?.toInt(),
    lat: (r['lat'] as num?)?.toDouble(),
    lng: (r['lng'] as num?)?.toDouble(),
  );
}

/// Pet details beyond what onboarding needed, for the passport.
class PetDetails {
  const PetDetails({
    this.originName,
    this.originVerified = false,
    this.motherName,
    this.fatherName,
  });

  final String? originName;
  final bool originVerified;
  final String? motherName;
  final String? fatherName;
}

/// Formats a due date for the passport ("Due 12 Nov 2026").
String dueText(DateTime d) => 'Due ${formatDate(d)}';
