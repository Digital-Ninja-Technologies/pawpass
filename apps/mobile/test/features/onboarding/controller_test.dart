import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/community/data/in_memory_community.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/domain/reminder_schedule.dart';
import 'package:pawpass/features/onboarding/state/onboarding_controller.dart';
import 'package:pawpass/features/onboarding/state/session_controller.dart';

class _Rig {
  _Rig() {
    profiles = InMemoryProfileRepository();
    auth = InMemoryAuthRepository();
    pets = InMemoryPetRepository(profiles: profiles, now: () => today);
    services = AppServices(
      auth: auth,
      profiles: profiles,
      pets: pets,
      photos: NoPhotoPicker(),
      emailApp: NoEmailApp(),
      health: InMemoryHealthRepository(now: () => today),
      notifications: InMemoryNotificationsRepository(),
      vets: InMemoryVetsRepository(),
      location: FakeLocationService(),
      links: FakeLinkLauncher(),
      bookings: InMemoryBookingsRepository(),
      payments: InMemoryPaymentsRepository(InMemoryBookingsRepository()),
      community: InMemoryCommunityRepository(),
      now: () => today,
    );
    session = SessionController(services);
    onboarding = OnboardingController(services, session);
  }

  final today = DateTime(2026, 11, 5, 14, 30);
  late final InMemoryProfileRepository profiles;
  late final InMemoryAuthRepository auth;
  late final InMemoryPetRepository pets;
  late final AppServices services;
  late final SessionController session;
  late final OnboardingController onboarding;

  Future<void> signIn() async {
    await onboarding.sendCode('Tolu@Example.com');
    await onboarding.verify('123456');
  }
}

