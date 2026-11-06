import '../../onboarding/domain/models.dart';
import '../domain/models.dart';

abstract class HealthRepository {
  Future<List<HealthRecord>> records(String petId);

  /// Open (not done) reminders for these pets, soonest first.
  Future<List<Reminder>> reminders(List<Pet> pets);

  Future<HealthRecord> addRecord({
    required String petId,
    required RecordType type,
    required String name,
    required DateTime givenOn,
    DateTime? nextDueOn,
    String? value,
    String? givenByName,
    PickedPhoto? attachment,
  });

  /// The dose was given: records it and schedules the next one. Returns the new record, if any.
  Future<HealthRecord?> completeReminder(
    String reminderId, {
    DateTime? givenOn,
  });

  Future<ShareLink> createShare({
    required String petId,
    required Set<ShareScope> scopes,
    int hours = 24,
  });

  Future<void> revokeShare(String shareId);

  Future<PetDetails> petDetails(Pet pet);
}

abstract class NotificationsRepository {
  /// Announces reminders that are due soon or overdue (once each), then returns the list, newest first.
  Future<List<AppNotification>> load();

  Future<void> markRead(String id);
  Future<void> markAllRead();
}

abstract class VetsRepository {
  Future<List<EmergencyVet>> emergencyVets({double? lat, double? lng});
}

/// Where the phone is, or null if the person said no or location is off. Coarse is plenty.
abstract class LocationService {
  Future<({double lat, double lng})?> current();
}

/// Opens things outside the app and copies text.
abstract class LinkLauncher {
  Future<bool> open(Uri uri);
  Future<void> copy(String text);
}
