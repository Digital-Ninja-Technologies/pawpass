import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/health/domain/health_logic.dart';
import 'package:pawpass/features/health/domain/models.dart';
import 'package:pawpass/features/health/state/health_controller.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/state/session_controller.dart';

final _today = DateTime(2026, 11, 5, 9);

class _Rig {
  _Rig({bool signedIn = true, bool onboarded = true}) {
    profiles = InMemoryProfileRepository();
    auth = InMemoryAuthRepository(
      signedInAs: signedIn ? 'tolu@example.com' : null,
    );
    pets = InMemoryPetRepository(profiles: profiles, now: () => _today);
    health = InMemoryHealthRepository(now: () => _today);
    notifications = InMemoryNotificationsRepository();
    services = AppServices(
      auth: auth,
      profiles: profiles,
      pets: pets,
      photos: NoPhotoPicker(),
      emailApp: NoEmailApp(),
      health: health,
      notifications: notifications,
      vets: InMemoryVetsRepository(),
      location: FakeLocationService(),
      links: FakeLinkLauncher(),
      bookings: InMemoryBookingsRepository(),
      payments: InMemoryPaymentsRepository(InMemoryBookingsRepository()),
      now: () => _today,
    );
    if (onboarded) profiles.markOnboarded(_today);
    session = SessionController(services);
    controller = HealthController(services, session);
  }

  late final InMemoryProfileRepository profiles;
  late final InMemoryAuthRepository auth;
  late final InMemoryPetRepository pets;
  late final InMemoryHealthRepository health;
  late final InMemoryNotificationsRepository notifications;
  late final AppServices services;
  late final SessionController session;
  late final HealthController controller;

  Future<Pet> addPet(String name) => pets.createPassport(
    pet: PetInput(name: name, species: Species.dog),
    records: const [],
    channels: {ReminderChannel.push},
  );

  /// Waits for the controller's first load, then loads again so it sees what the test just added.
  Future<void> reload() async {
    await settle();
    await controller.load();
    await settle();
  }

  /// Lets queued work finish.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  group('loading', () {
    test(
      'loads pets, reminders and notifications once onboarding is done',
      () async {
        final r = _Rig();
        final bingo = await r.addPet('Bingo');
        r.health.seed(
          petId: bingo.id,
          petName: 'Bingo',
          type: RecordType.vaccine,
          name: 'Rabies',
          givenOn: DateTime(2025, 11, 12),
          nextDueOn: DateTime(2026, 11, 12),
        );
        r.notifications.items.add(
          AppNotification(
            id: 'n1',
            kind: NotificationKind.reminderDue,
            title: 'x',
            createdAt: _today,
          ),
        );
        await r.settle();

        final c = r.controller;
        expect(c.loaded, isTrue);
        expect(c.pets.map((p) => p.name), ['Bingo']);
        expect(c.selected?.name, 'Bingo');
        expect(c.reminders.single.label, 'Rabies booster');
        expect(c.recordsFor(bingo.id), hasLength(1));
        expect(c.unread, 1);
        expect(c.statusFor(bingo.id).state, PassportState.dueSoon);
        expect(c.nextFor(bingo.id)?.label, 'Rabies booster');
      },
    );

    test('waits until onboarding is finished', () async {
      final r = _Rig(onboarded: false);
      await r.addPet('Bingo');
      await r.settle();
      expect(r.controller.loaded, isFalse);
      expect(r.controller.pets, isEmpty);

      r.profiles.markOnboarded(_today);
      await r.session.refreshProfile();
      await r.settle();
      expect(r.controller.loaded, isTrue);
      expect(r.controller.pets, hasLength(1));
    });

    test('does nothing while signed out', () async {
      final r = _Rig(signedIn: false);
      await r.settle();
      expect(r.controller.loaded, isFalse);
    });

    test('a failure is shown, not thrown', () async {
      final r = _Rig();
      await r.addPet('Bingo');
      r.health.failNext = const AppFailure('We could not load the schedule.');
      await r.settle();
      expect(r.controller.error, 'We could not load the schedule.');
      expect(r.controller.loaded, isFalse);
      await r.controller.load();
      expect(r.controller.loaded, isTrue);
      expect(r.controller.error, isNull);
    });

    test('a broken notifications list does not stop the rest', () async {
      final r = _Rig();
      await r.addPet('Bingo');
      r.notifications.failNext = const AppFailure('nope');
      await r.reload();
      expect(r.controller.loaded, isTrue);
      expect(r.controller.notifications, isEmpty);
    });

