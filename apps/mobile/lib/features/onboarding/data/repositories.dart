import '../domain/models.dart';
import '../domain/reminder_schedule.dart';

/// Email one-time code sign in. No password.
abstract class AuthRepository {
  bool get signedIn;
  String? get email;

  /// Emits true on sign in and false on sign out.
  Stream<bool> get signedInChanges;

  /// Emails a 6 digit code. Creates the account on first use.
  Future<void> sendCode(String email);

  /// Throws [AppFailure] with a readable message if the code is wrong or has expired.
  Future<void> verifyCode({required String email, required String code});

  Future<void> signOut();
}

abstract class ProfileRepository {
  Future<Profile> load();

  /// Saves only the fields passed. A null [phone] leaves it alone; pass an empty string to clear it.
  Future<void> save({
    String? firstName,
    String? lastName,
    String? area,
    String? phone,
    Set<AccountType>? accountTypes,
  });

  /// Uploads to the private avatars bucket and points the profile at it. Returns the storage path.
  Future<String> uploadAvatar(PickedPhoto photo);
}

abstract class PetRepository {
  /// Creates the pet, its tag code, its past records and their reminders in one go (see the
  /// `create_pet_passport` database function). The photo is uploaded afterwards and never blocks
  /// the passport: if it fails the pet is still created.
  Future<Pet> createPassport({
    required PetInput pet,
    required List<HealthRecordDraft> records,
    required Set<ReminderChannel> channels,
    PickedPhoto? photo,
  });

  Future<List<Pet>> myPets();
}

abstract class PhotoPicker {
  Future<PickedPhoto?> fromGallery();
  Future<PickedPhoto?> fromCamera();
}

/// Opens the phone's mail app (for "Open email app" on the code screen).
abstract class EmailAppLauncher {
  Future<bool> open();
}

/// Everything the onboarding flow needs from the outside world.
class AppServices {
  const AppServices({
    required this.auth,
    required this.profiles,
    required this.pets,
    required this.photos,
    required this.emailApp,
    this.now = DateTime.now,
    this.demoHint,
  });

  final AuthRepository auth;
  final ProfileRepository profiles;
  final PetRepository pets;
  final PhotoPicker photos;
  final EmailAppLauncher emailApp;

  /// The clock, so tests can pin "today".
  final DateTime Function() now;

  /// Set only by the debug demo build (no Supabase project): shown on the code screen.
  final String? demoHint;
}
