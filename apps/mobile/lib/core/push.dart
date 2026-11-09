import 'dart:async';

import 'package:flutter/foundation.dart';

import 'offline_cache.dart' show KeyValueStore, MemoryKeyValueStore;

/// A person tapped a notification. [link] is where it should take them (see `notificationRoute`).
class PushTap {
  const PushTap(this.link);
  final String? link;
}

/// What the phone's push system offers. A real build uses Firebase ([FirebasePushPlatform]); tests use a fake.
abstract class PushPlatform {
  /// False when push cannot work here (no Firebase setup in this build, or a platform without it).
  bool get available;

  /// 'android' or 'ios'.
  String get platformName;

  /// True when notifications are already allowed (asks nothing).
  Future<bool> permissionGranted();

  /// Asks the phone for permission to show notifications. The phone shows its own question, and only once.
  Future<bool> requestPermission();

  /// This phone's push address, or null if it is not ready yet (it arrives through [tokenRefreshed] then).
  Future<String?> token();
  Stream<String> get tokenRefreshed;

  /// Forgets this phone's push address, so the next person to sign in gets a fresh one.
  Future<void> deleteToken();

  /// A notification was tapped while the app was open in the background.
  Stream<PushTap> get taps;

  /// The notification that opened the app from closed, if any.
  Future<PushTap?> launchTap();

  /// A notification arrived while the app was open.
  Stream<void> get foreground;
}

/// Used when push cannot work (the build has no Firebase setup, or in tests that do not care).
class NoPushPlatform implements PushPlatform {
  const NoPushPlatform();

  @override
  bool get available => false;
  @override
  String get platformName => '';
  @override
  Future<bool> permissionGranted() async => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRefreshed => const Stream.empty();
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<PushTap> get taps => const Stream.empty();
  @override
  Future<PushTap?> launchTap() async => null;
  @override
  Stream<void> get foreground => const Stream.empty();
}

/// Tells the server which phone belongs to the signed in person.
abstract class PushRepository {
  Future<void> register(String token, String platform);
  Future<void> unregister(String token);
}

class NoPushRepository implements PushRepository {
  const NoPushRepository();
  @override
  Future<void> register(String token, String platform) async {}
  @override
  Future<void> unregister(String token) async {}
}

/// Remembers calls, for tests.
class RecordingPushRepository implements PushRepository {
  final List<String> registered = [];
  final List<String> unregistered = [];
  Object? failWith;

  @override
  Future<void> register(String token, String platform) async {
    if (failWith != null) throw failWith!;
    registered.add(token);
  }

  @override
  Future<void> unregister(String token) async {
    if (failWith != null) throw failWith!;
    unregistered.add(token);
  }
}

/// Gets this phone ready for push notifications and keeps the server's copy of its address right.
///
///  * Asks for permission once, when the person has finished setting up (the phone only lets an app ask once).
///  * Registers the phone's address with the server, and again whenever it changes.
///  * Removes the address when the person signs out, so the next person on this phone is not sent their news.
///
/// Nothing here can stop the app: every failure is swallowed (push is a convenience, not a requirement).
class PushService {
  PushService({
    required this.platform,
    required this.repository,
    KeyValueStore? store,
  }) : _store = store ?? MemoryKeyValueStore();

  /// Push switched off: used by tests and demo builds.
  PushService.off()
    : platform = const NoPushPlatform(),
      repository = const NoPushRepository(),
      _store = MemoryKeyValueStore();

  final PushPlatform platform;
  final PushRepository repository;
  final KeyValueStore _store;

  static const askedKey = 'push.asked';

  String? _token;
  StreamSubscription<String>? _refresh;

  bool get available => platform.available;

  Stream<PushTap> get taps => platform.taps;
  Stream<void> get foreground => platform.foreground;
  Future<PushTap?> launchTap() => platform.launchTap();

  /// Call once a person is signed in and has finished onboarding.
  Future<void> signedIn() async {
    if (!platform.available) return;
    try {
      final asked = await _store.read(askedKey) != null;
      bool allowed;
      if (asked) {
        allowed = await platform.permissionGranted();
      } else {
        await _store.write(askedKey, '1');
        allowed = await platform.requestPermission();
      }
      if (!allowed) return;
      await _refresh?.cancel();
      _refresh = platform.tokenRefreshed.listen(_register);
      final token = await platform.token();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('push setup failed: $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await repository.register(token, platform.platformName);
      _token = token;
    } catch (e) {
      debugPrint('push register failed: $e');
    }
  }

  /// Call before signing out (while the server still knows who this is).
  Future<void> signingOut() async {
    await _refresh?.cancel();
    _refresh = null;
    if (!platform.available) return;
    try {
      final token = _token ?? await platform.token();
      if (token != null) await repository.unregister(token);
    } catch (e) {
      debugPrint('push unregister failed: $e');
    }
    _token = null;
    try {
      await platform.deleteToken();
    } catch (e) {
      debugPrint('push token not deleted: $e');
    }
  }

  Future<void> dispose() async {
    await _refresh?.cancel();
    _refresh = null;
  }
}
