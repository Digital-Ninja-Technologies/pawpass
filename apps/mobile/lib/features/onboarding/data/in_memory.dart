import 'dart:async';

import '../../../core/analytics.dart';
import '../../../core/push.dart';
import '../../../core/offline_cache.dart';
import '../../account/data/in_memory_account.dart';
import '../../account/domain/models.dart';
import '../../courses/data/courses_repository.dart';
import '../../courses/data/in_memory_courses.dart';
import '../../adopt/data/in_memory_adopt.dart';
import '../../booking/data/in_memory_bookings.dart';
import '../../community/data/in_memory_community.dart';
import '../../health/data/in_memory_health.dart';
import '../../partner/data/in_memory_partner.dart';
import '../domain/models.dart';
import '../domain/reminder_schedule.dart';
import '../domain/validators.dart';
import 'repositories.dart';

/// Working stand ins for the real services. Used by tests and by the debug build when no Supabase
/// project is configured, so the screens can be reviewed on their own. Never used in a release build.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({this.validCode = '123456', String? signedInAs})
    : _email = signedInAs;

  /// The only code that signs in.
  final String validCode;
  final _changes = StreamController<bool>.broadcast();
  String? _email;
  final sentTo = <String>[];

  /// Set to make the next call fail, to test error handling.
  AppFailure? failNextSend;
  AppFailure? failNextVerify;

  @override
  bool get signedIn => _email != null;

  @override
  String? get email => _email;

  @override
  Stream<bool> get signedInChanges => _changes.stream;

  @override
  Future<void> sendCode(String email) async {
    final f = failNextSend;
    if (f != null) {
      failNextSend = null;
      throw f;
    }
    sentTo.add(normaliseEmail(email));
  }

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    final f = failNextVerify;
    if (f != null) {
      failNextVerify = null;
      throw f;
    }
    if (code != validCode) {
      throw const AppFailure(
        'That code is wrong or has expired. Check it, or ask for a new one.',
      );
    }
    _email = normaliseEmail(email);
    _changes.add(true);
  }

  @override
  Future<void> signOut() async {
    _email = null;
    _changes.add(false);
  }
}

class InMemoryProfileRepository implements ProfileRepository {
  Profile _profile = const Profile();
  var saves = 0;
  var avatarUploads = 0;
  AppFailure? failNextSave;

  /// Marks the profile as finished, as the database does when the first passport is created.
  void markOnboarded(DateTime at) {
    _profile = Profile(
      firstName: _profile.firstName,
      lastName: _profile.lastName,
      area: _profile.area,
      phone: _profile.phone,
      avatarPath: _profile.avatarPath,
      accountTypes: _profile.accountTypes,
      onboardedAt: at,
    );
  }

  @override
  Future<Profile> load() async => _profile;

  @override
  Future<void> save({
    String? firstName,
    String? lastName,
    String? area,
    String? phone,
    Set<AccountType>? accountTypes,
  }) async {
    final f = failNextSave;
    if (f != null) {
      failNextSave = null;
      throw f;
    }
    saves++;
    _profile = Profile(
      firstName: firstName ?? _profile.firstName,
      lastName: lastName ?? _profile.lastName,
      area: area ?? _profile.area,
      phone: phone == null ? _profile.phone : (phone.isEmpty ? null : phone),
      avatarPath: _profile.avatarPath,
      accountTypes: accountTypes ?? _profile.accountTypes,
      onboardedAt: _profile.onboardedAt,
    );
  }

  @override
  Future<String> uploadAvatar(PickedPhoto photo) async {
    avatarUploads++;
    return 'demo/avatar.${photo.extension}';
  }
}

