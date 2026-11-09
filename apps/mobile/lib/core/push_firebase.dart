import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push.dart';

/// Push through Firebase Cloud Messaging.
///
/// Uses the classic FCM registration token (`getToken`, `onTokenRefresh`, `deleteToken`), which the server's
/// `messages:send` call takes as `token`. Newer versions of the package mark these as deprecated in favour of a
/// Firebase installation id scheme; this build deliberately stays on the token the server is written for. If you
/// move to the new scheme, change the server to send to that id too.
///
/// [create] returns a platform that does nothing when this build has no Firebase setup
/// (no `google-services.json` on Android, no `GoogleService-Info.plist` on iOS), so the app still runs.
class FirebasePushPlatform implements PushPlatform {
  FirebasePushPlatform._(this._messaging, this.platformName);

  final FirebaseMessaging _messaging;

  @override
  final String platformName;

  static Future<PushPlatform> create() async {
    final name = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => '',
    };
    if (name.isEmpty) return const NoPushPlatform();
    try {
      await Firebase.initializeApp();
      return FirebasePushPlatform._(FirebaseMessaging.instance, name);
    } catch (e) {
      debugPrint('Push is off: Firebase is not set up in this build ($e)');
      return const NoPushPlatform();
    }
  }

  @override
  bool get available => true;

  @override
  Future<bool> permissionGranted() async {
    final s = await _messaging.getNotificationSettings();
    return _allowed(s.authorizationStatus);
  }

  @override
  Future<bool> requestPermission() async {
    final s = await _messaging.requestPermission();
    return _allowed(s.authorizationStatus);
  }

  static bool _allowed(AuthorizationStatus s) =>
      s == AuthorizationStatus.authorized ||
      s == AuthorizationStatus.provisional;

  @override
  Future<String?> token() async {
    try {
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (e) {
      // On iPhone the address is not ready for a moment after start; it arrives through tokenRefreshed.
      debugPrint('push token not ready: $e');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefreshed => _messaging.onTokenRefresh;

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<PushTap> get taps => FirebaseMessaging.onMessageOpenedApp.map(
    (m) => PushTap(m.data['link'] as String?),
  );

  @override
  Future<PushTap?> launchTap() async {
    final m = await _messaging.getInitialMessage();
    return m == null ? null : PushTap(m.data['link'] as String?);
  }

  @override
  Stream<void> get foreground => FirebaseMessaging.onMessage.map((_) {});
}

/// Registers this phone through the `register_device` and `unregister_device` database functions.
class SupabasePushRepository implements PushRepository {
  SupabasePushRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> register(String token, String platform) async {
    await _client.rpc(
      'register_device',
      params: {'p_token': token, 'p_platform': platform},
    );
  }

  @override
  Future<void> unregister(String token) async {
    await _client.rpc('unregister_device', params: {'p_token': token});
  }
}
