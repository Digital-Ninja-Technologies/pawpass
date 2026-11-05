import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories.dart';
import '../domain/models.dart';

enum SessionStatus { loading, signedOut, signedIn }

/// Who is signed in and whether they have finished setting up. The router reads this to decide
/// where to send people.
class SessionController extends ChangeNotifier {
  SessionController(this._services) {
    _sub = _services.auth.signedInChanges.listen(_onAuthChange);
    _start();
  }

  final AppServices _services;
  StreamSubscription<bool>? _sub;
  var _disposed = false;

  SessionStatus status = SessionStatus.loading;
  Profile? profile;

  bool get signedIn => status == SessionStatus.signedIn;
  bool get onboarded => profile?.onboarded ?? false;

  Future<void> _start() async {
    if (!_services.auth.signedIn) {
      _set(SessionStatus.signedOut, null);
      return;
    }
    await refreshProfile();
  }

  void _onAuthChange(bool signedIn) {
    if (signedIn) {
      refreshProfile();
    } else {
      _set(SessionStatus.signedOut, null);
    }
  }

  /// Reloads the profile. If it cannot be read (offline), the person stays signed in and is
  /// treated as not yet onboarded until it can be.
  Future<void> refreshProfile() async {
    Profile? loaded;
    try {
      loaded = await _services.profiles.load();
    } on AppFailure {
      loaded = profile ?? const Profile();
    }
    _set(SessionStatus.signedIn, loaded);
  }

  Future<void> signOut() => _services.auth.signOut();

  void _set(SessionStatus s, Profile? p) {
    if (_disposed) return;
    status = s;
    profile = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
