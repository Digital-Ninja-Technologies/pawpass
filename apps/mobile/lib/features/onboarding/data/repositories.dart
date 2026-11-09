import '../../../core/analytics.dart';
import '../../../core/offline_cache.dart';
import '../../../core/push.dart';
import '../../account/data/account_repository.dart';
import '../../account/data/in_memory_account.dart';
import '../../adopt/data/adopt_repository.dart';
import '../../booking/data/booking_repositories.dart';
import '../../community/data/community_repository.dart';
import '../../health/data/health_repositories.dart';
import '../../partner/data/partner_repository.dart';
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

  /// A short lived link to the pet's photo (the bucket is private), or null if there is none.
  Future<String?> photoUrl(Pet pet);
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
  AppServices({
    required this.auth,
    required this.profiles,
    required this.pets,
    required this.photos,
    required this.emailApp,
    required this.health,
    required this.notifications,
    required this.vets,
    required this.location,
    required this.links,
    required this.bookings,
    required this.payments,
    required this.community,
    required this.adopt,
    required this.partner,
    AccountRepository? account,
    this.cache,
    this.analytics = const NoAnalytics(),
    PushService? push,
    this.shareBaseUrl = kShareBaseUrl,
    this.now = DateTime.now,
    this.demoHint,
  }) : account = account ?? InMemoryAccountRepository(),
       push = push ?? PushService.off();

  final AuthRepository auth;
  final ProfileRepository profiles;
  final PetRepository pets;
  final PhotoPicker photos;
  final EmailAppLauncher emailApp;
  final HealthRepository health;
  final NotificationsRepository notifications;
  final VetsRepository vets;
  final LocationService location;
  final LinkLauncher links;
  final BookingsRepository bookings;
  final PaymentsRepository payments;
  final CommunityRepository community;
  final AdoptRepository adopt;
  final PartnerRepository partner;

  /// QR tag orders, active shares and blocked accounts. Tests that do not need it get a pretend one.
  final AccountRepository account;

  /// Saved copies of the profile, pets, passport and reminders, for reading with no signal.
  final OfflineCache? cache;

  /// Counts a few events (opening the app, starting a booking) for the success metrics.
  final Analytics analytics;

  /// Push notifications: registers this phone, and removes it on sign out. Off in tests and demo builds.
  final PushService push;

  /// Where share links point. The token follows a `#`, so it is never sent to that server.
  final String shareBaseUrl;

  /// The clock, so tests can pin "today".
  final DateTime Function() now;

  /// Set only by the debug demo build (no Supabase project): shown on the code screen.
  final String? demoHint;
}

/// Share links open this page (it explains that the link is for a vet using the PawPass app).
/// Override with --dart-define=SHARE_BASE_URL=https://your.domain/s once the site has its own domain.
const kShareBaseUrl = String.fromEnvironment(
  'SHARE_BASE_URL',
  defaultValue: 'https://pawpass-web-ten.vercel.app/s',
);
