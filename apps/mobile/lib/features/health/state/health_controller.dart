import 'package:flutter/foundation.dart';

import '../../../core/dates.dart';
import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/session_controller.dart';
import '../domain/health_logic.dart';
import '../domain/models.dart';

/// Everything the Health screens show: the person's pets, which one is selected, its records, the
/// schedule across all pets, and notifications. Loads once the person has finished onboarding and
/// forgets everything on sign out.
class HealthController extends ChangeNotifier {
  HealthController(this._services, this._session) {
    _session.addListener(_onSession);
    _onSession();
  }

  final AppServices _services;
  final SessionController _session;
  var _disposed = false;
  var _reloadRequested = false;

  DateTime get now => _services.now();
  DateTime get today => dateOnly(now);

  List<Pet> pets = const [];
  String? selectedId;
  List<Reminder> reminders = const [];
  List<AppNotification> notifications = const [];
  final Map<String, List<HealthRecord>> _records = {};
  final Map<String, PetDetails> _details = {};
  final Map<String, String?> _photoUrls = {};

  bool loaded = false;
  bool loading = false;
  bool busy = false;
  String? error;

  /// The next due date after the last "mark done", for the confirmation message.
  DateTime? lastNextDue;

  // ------------------------------------------------------------------ reading

  Pet? get selected {
    for (final p in pets) {
      if (p.id == selectedId) return p;
    }
    return pets.isEmpty ? null : pets.first;
  }

  List<HealthRecord> recordsFor(String petId) => _records[petId] ?? const [];

  PetDetails detailsFor(String petId) => _details[petId] ?? const PetDetails();

  String? photoUrlFor(String petId) => _photoUrls[petId];

  List<Reminder> remindersFor(String? petId) => petId == null
      ? reminders
      : [
          for (final r in reminders)
            if (r.petId == petId) r,
        ];

  PassportStatus statusFor(String petId) =>
      passportStatus(remindersFor(petId), today);

  /// The soonest open reminder for this pet.
  Reminder? nextFor(String petId) => statusFor(petId).next;

  WeightSeries weightFor(String petId) => weightSeries(recordsFor(petId));

  int get unread => unreadCount(notifications);

  // ------------------------------------------------------------------ loading

  void _onSession() {
    if (_disposed) return;
    if (_session.status == SessionStatus.signedOut) {
      if (loaded || pets.isNotEmpty) reset();
      return;
    }
    if (_session.signedIn && _session.onboarded && !loaded && !loading) {
      load();
    }
  }

  /// Loads pets, the schedule and notifications. Safe to call again to refresh.
  Future<void> load() async {
    if (loading) {
      // Something changed while a load was running (a new pet): go round again when it finishes.
      _reloadRequested = true;
      return;
    }
    loading = true;
    error = null;
    _notify();
    try {
      pets = await _services.pets.myPets();
      if (selectedId == null || !pets.any((p) => p.id == selectedId)) {
        selectedId = pets.isEmpty ? null : pets.first.id;
      }
      reminders = await _services.health.reminders(pets);
      await _loadSelected();
      await _loadNotifications();
      loaded = true;
    } on AppFailure catch (e) {
      error = e.message;
    } finally {
      loading = false;
      _notify();
    }
    _loadPhotos();
    if (_reloadRequested) {
      _reloadRequested = false;
      await load();
    }
  }

  Future<void> _loadSelected() async {
    final pet = selected;
    if (pet == null) return;
    _records[pet.id] = await _services.health.records(pet.id);
    _details[pet.id] = await _services.health.petDetails(pet);
  }

  Future<void> _loadNotifications() async {
    try {
      notifications = await _services.notifications.load();
    } on AppFailure {
      // The bell can stay empty; it should never stop the rest of the screen.
    }
  }

  Future<void> _loadPhotos() async {
    for (final p in pets) {
      if (_photoUrls.containsKey(p.id)) continue;
      _photoUrls[p.id] = await _services.pets.photoUrl(p);
    }
    _notify();
  }

  Future<void> select(String petId) async {
    if (selectedId == petId) return;
    selectedId = petId;
    _notify();
    try {
      await _loadSelected();
    } on AppFailure catch (e) {
      error = e.message;
    }
    _notify();
  }

  /// Refreshes the selected pet's records and everyone's reminders.
  Future<void> refreshHealth() async {
    try {
      reminders = await _services.health.reminders(pets);
      await _loadSelected();
    } on AppFailure catch (e) {
      error = e.message;
    }
    _notify();
  }

  // ------------------------------------------------------------------ acting

  Future<bool> _run(Future<void> Function() work) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await work();
      return true;
    } on AppFailure catch (e) {
      error = e.message;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> addRecord({
    required RecordType type,
    required String name,
    required DateTime givenOn,
    DateTime? nextDueOn,
    String? value,
    String? givenByName,
    PickedPhoto? attachment,
  }) {
    final pet = selected;
    if (pet == null) return Future.value(false);
    return _run(() async {
      await _services.health.addRecord(
        petId: pet.id,
        type: type,
        name: name,
        givenOn: givenOn,
        nextDueOn: nextDueOn,
        value: value,
        givenByName: givenByName,
        attachment: attachment,
      );
      await refreshHealth();
    });
  }

  /// The dose was given (today unless [date] is set): records it and schedules the next one.
  Future<bool> markDone(Reminder reminder, {DateTime? date}) {
    lastNextDue = null;
    return _run(() async {
      final next = await _services.health.completeReminder(
        reminder.id,
        givenOn: date,
      );
      lastNextDue = next?.nextDueOn;
      // Make the screen right away, then confirm with the database.
      reminders = [
        for (final r in reminders)
          if (r.id != reminder.id) r,
      ];
      _notify();
      await refreshHealth();
    });
  }

  Future<ShareLink?> createShare(
    Set<ShareScope> scopes, {
    int hours = 24,
  }) async {
    final pet = selected;
    if (pet == null) return null;
    ShareLink? link;
    await _run(() async {
      link = await _services.health.createShare(
        petId: pet.id,
        scopes: scopes,
        hours: hours,
      );
    });
    return link;
  }

  Future<void> revokeShare(String shareId) async {
    await _run(() => _services.health.revokeShare(shareId));
  }

  Future<void> refreshNotifications() async {
    await _loadNotifications();
    _notify();
  }

  Future<void> markNotificationRead(String id) async {
    notifications = [
      for (final n in notifications) n.id == id ? n.asRead() : n,
    ];
    _notify();
    try {
      await _services.notifications.markRead(id);
    } on AppFailure {
      // Reading it on screen is what matters; it will sync next time.
    }
  }

  Future<void> markAllRead() async {
    notifications = [for (final n in notifications) n.asRead()];
    _notify();
    try {
      await _services.notifications.markAllRead();
    } on AppFailure {
      // As above.
    }
  }

  void clearError() {
    if (error != null) {
      error = null;
      _notify();
    }
  }

  /// Forgets everything (sign out), so nothing carries over to the next person.
  void reset() {
    pets = const [];
    selectedId = null;
    reminders = const [];
    notifications = const [];
    _records.clear();
    _details.clear();
    _photoUrls.clear();
    loaded = false;
    loading = false;
    busy = false;
    error = null;
    lastNextDue = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_onSession);
    super.dispose();
  }
}
