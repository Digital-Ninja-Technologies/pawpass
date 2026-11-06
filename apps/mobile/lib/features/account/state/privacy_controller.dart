import 'package:flutter/foundation.dart';

import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../domain/models.dart';

/// Privacy and sharing: who the owner is sharing records with right now, blocked accounts, and stopping either.
class PrivacyController extends ChangeNotifier {
  PrivacyController(this._services);

  final AppServices _services;
  var _disposed = false;

  List<ActiveShare> shares = const [];
  List<BlockedAccount> blocked = const [];
  var loading = false;
  var loaded = false;
  String? loadError;

  /// Shown under the list after a failed Stop sharing or Unblock.
  String? actionError;
  final _busyIds = <String>{};

  bool isBusy(String id) => _busyIds.contains(id);

  Future<void> load() async {
    if (loading) {
      return;
    }
    loading = true;
    loadError = null;
    _notify();
    try {
      shares = await _services.account.activeShares();
      blocked = await _services.account.blocks();
      loaded = true;
    } on AppFailure catch (e) {
      loadError = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Ends a share: the link or QR code stops working at once.
  Future<bool> stopSharing(String shareId) async {
    if (isBusy(shareId)) {
      return false;
    }
    _busyIds.add(shareId);
    actionError = null;
    _notify();
    try {
      await _services.health.revokeShare(shareId);
      shares = [
        for (final s in shares)
          if (s.id != shareId) s,
      ];
      return true;
    } on AppFailure catch (e) {
      actionError = e.message;
      return false;
    } finally {
      _busyIds.remove(shareId);
      _notify();
    }
  }

  Future<bool> unblock(String blockId) async {
    if (isBusy(blockId)) {
      return false;
    }
    _busyIds.add(blockId);
    actionError = null;
    _notify();
    try {
      await _services.account.unblock(blockId);
      blocked = [
        for (final b in blocked)
          if (b.id != blockId) b,
      ];
      return true;
    } on AppFailure catch (e) {
      actionError = e.message;
      return false;
    } finally {
      _busyIds.remove(blockId);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
