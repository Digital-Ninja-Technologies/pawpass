import 'dart:math';

import '../../../core/dates.dart';
import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'health_repositories.dart';

/// Working stand ins that follow the same rules as the database (a reminder per record with a next due
/// date, mark done rolls to the next dose), for tests and the no Supabase debug build.
class InMemoryHealthRepository implements HealthRepository {
  InMemoryHealthRepository({DateTime Function()? now, this.remindersOn = true})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Mirrors `profiles.reminder_channels` being non empty.
  bool remindersOn;

  final _records = <String, List<HealthRecord>>{};
  final _reminders = <Reminder>[];
  final _recordPet = <String, String>{};
  final petNames = <String, String>{};
  final details = <String, PetDetails>{};
  final shares = <({ShareLink link, String petId, bool revoked})>[];
  var _n = 0;
  var recordAdds = 0;
  var attachments = 0;
  AppFailure? failNext;

  DateTime get today => dateOnly(_now());

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  /// Adds a record the way the database would, without going through the form checks.
  HealthRecord seed({
    required String petId,
    required String petName,
    required RecordType type,
    required String name,
    DateTime? givenOn,
    DateTime? nextDueOn,
    String? value,
    bool verified = false,
    String? verifier,
    String? givenByName,
  }) {
    petNames[petId] = petName;
    final id = 'rec-${++_n}';
    final rec = HealthRecord(
      id: id,
      petId: petId,
      type: type,
      name: name,
      givenOn: givenOn,
      nextDueOn: nextDueOn,
      value: value,
      verified: verified,
      verifiedByName: verifier,
      givenByName: givenByName,
    );
    (_records[petId] ??= []).add(rec);
    _recordPet[id] = petId;
    if (nextDueOn != null && remindersOn) {
      _reminders.add(
        Reminder(
          id: 'rem-$id',
          petId: petId,
          petName: petName,
          recordId: id,
          label: reminderLabel(type, name),
          dueOn: nextDueOn,
          cadence: cadenceLabel(givenOn, nextDueOn),
          givenOn: givenOn,
        ),
      );
    }
    return rec;
  }

  @override
  Future<List<HealthRecord>> records(String petId) async {
    _maybeFail();
    return List.of(_records[petId] ?? const []);
  }

  @override
  Future<List<Reminder>> reminders(List<Pet> pets) async {
    _maybeFail();
    final ids = {for (final p in pets) p.id};
    final open =
        _reminders.where((r) => ids.contains(r.petId) && !r.done).toList()
          ..sort((a, b) => a.dueOn.compareTo(b.dueOn));
    return open;
  }

  @override
  Future<HealthRecord> addRecord({
    required String petId,
    required RecordType type,
    required String name,
    required DateTime givenOn,
    DateTime? nextDueOn,
    String? value,
    String? givenByName,
    PickedPhoto? attachment,
  }) async {
    _maybeFail();
    recordAdds++;
    if (attachment != null) attachments++;
    return seed(
      petId: petId,
      petName: petNames[petId] ?? 'Pet',
      type: type,
      name: name.trim(),
      givenOn: givenOn,
      nextDueOn: nextDueOn,
      value: value,
      givenByName: (givenByName ?? '').trim().isEmpty
          ? null
          : givenByName!.trim(),
    );
  }

  @override
  Future<HealthRecord?> completeReminder(
    String reminderId, {
    DateTime? givenOn,
  }) async {
    _maybeFail();
    final i = _reminders.indexWhere((r) => r.id == reminderId);
    if (i < 0) throw const AppFailure('Reminder not found');
    final r = _reminders[i];
    if (r.done) throw const AppFailure('That reminder is already done');
    final d = dateOnly(givenOn ?? today);
    if (d.isAfter(today)) {
      throw const AppFailure('The date given cannot be in the future');
    }
    _reminders[i] = Reminder(
      id: r.id,
      petId: r.petId,
      petName: r.petName,
      recordId: r.recordId,
      label: r.label,
      dueOn: r.dueOn,
      cadence: r.cadence,
      givenOn: r.givenOn,
      done: true,
    );
    final original = (_records[r.petId] ?? const <HealthRecord>[])
        .where((x) => x.id == r.recordId)
        .firstOrNull;
    if (original == null) return null;
    int? gap;
    if (original.givenOn != null && original.nextDueOn != null) {
      final a = original.givenOn!;
      final b = original.nextDueOn!;
      var m = (b.year - a.year) * 12 + (b.month - a.month);
      if (b.day < a.day) m -= 1;
      gap = max(1, m);
    }
    return seed(
      petId: r.petId,
      petName: r.petName,
      type: original.type,
      name: original.name,
      givenOn: d,
      nextDueOn: gap == null ? null : addMonths(d, gap),
    );
  }

  @override
  Future<ShareLink> createShare({
    required String petId,
    required Set<ShareScope> scopes,
    int hours = 24,
  }) async {
    _maybeFail();
    final rnd = Random.secure();
    final token = [
      for (var i = 0; i < 24; i++)
        rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    final link = ShareLink(
      id: 'share-${shares.length + 1}',
      token: token,
      expiresAt: _now().add(Duration(hours: hours)),
      scopes: scopes,
    );
    shares.add((link: link, petId: petId, revoked: false));
    return link;
  }

  @override
  Future<void> revokeShare(String shareId) async {
    _maybeFail();
    final i = shares.indexWhere((s) => s.link.id == shareId);
    if (i < 0) throw const AppFailure('Share not found');
    shares[i] = (link: shares[i].link, petId: shares[i].petId, revoked: true);
  }

  @override
  Future<PetDetails> petDetails(Pet pet) async =>
      details[pet.id] ?? const PetDetails();
}

class InMemoryNotificationsRepository implements NotificationsRepository {
  final items = <AppNotification>[];
  var loads = 0;
  AppFailure? failNext;

  @override
  Future<List<AppNotification>> load() async {
    loads++;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    return List.of(items);
  }

  @override
  Future<void> markRead(String id) async {
    final i = items.indexWhere((n) => n.id == id);
    if (i >= 0) items[i] = items[i].asRead();
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].asRead();
    }
  }
}

class InMemoryVetsRepository implements VetsRepository {
  InMemoryVetsRepository([List<EmergencyVet>? vets]) : vets = vets ?? [];
  final List<EmergencyVet> vets;
  final calls = <({double? lat, double? lng})>[];
  AppFailure? failNext;

  @override
  Future<List<EmergencyVet>> emergencyVets({double? lat, double? lng}) async {
    calls.add((lat: lat, lng: lng));
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    // Like the database: distances only when a position was given.
    return [
      for (final v in vets)
        lat == null || lng == null
            ? EmergencyVet(
                id: v.id,
                name: v.name,
                area: v.area,
                phone: v.phone,
                open24h: v.open24h,
                openNow: v.openNow,
                homeVisits: v.homeVisits,
                closesAt: v.closesAt,
                lat: v.lat,
                lng: v.lng,
              )
            : v,
    ];
  }
}

class FakeLocationService implements LocationService {
  FakeLocationService([this.position]);
  ({double lat, double lng})? position;
  var asked = 0;

  @override
  Future<({double lat, double lng})?> current() async {
    asked++;
    return position;
  }
}

class FakeLinkLauncher implements LinkLauncher {
  final opened = <Uri>[];
  final copied = <String>[];
  bool result = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }

  @override
  Future<void> copy(String text) async => copied.add(text);
}