    test('signing out forgets everything', () async {
      final r = _Rig();
      await r.addPet('Bingo');
      await r.reload();
      expect(r.controller.pets, isNotEmpty);
      await r.session.signOut();
      await r.settle();
      expect(r.controller.pets, isEmpty);
      expect(r.controller.loaded, isFalse);
      expect(r.controller.notifications, isEmpty);
    });
  });

  group('pets', () {
    test('selecting another pet loads its records', () async {
      final r = _Rig();
      final bingo = await r.addPet('Bingo');
      final mimi = await r.addPet('Mimi');
      r.health.seed(
        petId: mimi.id,
        petName: 'Mimi',
        type: RecordType.weight,
        name: 'Weight',
        givenOn: DateTime(2026, 10, 1),
        value: '4',
      );
      await r.reload();
      expect(r.controller.selected?.id, bingo.id);
      expect(r.controller.recordsFor(mimi.id), isEmpty);

      await r.controller.select(mimi.id);
      expect(r.controller.selected?.name, 'Mimi');
      expect(r.controller.recordsFor(mimi.id), hasLength(1));
      expect(r.controller.weightFor(mimi.id).latestKg, 4);
    });

    test('reminders can be filtered by pet', () async {
      final r = _Rig();
      final bingo = await r.addPet('Bingo');
      final mimi = await r.addPet('Mimi');
      r.health.seed(
        petId: bingo.id,
        petName: 'Bingo',
        type: RecordType.vaccine,
        name: 'Rabies',
        givenOn: DateTime(2025, 11, 12),
        nextDueOn: DateTime(2026, 11, 12),
      );
      r.health.seed(
        petId: mimi.id,
        petName: 'Mimi',
        type: RecordType.treatment,
        name: 'Tick & flea treatment',
        givenOn: DateTime(2026, 10, 28),
        nextDueOn: DateTime(2026, 11, 28),
      );
      await r.reload();
      expect(r.controller.remindersFor(null), hasLength(2));
      expect(r.controller.remindersFor(bingo.id).single.petName, 'Bingo');
      expect(r.controller.remindersFor(mimi.id).single.cadence, 'monthly');
    });
  });

  group('adding a record', () {
    test('saves it, and a repeating one makes a reminder', () async {
      final r = _Rig();
      final bingo = await r.addPet('Bingo');
      await r.reload();
      final ok = await r.controller.addRecord(
        type: RecordType.vaccine,
        name: 'Rabies',
        givenOn: DateTime(2026, 11, 5),
        nextDueOn: DateTime(2027, 11, 5),
        givenByName: 'Paws and Claws',
      );
      expect(ok, isTrue);
      expect(
        r.controller.recordsFor(bingo.id).single.sourceLabel,
        'Paws and Claws',
      );
      expect(
        r.controller.remindersFor(bingo.id).single.dueOn,
        DateTime(2027, 11, 5),
      );
    });

    test('a weight makes no reminder', () async {
      final r = _Rig();
      final bingo = await r.addPet('Bingo');
      await r.reload();
      await r.controller.addRecord(
        type: RecordType.weight,
        name: 'Weight',
        givenOn: DateTime(2026, 11, 1),
        value: '41 kg',
      );
      expect(r.controller.remindersFor(bingo.id), isEmpty);
      expect(r.controller.weightFor(bingo.id).latestKg, 41);
    });

    test('a failure keeps the form usable and saves nothing', () async {
      final r = _Rig();
      final bingo = await r.addPet('Bingo');
      await r.reload();
      r.health.failNext = const AppFailure(
        'We could not save the record. Nothing was saved.',
      );
      final ok = await r.controller.addRecord(
        type: RecordType.vaccine,
        name: 'Rabies',
        givenOn: DateTime(2026, 11, 5),
      );
      expect(ok, isFalse);
      expect(r.controller.error, contains('Nothing was saved'));
      expect(r.controller.recordsFor(bingo.id), isEmpty);
      expect(r.controller.busy, isFalse);
    });

    test('a photo is passed along', () async {
      final r = _Rig();
      await r.addPet('Bingo');
      await r.reload();
      await r.controller.addRecord(
        type: RecordType.vaccine,
        name: 'Rabies',
        givenOn: DateTime(2026, 11, 5),
        attachment: PickedPhoto(Uint8List.fromList([1, 2, 3])),
      );
      expect(r.health.attachments, 1);
    });

    test('with no pet nothing happens', () async {
      final r = _Rig();
      await r.reload();
      expect(
        await r.controller.addRecord(
          type: RecordType.vaccine,
          name: 'x',
          givenOn: _today,
        ),
        isFalse,
      );
    });
  });

  group('mark done', () {
    Future<(_Rig, Pet)> ready() async {
      final r = _Rig();
      final bingo = await r.addPet('Bingo');
      r.health.seed(
        petId: bingo.id,
        petName: 'Bingo',
        type: RecordType.vaccine,
        name: 'Rabies',
        givenOn: DateTime(2025, 11, 12),
        nextDueOn: DateTime(2026, 11, 12),
      );
      await r.reload();
      return (r, bingo);
    }

    test('records the dose and schedules the next one a year on', () async {
      final (r, bingo) = await ready();
      final due = r.controller.reminders.single;
      expect(await r.controller.markDone(due), isTrue);

      expect(r.controller.lastNextDue, DateTime(2027, 11, 5));
      final open = r.controller.remindersFor(bingo.id);
      expect(open.single.dueOn, DateTime(2027, 11, 5));
      expect(open.single.cadence, 'yearly');
      expect(r.controller.recordsFor(bingo.id), hasLength(2));
    });

    test('can be dated earlier than today', () async {
      final (r, bingo) = await ready();
      await r.controller.markDone(
        r.controller.reminders.single,
        date: DateTime(2026, 11, 1),
      );
      expect(
        r.controller.remindersFor(bingo.id).single.dueOn,
        DateTime(2027, 11, 1),
      );
    });

    test('not in the future, and not twice', () async {
      final (r, _) = await ready();
      final due = r.controller.reminders.single;
      expect(
        await r.controller.markDone(due, date: DateTime(2026, 11, 9)),
        isFalse,
      );
      expect(r.controller.error, contains('future'));
      expect(await r.controller.markDone(due), isTrue);
      expect(await r.controller.markDone(due), isFalse);
    });

    test('the status clears once the overdue dose is done', () async {
      final r = _Rig();
      final bingo = await r.addPet('Bingo');
      r.health.seed(
        petId: bingo.id,
        petName: 'Bingo',
        type: RecordType.vaccine,
        name: 'Rabies',
        givenOn: DateTime(2025, 10, 1),
        nextDueOn: DateTime(2026, 10, 1),
      );
      await r.reload();
      expect(r.controller.statusFor(bingo.id).state, PassportState.overdue);
      await r.controller.markDone(r.controller.reminders.single);
      expect(r.controller.statusFor(bingo.id).state, PassportState.upToDate);
    });
  });

  group('share with a vet', () {
    test('makes a link for the selected pet and can stop it', () async {
      final r = _Rig();
      final bingo = await r.addPet('Bingo');
      await r.reload();
      final link = await r.controller.createShare({
        ShareScope.health,
        ShareScope.write,
      });
      expect(link, isNotNull);
      expect(link!.token.length, 48);
      expect(link.scopes, {ShareScope.health, ShareScope.write});
      expect(link.expiresAt, _today.add(const Duration(hours: 24)));
      expect(r.health.shares.single.petId, bingo.id);

      await r.controller.revokeShare(link.id);
      expect(r.health.shares.single.revoked, isTrue);
    });

    test('a failure returns no link and says why', () async {
      final r = _Rig();
      await r.addPet('Bingo');
      await r.reload();
      r.health.failNext = const AppFailure(
        'We could not make a share link. Try again.',
      );
      expect(await r.controller.createShare({ShareScope.health}), isNull);
      expect(r.controller.error, contains('share link'));
    });
  });

  group('notifications', () {
    test('mark one or all as read', () async {
      final r = _Rig();
      await r.addPet('Bingo');
      r.notifications.items.addAll([
        for (final id in ['a', 'b', 'c'])
          AppNotification(
            id: id,
            kind: NotificationKind.reminderDue,
            title: id,
            createdAt: _today,
          ),
      ]);
      await r.reload();
      expect(r.controller.unread, 3);
      await r.controller.markNotificationRead('a');
      expect(r.controller.unread, 2);
      expect(r.notifications.items.first.read, isTrue);
      await r.controller.markAllRead();
      expect(r.controller.unread, 0);
      expect(r.notifications.items.every((n) => n.read), isTrue);
    });

    test('refreshing asks the server again', () async {
      final r = _Rig();
      await r.addPet('Bingo');
      await r.reload();
      final before = r.notifications.loads;
      await r.controller.refreshNotifications();
      expect(r.notifications.loads, before + 1);
    });
  });
}