class InMemoryPetRepository implements PetRepository {
  InMemoryPetRepository({this.profiles, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final InMemoryProfileRepository? profiles;
  final DateTime Function() _now;
  final pets = <Pet>[];
  final recordsSaved = <List<HealthRecordDraft>>[];
  final channelsSaved = <Set<ReminderChannel>>[];
  AppFailure? failNext;
  var _n = 0;

  @override
  Future<Pet> createPassport({
    required PetInput pet,
    required List<HealthRecordDraft> records,
    required Set<ReminderChannel> channels,
    PickedPhoto? photo,
  }) async {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    _n++;
    final created = Pet(
      id: 'pet-$_n',
      name: pet.name,
      species: pet.species,
      breed: pet.breed,
      sex: pet.sex,
      dateOfBirth: pet.dateOfBirth,
      tagCode: 'PP-${4820 + _n}-LK',
      photoPath: photo == null ? null : 'demo/pet-$_n.${photo.extension}',
    );
    pets.add(created);
    recordsSaved.add(records);
    channelsSaved.add(channels);
    profiles?.markOnboarded(_now());
    return created;
  }

  @override
  Future<List<Pet>> myPets() async => List.of(pets);

  @override
  Future<String?> photoUrl(Pet pet) async => null;
}

class NoPhotoPicker implements PhotoPicker {
  NoPhotoPicker({this.next});

  /// The photo the next pick returns (null means the person cancelled).
  PickedPhoto? next;

  @override
  Future<PickedPhoto?> fromGallery() async => next;

  @override
  Future<PickedPhoto?> fromCamera() async => next;
}

class NoEmailApp implements EmailAppLauncher {
  var opened = 0;
  bool result = true;

  @override
  Future<bool> open() async {
    opened++;
    return result;
  }
}

/// A full set of in memory services.
AppServices inMemoryServices({
  DateTime Function()? now,
  String validCode = '123456',
  String? signedInAs,
  OfflineCache? cache,
  Analytics analytics = const NoAnalytics(),
  PushService? push,
  CoursesRepository? courses,
}) {
  final profiles = InMemoryProfileRepository();
  final bookings = InMemoryBookingsRepository(now: now);
  final pets = InMemoryPetRepository(profiles: profiles, now: now);
  final health = InMemoryHealthRepository(now: now);
  String? petNameFor(String id) {
    for (final p in pets.pets) {
      if (p.id == id) {
        return p.name;
      }
    }
    return null;
  }

  final account = InMemoryAccountRepository(
    now: now,
    petName: petNameFor,
    sharesSource: () => [
      for (final s in health.shares)
        if (!s.revoked)
          ActiveShare(
            id: s.link.id,
            petId: s.petId,
            petName: petNameFor(s.petId) ?? 'Your pet',
            scopes: s.link.scopes,
            expiresAt: s.link.expiresAt,
          ),
    ],
  );
  final coursesRepo = courses is InMemoryCoursesRepository
      ? courses
      : InMemoryCoursesRepository();
  final adopt = InMemoryAdoptRepository(
    now: now,
    onPassport: (name, species, breed) {
      // A passport accepted from a sale or adoption becomes one of the person's pets.
      pets.createPassport(
        pet: PetInput(
          name: name,
          species: Species.values.firstWhere(
            (s) => s.value == species,
            orElse: () => Species.other,
          ),
          breed: breed,
          sex: PetSex.unknown,
        ),
        records: const [],
        channels: {ReminderChannel.push},
      );
    },
  );
  return AppServices(
    auth: InMemoryAuthRepository(validCode: validCode, signedInAs: signedInAs),
    profiles: profiles,
    pets: pets,
    photos: NoPhotoPicker(),
    emailApp: NoEmailApp(),
    health: health,
    notifications: InMemoryNotificationsRepository(),
    vets: InMemoryVetsRepository(),
    location: FakeLocationService(),
    links: FakeLinkLauncher(),
    bookings: bookings,
    payments: InMemoryPaymentsRepository(
      bookings,
      others: [adopt.markPaid, account.markPaid, coursesRepo.markPaid],
    ),
    community: InMemoryCommunityRepository(now: now),
    adopt: adopt,
    partner: InMemoryPartnerRepository(
      now: now,
      onConfirmHandover: adopt.sellerConfirmHandover,
      onCancelOrder: adopt.sellerCancel,
    ),
    account: account,
    courses: courses ?? coursesRepo,
    cache: cache,
    analytics: analytics,
    push: push,
    now: now ?? DateTime.now,
  );
}