void main() {
  group('sign in', () {
    test('starts signed out', () async {
      final r = _Rig();
      await Future<void>.delayed(Duration.zero);
      expect(r.session.status, SessionStatus.signedOut);
    });

    test('sends the code to the cleaned up address', () async {
      final r = _Rig();
      expect(await r.onboarding.sendCode('  Tolu@Example.com '), isTrue);
      expect(r.auth.sentTo, ['tolu@example.com']);
      expect(r.onboarding.email, 'tolu@example.com');
    });

    test('a wrong code keeps them out and says why', () async {
      final r = _Rig();
      await r.onboarding.sendCode('tolu@example.com');
      expect(await r.onboarding.verify('000000'), isFalse);
      expect(r.onboarding.error, contains('wrong or has expired'));
      expect(r.session.signedIn, isFalse);
    });

    test('the right code signs in and loads the profile', () async {
      final r = _Rig();
      await r.signIn();
      expect(r.onboarding.error, isNull);
      expect(r.session.signedIn, isTrue);
      expect(r.session.onboarded, isFalse);
    });

    test('a failed send shows the message and clears on retry', () async {
      final r = _Rig();
      r.auth.failNextSend = const AppFailure('Too many tries. Wait a minute.');
      expect(await r.onboarding.sendCode('tolu@example.com'), isFalse);
      expect(r.onboarding.error, 'Too many tries. Wait a minute.');
      expect(await r.onboarding.sendCode('tolu@example.com'), isTrue);
      expect(r.onboarding.error, isNull);
    });

    test('signing out returns to signed out', () async {
      final r = _Rig();
      await r.signIn();
      await r.session.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(r.session.status, SessionStatus.signedOut);
      expect(r.session.profile, isNull);
    });
  });

  group('account type and profile', () {
    test('owner is picked to begin with and can be changed', () {
      final r = _Rig();
      expect(r.onboarding.accountTypes, {AccountType.owner});
      r.onboarding.toggleAccountType(AccountType.breeder);
      expect(r.onboarding.accountTypes, {
        AccountType.owner,
        AccountType.breeder,
      });
      r.onboarding.toggleAccountType(AccountType.owner);
      r.onboarding.toggleAccountType(AccountType.breeder);
      expect(r.onboarding.accountTypes, isEmpty);
    });

    test('at least one type is needed to continue', () async {
      final r = _Rig();
      await r.signIn();
      r.onboarding.toggleAccountType(AccountType.owner);
      expect(await r.onboarding.saveAccountTypes(), isFalse);
      r.onboarding.toggleAccountType(AccountType.shelter);
      expect(await r.onboarding.saveAccountTypes(), isTrue);
      expect((await r.profiles.load()).accountTypes, {AccountType.shelter});
    });

    test('saves the profile with the phone in international form', () async {
      final r = _Rig();
      await r.signIn();
      r.onboarding
        ..firstName = ' Tolu '
        ..lastName = 'Adeyemi'
        ..area = 'Lekki Phase 1'
        ..phone = '0803 123 4567';
      expect(await r.onboarding.saveProfile(), isTrue);
      final p = await r.profiles.load();
      expect(p.firstName, 'Tolu');
      expect(p.area, 'Lekki Phase 1');
      expect(p.phone, '+2348031234567');
    });

    test('a bad phone number is refused and nothing is saved', () async {
      final r = _Rig();
      await r.signIn();
      r.onboarding
        ..firstName = 'Tolu'
        ..phone = '12345';
      expect(await r.onboarding.saveProfile(), isFalse);
      expect(r.onboarding.error, contains('phone number'));
      expect(r.profiles.saves, 0);
    });

    test('the phone is optional and the photo uploads when chosen', () async {
      final r = _Rig();
      await r.signIn();
      r.onboarding
        ..firstName = 'Tolu'
        ..avatar = PickedPhoto(Uint8List.fromList([1, 2, 3]));
      expect(await r.onboarding.saveProfile(), isTrue);
      expect((await r.profiles.load()).phone, isNull);
      expect(r.profiles.avatarUploads, 1);
    });
  });

  group('creating the passport', () {
    Future<_Rig> ready() async {
      final r = _Rig();
      await r.signIn();
      r.onboarding
        ..petName = ' Bingo '
        ..breed = 'Boerboel'
        ..sex = PetSex.male
        ..setDateOfBirth(DateTime(2024, 8, 14));
      r.onboarding.setGiven(VaccineKind.core, DateTime(2026, 3, 12));
      r.onboarding.setGiven(VaccineKind.rabies, DateTime(2025, 11, 12));
      r.onboarding.setGiven(VaccineKind.deworming, DateTime(2026, 10, 20));
      return r;
    }

    test(
      'saves the pet, its records and reminders, and finishes setup',
      () async {
        final r = await ready();
        expect(await r.onboarding.createPassport(), isTrue);

        final pet = r.onboarding.createdPet!;
        expect(pet.name, 'Bingo');
        expect(pet.tagCode, startsWith('PP-'));
        expect(r.pets.pets, hasLength(1));
        expect(r.pets.recordsSaved.single.map((x) => x.name), [
          'Rabies',
          'Deworming',
          'DHPP (5-in-1)',
        ]);
        expect(r.pets.channelsSaved.single, {
          ReminderChannel.push,
          ReminderChannel.whatsapp,
          ReminderChannel.email,
        });
        expect(r.session.onboarded, isTrue);
      },
    );

    test('the reminders the person turned off are not saved', () async {
      final r = await ready();
      r.onboarding.toggleChannel(ReminderChannel.whatsapp);
      r.onboarding.toggleChannel(ReminderChannel.email);
      await r.onboarding.createPassport();
      expect(r.pets.channelsSaved.single, {ReminderChannel.push});
    });

    test('skipping health history still creates the passport', () async {
      final r = await ready();
      r.onboarding.given.clear();
      expect(await r.onboarding.createPassport(), isTrue);
      expect(r.pets.recordsSaved.single, isEmpty);
    });

    test('a name is needed', () async {
      final r = await ready();
      r.onboarding.petName = '  ';
      expect(await r.onboarding.createPassport(), isFalse);
      expect(r.onboarding.error, contains('name'));
      expect(r.pets.pets, isEmpty);
    });

    test('a failure saves nothing and can be retried', () async {
      final r = await ready();
      r.pets.failNext = const AppFailure('We could not create the passport.');
      expect(await r.onboarding.createPassport(), isFalse);
      expect(r.onboarding.error, 'We could not create the passport.');
      expect(r.pets.pets, isEmpty);
      expect(r.session.onboarded, isFalse);
      expect(await r.onboarding.createPassport(), isTrue);
      expect(r.pets.pets, hasLength(1));
    });

    test('tapping twice quickly creates one pet', () async {
      final r = await ready();
      final first = r.onboarding.createPassport();
      final second = r.onboarding.createPassport();
      expect(await second, isFalse);
      expect(await first, isTrue);
      expect(r.pets.pets, hasLength(1));
    });

    test('an unknown sex is saved as unknown, not guessed', () async {
      final r = await ready();
      r.onboarding.sex = null;
      await r.onboarding.createPassport();
      expect(r.onboarding.createdPet!.sex, PetSex.unknown);
    });
  });

  group('pet details', () {
    test('changing species clears the breed', () {
      final r = _Rig();
      r.onboarding.breed = 'Boerboel';
      r.onboarding.setSpecies(Species.dog);
      expect(r.onboarding.breed, 'Boerboel');
      r.onboarding.setSpecies(Species.cat);
      expect(r.onboarding.breed, '');
    });

    test('approximate age sets the birth date from today', () {
      final r = _Rig();
      expect(r.onboarding.setApproximateAge(years: 2, months: 0), isTrue);
      expect(r.onboarding.dateOfBirth, DateTime(2024, 11, 5));
      expect(r.onboarding.setApproximateAge(years: 0, months: 0), isFalse);
    });

    test('possessive names', () {
      final r = _Rig();
      r.onboarding.petName = 'Bingo';
      expect(r.onboarding.petPossessive, "Bingo's");
      r.onboarding.petName = 'Charles';
      expect(r.onboarding.petPossessive, "Charles'");
      r.onboarding.petName = '';
      expect(r.onboarding.petPossessive, "your pet's");
    });

    test('starting another pet clears the pet but keeps the person', () async {
      final r = _Rig();
      await r.signIn();
      r.onboarding
        ..petName = 'Bingo'
        ..firstName = 'Tolu';
      r.onboarding.setGiven(VaccineKind.rabies, DateTime(2025, 11, 12));
      r.onboarding.startAnotherPet();
      expect(r.onboarding.petName, '');
      expect(r.onboarding.given, isEmpty);
      expect(r.onboarding.anotherPet, isTrue);
      expect(r.onboarding.firstName, 'Tolu');
      expect(r.session.signedIn, isTrue);
    });
  });
}
