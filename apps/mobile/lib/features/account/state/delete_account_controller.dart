import 'package:flutter/foundation.dart';

import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';

/// What a person types to confirm. Matches the server.
const deleteWord = 'DELETE';

bool isDeleteConfirmed(String typed) => typed.trim().toUpperCase() == deleteWord;

/// Deleting the account: shows what is in the way first, asks for the word DELETE, then erases and signs out.
class DeleteAccountController extends ChangeNotifier {
  DeleteAccountController(this._services);

  final AppServices _services;
  var _disposed = false;

  List<String> blockers = const [];
  var loading = false;
  var loaded = false;
  String? loadError;

  var deleting = false;
  String? deleteError;

  /// Set once the account is erased. The screen then signs out.
  var done = false;

  bool get canDelete => loaded && blockers.isEmpty && !deleting && !done;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    loadError = null;
    _notify();
    try {
      blockers = await _services.account.deletionBlockers();
      loaded = true;
    } on AppFailure catch (e) {
      loadError = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Erases the account. Returns true when it is done; the person is signed out by [finish].
  Future<bool> delete(String typed) async {
    if (!canDelete) return false;
    if (!isDeleteConfirmed(typed)) {
      deleteError = 'Type $deleteWord to confirm.';
      _notify();
      return false;
    }
    deleting = true;
    deleteError = null;
    _notify();
    try {
      await _services.account.deleteAccount();
      done = true;
      return true;
    } on AppFailure catch (e) {
      deleteError = e.message;
      // The reason may be new (a booking began since this screen opened): show the current list.
      try {
        blockers = await _services.account.deletionBlockers();
      } on AppFailure {
        // Keep what is on screen.
      }
      return false;
    } finally {
      deleting = false;
      _notify();
    }
  }

  /// Signs the person out. The sign in is already gone on the server, so a failure here does not matter.
  Future<void> finish() async {
    try {
      await _services.auth.signOut();
    } catch (_) {
      // The session is useless now; the next start lands on Welcome.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
