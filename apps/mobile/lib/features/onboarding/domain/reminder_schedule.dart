import '../../../core/dates.dart';
import 'models.dart';

/// The past treatments an owner can tick on "health so far", and how often each comes round.
///
/// These intervals are sensible defaults for a first schedule, not veterinary advice: a vet can change
/// any of them once the pet has a record (milestone 2). Keep this in step with the copy in the app.
enum VaccineKind {
  core(
    recordType: 'vaccine',
    everyMonths: 12,
    cadence: 'Yearly',
    boosterLabel: _coreBooster,
    label: _coreName,
  ),
  rabies(
    recordType: 'vaccine',
    everyMonths: 12,
    cadence: 'Yearly',
    boosterLabel: _rabiesBooster,
    label: _rabiesName,
  ),
  deworming(
    recordType: 'deworming',
    everyMonths: 3,
    cadence: 'Every 3 months',
    boosterLabel: _dewormingName,
    label: _dewormingName,
  ),
  tickFlea(
    recordType: 'treatment',
    everyMonths: 1,
    cadence: 'Monthly',
    boosterLabel: _tickFleaName,
    label: _tickFleaName,
  );

  const VaccineKind({
    required this.recordType,
    required this.everyMonths,
    required this.cadence,
    required String Function(Species) boosterLabel,
    required String Function(Species) label,
  }) : _booster = boosterLabel,
       _name = label;

  /// `health_records.type`.
  final String recordType;
  final int everyMonths;
  final String cadence;
  final String Function(Species) _booster;
  final String Function(Species) _name;

  /// "DHPP (5-in-1)", "Rabies", ...
  String nameFor(Species s) => _name(s);

  /// "DHPP booster", "Rabies booster", ...
  String boosterFor(Species s) => _booster(s);
}

String _coreName(Species s) => switch (s) {
  Species.dog => 'DHPP (5-in-1)',
  Species.cat => 'FVRCP (3-in-1)',
  Species.other => 'Core vaccine',
};
String _coreBooster(Species s) => switch (s) {
  Species.dog => 'DHPP booster',
  Species.cat => 'FVRCP booster',
  Species.other => 'Booster vaccine',
};
String _rabiesName(Species _) => 'Rabies';
String _rabiesBooster(Species _) => 'Rabies booster';
String _dewormingName(Species _) => 'Deworming';
String _tickFleaName(Species _) => 'Tick & flea treatment';

/// One line of the suggested schedule.
class ScheduleItem {
  const ScheduleItem({
    required this.kind,
    required this.label,
    required this.cadence,
    required this.givenOn,
    required this.dueOn,
  });

  final VaccineKind kind;
  final String label;
  final String cadence;
  final DateTime givenOn;
  final DateTime dueOn;

  /// Calendar days until it is due (negative once overdue).
  int daysUntil(DateTime today) => daysBetween(today, dueOn);

  /// Due within 30 days, or already overdue: shown with the warm highlight.
  bool isSoon(DateTime today) => daysUntil(today) <= 30;

  /// "due in 7 days", "due tomorrow", "overdue by 3 days"; null when it is more than 30 days away.
  String? dueText(DateTime today) {
    final d = daysUntil(today);
    if (d < 0) return 'overdue by ${-d} ${-d == 1 ? 'day' : 'days'}';
    if (d == 0) return 'due today';
    if (d == 1) return 'due tomorrow';
    if (d <= 30) return 'due in $d days';
    return null;
  }

  /// "Yearly · due in 7 days" or just "Every 3 months".
  String subtitle(DateTime today) {
    final due = dueText(today);
    return due == null ? cadence : '$cadence · $due';
  }
}

/// The next dose for each treatment the owner says the pet has had, soonest first.
List<ScheduleItem> buildSchedule({
  required Species species,
  required Map<VaccineKind, DateTime> given,
}) {
  final items = [
    for (final e in given.entries)
      ScheduleItem(
        kind: e.key,
        label: e.key.boosterFor(species),
        cadence: e.key.cadence,
        givenOn: dateOnly(e.value),
        dueOn: addMonths(dateOnly(e.value), e.key.everyMonths),
      ),
  ];
  items.sort((a, b) {
    final c = a.dueOn.compareTo(b.dueOn);
    return c != 0 ? c : a.kind.index.compareTo(b.kind.index);
  });
  return items;
}

/// A past treatment as it is saved: one `health_records` row (and one reminder for what is due next).
class HealthRecordDraft {
  const HealthRecordDraft({
    required this.type,
    required this.name,
    required this.givenOn,
    required this.nextDueOn,
  });

  final String type;
  final String name;
  final DateTime givenOn;
  final DateTime nextDueOn;

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'given_on': isoDate(givenOn),
    'next_due_on': isoDate(nextDueOn),
  };
}

List<HealthRecordDraft> recordDrafts({
  required Species species,
  required Map<VaccineKind, DateTime> given,
}) => [
  for (final item in buildSchedule(species: species, given: given))
    HealthRecordDraft(
      type: item.kind.recordType,
      name: item.kind.nameFor(species),
      givenOn: item.givenOn,
      nextDueOn: item.dueOn,
    ),
];
