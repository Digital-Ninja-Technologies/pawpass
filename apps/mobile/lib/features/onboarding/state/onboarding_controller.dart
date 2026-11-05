import 'package:flutter/foundation.dart';

import '../../../core/dates.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import '../domain/pet_age.dart';
import '../domain/reminder_schedule.dart';
import '../domain/validators.dart';
import 'session_controller.dart';

/// Everything typed and picked across the onboarding screens, and the calls that save it.
///
/// Nothing about the pet is saved until the last step ("Turn on reminders"), so a person who stops
/// half way leaves no half made passport behind. Account types and profile details save as they go.
class OnboardingController extends ChangeNotifier {
  OnboardingController(this._services, this._session) {
    _session.addListener(_onSession);
  }

  final AppServices _services;
  final SessionController _session;
  var _disposed = false;

  DateTime get today => dateOnly(_services.now());

  // Busy and error state shared by every step.
  bool busy = false;
  String? error;

  // Sign in
  String email = '';

  // Account types
  Set<AccountType> accountTypes = {AccountType.owner};

  // Profile
  String firstName = '';
  String lastName = '';
  String area = '';
  String phone = '';
  PickedPhoto? avatar;

  // Pet
  Species species = Species.dog;
  String petName = '';
  String breed = '';
  PetSex? sex;
  DateTime? dateOfBirth;
  PickedPhoto? petPhoto;

  // Health history: what the owner says the pet has had, and when it was last given.
  final Map<VaccineKind, DateTime> given = {};

  // Reminders
  Set<ReminderChannel> channels = {
    ReminderChannel.push,
    ReminderChannel.whatsapp,
    ReminderChannel.email,
  };

  Pet? createdPet;

  var _prefilled = false;

  /// Fills the form from the saved profile once per sign in (a person who comes back half way through
  /// finds their details waiting), and wipes everything when they sign out.
  void _onSession() {
    if (_disposed) return;
    if (_session.status == SessionStatus.signedOut) {
      if (_prefilled || email.isNotEmpty) reset();
      return;
    }
    final p = _session.profile;
    if (_session.signedIn && p != null && !_prefilled) {
      _prefilled = true;
      accountTypes = {...p.accountTypes};
      firstName = p.firstName;
      lastName = p.lastName;
      area = p.area ?? '';
      phone = p.phone ?? '';
      notifyListeners();
    }
  }

  /// Forgets everything typed so far (used on sign out so nothing carries over to the next person).
  void reset() {
    _prefilled = false;
    busy = false;
    error = null;
    email = '';
    accountTypes = {AccountType.owner};
    firstName = '';
    lastName = '';
    area = '';
    phone = '';
    avatar = null;
    species = Species.dog;
    petName = '';
    breed = '';
    sex = null;
    dateOfBirth = null;
    petPhoto = null;
    given.clear();
    channels = {
      ReminderChannel.push,
      ReminderChannel.whatsapp,
      ReminderChannel.email,
    };
    createdPet = null;
    anotherPet = false;
    notifyListeners();
  }

  /// True when adding a second or later pet, after the first-run flow.
  bool anotherPet = false;

  // ---------------------------------------------------------------- helpers

  String get petNameOrFallback =>
      petName.trim().isEmpty ? 'your pet' : petName.trim();

  /// "Bingo's" or "Charles'"
  String get petPossessive {
    final n = petNameOrFallback;
    return n.endsWith('s') ? "$n'" : "$n's";
  }

  List<ScheduleItem> get schedule =>
      buildSchedule(species: species, given: given);

  bool get petValid => petName.trim().isNotEmpty;

  void clearError() {
    if (error != null) {
      error = null;
      notifyListeners();
    }
  }

  Future<bool> _run(Future<void> Function() work) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await work();
      return true;
    } on AppFailure catch (e) {
      error = e.message;
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ----------------------------------------------------------------- steps

  Future<bool> sendCode(String address) {
    email = normaliseEmail(address);
    return _run(() => _services.auth.sendCode(email));
  }

  /// Signs in with the code, then loads the profile so the router knows where to go next.
  Future<bool> verify(String code) => _run(() async {
    await _services.auth.verifyCode(email: email, code: code);
    await _session.refreshProfile();
  });

  void toggleAccountType(AccountType t) {
    if (accountTypes.contains(t)) {
      accountTypes = {...accountTypes}..remove(t);
    } else {
      accountTypes = {...accountTypes, t};
    }
    notifyListeners();
  }

  Future<bool> saveAccountTypes() {
    if (accountTypes.isEmpty) return Future.value(false);
    return _run(() => _services.profiles.save(accountTypes: accountTypes));
  }

  /// Saves the profile. Returns false (with [error] set) if the phone number is not valid.
  Future<bool> saveProfile() => _run(() async {
    final normalised = phone.trim().isEmpty ? '' : normalisePhone(phone);
    if (normalised == null) {
      throw const AppFailure(
        'That phone number does not look right. Check it, or leave it blank.',
      );
    }
    await _services.profiles.save(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      area: area.trim(),
      phone: normalised,
    );
    if (avatar != null) await _services.profiles.uploadAvatar(avatar!);
  });

  void setSpecies(Species s) {
    if (species == s) return;
    species = s;
    // A breed or a vaccine name belongs to a species: start fresh when it changes.
    breed = '';
    notifyListeners();
  }

  void setGiven(VaccineKind kind, DateTime? date) {
    if (date == null) {
      given.remove(kind);
    } else {
      given[kind] = dateOnly(date);
    }
    notifyListeners();
  }

  void toggleChannel(ReminderChannel c) {
    if (channels.contains(c)) {
      channels = {...channels}..remove(c);
    } else {
      channels = {...channels, c};
    }
    notifyListeners();
  }

  void setDateOfBirth(DateTime? d) {
    dateOfBirth = d == null ? null : dateOnly(d);
    notifyListeners();
  }

  /// Sets the birth date from "about N years and M months". Returns false if the age makes no sense.
  bool setApproximateAge({required int years, required int months}) {
    final d = approximateBirthDate(years: years, months: months, today: today);
    if (d == null) return false;
    setDateOfBirth(d);
    return true;
  }

  void notify() => notifyListeners();

  /// Creates the passport, its records and its reminders in one go.
  Future<bool> createPassport() => _run(() async {
    if (!petValid) throw const AppFailure("Add your pet's name first.");
    createdPet = await _services.pets.createPassport(
      pet: PetInput(
        name: petName.trim(),
        species: species,
        breed: breed.trim().isEmpty ? null : breed.trim(),
        sex: sex ?? PetSex.unknown,
        dateOfBirth: dateOfBirth,
      ),
      records: recordDrafts(species: species, given: given),
      channels: channels,
      photo: petPhoto,
    );
    await _session.refreshProfile();
  });

  /// Clears the pet steps so a second pet can be added. Profile and sign in are kept.
  void startAnotherPet() {
    species = Species.dog;
    petName = '';
    breed = '';
    sex = null;
    dateOfBirth = null;
    petPhoto = null;
    given.clear();
    createdPet = null;
    anotherPet = true;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_onSession);
    super.dispose();
  }
}
