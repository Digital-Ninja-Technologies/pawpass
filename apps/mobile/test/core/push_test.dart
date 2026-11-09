import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/core/offline_cache.dart';
import 'package:pawpass/core/push.dart';
import 'package:pawpass/features/booking/ui/bookings_screen.dart';
import 'package:pawpass/features/health/ui/schedule_screen.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/state/session_controller.dart';

/// A phone whose push system we control.
class FakePushPlatform implements PushPlatform {
  FakePushPlatform({
    this.available = true,
    this.allowed = true,
    this.currentToken = 'token-aaaaaaaaaaaaaaaaaaaaaaaa',
  });

  @override
  bool available;
  bool allowed;
  String? currentToken;
  int asked = 0;
  int deleted = 0;
  PushTap? launch;

  final refresh = StreamController<String>.broadcast();
  final tapped = StreamController<PushTap>.broadcast();
  final arrived = StreamController<void>.broadcast();

  @override
  String get platformName => 'android';
  @override
  Future<bool> permissionGranted() async => allowed;
  @override
  Future<bool> requestPermission() async {
    asked++;
    return allowed;
  }

  @override
  Future<String?> token() async => currentToken;
  @override
  Stream<String> get tokenRefreshed => refresh.stream;
  @override
  Future<void> deleteToken() async {
    deleted++;
    currentToken = 'token-bbbbbbbbbbbbbbbbbbbbbbbb';
  }

  @override
  Stream<PushTap> get taps => tapped.stream;
  @override
  Future<PushTap?> launchTap() async => launch;
  @override
  Stream<void> get foreground => arrived.stream;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakePushPlatform phone;
  late RecordingPushRepository server;
  late MemoryKeyValueStore store;

  PushService service() =>
      PushService(platform: phone, repository: server, store: store);

  setUp(() {
    phone = FakePushPlatform();
    server = RecordingPushRepository();
    store = MemoryKeyValueStore();
  });

  group('PushService', () {
    test('a build without push does nothing at all', () async {
      phone.available = false;
      final push = service();
      await push.signedIn();
      await push.signingOut();
      expect(phone.asked, 0);
      expect(server.registered, isEmpty);
      expect(server.unregistered, isEmpty);
    });

    test('asks once, then registers this phone', () async {
      await service().signedIn();
      expect(phone.asked, 1);
      expect(server.registered, ['token-aaaaaaaaaaaaaaaaaaaaaaaa']);
    });

    test(
      'the next time it does not ask again, but still registers if allowed',
      () async {
        await service().signedIn();
        await service().signedIn();
        expect(phone.asked, 1);
        expect(server.registered, hasLength(2));
      },
    );

    test(
      'a person who said no is not asked again and nothing is sent',
      () async {
        phone.allowed = false;
        await service().signedIn();
        await service().signedIn();
        expect(phone.asked, 1);
        expect(server.registered, isEmpty);
      },
    );

    test('a new address is registered when the phone changes it', () async {
      final push = service();
      await push.signedIn();
      phone.refresh.add('token-cccccccccccccccccccccccc');
      await _settle();
      expect(server.registered.last, 'token-cccccccccccccccccccccccc');
    });

    test(
      'an address that is not ready yet is registered when it arrives',
      () async {
        phone.currentToken = null;
        final push = service();
        await push.signedIn();
        expect(server.registered, isEmpty);
        phone.refresh.add('token-dddddddddddddddddddddddd');
        await _settle();
        expect(server.registered, ['token-dddddddddddddddddddddddd']);
      },
    );

    test('signing out removes this phone and forgets its address', () async {
      final push = service();
      await push.signedIn();
      await push.signingOut();
      expect(server.unregistered, ['token-aaaaaaaaaaaaaaaaaaaaaaaa']);
      expect(phone.deleted, 1);
      // Nothing more is registered from the old subscription.
      phone.refresh.add('token-eeeeeeeeeeeeeeeeeeeeeeee');
      await _settle();
      expect(server.registered, ['token-aaaaaaaaaaaaaaaaaaaaaaaa']);
    });

    test('the next person on the phone gets a fresh address', () async {
      final push = service();
      await push.signedIn();
      await push.signingOut();
      await push.signedIn();
      expect(server.registered.last, 'token-bbbbbbbbbbbbbbbbbbbbbbbb');
    });

    test('a server that is down never stops the app', () async {
      server.failWith = StateError('offline');
      final push = service();
      await push.signedIn();
      await push.signingOut();
      expect(phone.deleted, 1);
    });
  });

  test('signing out through the session removes this phone first', () async {
    final push = service();
    final services = inMemoryServices(
      signedInAs: 'tolu@example.com',
      push: push,
    );
    final session = SessionController(services);
    await push.signedIn();
    await session.signOut();
    expect(server.unregistered, ['token-aaaaaaaaaaaaaaaaaaaaaaaa']);
    expect(services.auth.signedIn, isFalse);
    session.dispose();
  });

  test('a push system that hangs does not stop signing out', () async {
    final slow = _HangingPlatform();
    final services = inMemoryServices(
      signedInAs: 'tolu@example.com',
      push: PushService(platform: slow, repository: server, store: store),
    );
    final session = SessionController(services);
    await session.signOut();
    expect(services.auth.signedIn, isFalse);
    session.dispose();
  });

  group('in the app', () {
    final today = DateTime(2026, 11, 5, 9);

    Future<AppServices> start(
      WidgetTester tester, {
      bool onboarded = true,
    }) async {
      final services = inMemoryServices(
        now: () => today,
        signedInAs: 'tolu@example.com',
        push: service(),
      );
      final profiles = services.profiles as InMemoryProfileRepository;
      await profiles.save(firstName: 'Tolu');
      if (onboarded) {
        profiles.markOnboarded(today);
        await services.pets.createPassport(
          pet: const PetInput(
            name: 'Bingo',
            species: Species.dog,
            sex: PetSex.male,
          ),
          records: const [],
          channels: {ReminderChannel.push},
        );
      }
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(PawPassApp(services: services));
      await tester.pumpAndSettle();
      return services;
    }

    testWidgets(
      'a person who has finished setting up is asked, and registered',
      (tester) async {
        await start(tester);
        expect(phone.asked, 1);
        expect(server.registered, hasLength(1));
      },
    );

    testWidgets('nobody is asked in the middle of setting up', (tester) async {
      await start(tester, onboarded: false);
      expect(phone.asked, 0);
      expect(server.registered, isEmpty);
    });

    testWidgets('tapping a notification opens the screen it is about', (
      tester,
    ) async {
      await start(tester);
      phone.tapped.add(const PushTap('/schedule'));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleScreen), findsOneWidget);
    });

    testWidgets('a link the app does not know is ignored', (tester) async {
      await start(tester);
      phone.tapped.add(const PushTap('/somewhere/new'));
      phone.tapped.add(const PushTap(null));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleScreen), findsNothing);
      expect(find.byType(BookingsScreen), findsNothing);
    });

    testWidgets('a notification that opened the app from closed is followed', (
      tester,
    ) async {
      phone.launch = const PushTap('/bookings');
      await start(tester);
      expect(find.byType(BookingsScreen), findsOneWidget);
    });

    testWidgets('signing out removes this phone from the server', (
      tester,
    ) async {
      final services = await start(tester);
      await tester.runAsync(() => services.push.signingOut());
      expect(server.unregistered, isNotEmpty);
    });
  });
}

/// Never answers: signing out must not wait for it for ever.
class _HangingPlatform extends FakePushPlatform {
  @override
  Future<String?> token() => Completer<String?>().future;
}
