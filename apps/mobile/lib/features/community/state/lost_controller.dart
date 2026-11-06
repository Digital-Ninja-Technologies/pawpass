import 'package:flutter/foundation.dart';

import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/session_controller.dart';
import '../domain/models.dart';

/// Lost pet alerts near the person, one alert's detail, raising an alert, and sharing a sighting.
class LostController extends ChangeNotifier {
  LostController(this._services, this._session) {
    _session.addListener(_onSession);
  }

  final AppServices _services;
  final SessionController _session;
  var _disposed = false;

  DateTime get now => _services.now();

  // ------------------------------------------------------------------ list

  List<LostAlertSummary> alerts = const [];
  bool loading = false;
  bool loaded = false;
  String? error;
  ({double lat, double lng})? where;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      where = await _services.location.current();
      final w = where;
      if (w != null) {
        // So alerts raised near here can reach this person. A convenience: never blocks the list.
        _services.community.shareLocation(w.lat, w.lng);
      }
      alerts = await _services.community.lostNearby(lat: w?.lat, lng: w?.lng);
      loaded = true;
    } on AppFailure catch (e) {
      error = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  // ------------------------------------------------------------------ one alert

  LostAlertDetail? detail;
  bool loadingDetail = false;
  String? detailError;
  bool busy = false;
  String? actionError;
  String? notice;

  Future<void> loadDetail(String alertId) async {
    detail = null;
    detailError = null;
    actionError = null;
    notice = null;
    loadingDetail = true;
    _notify();
    try {
      final w = where ?? await _services.location.current();
      where = w;
      detail = await _services.community.lostDetail(
        alertId,
        lat: w?.lat,
        lng: w?.lng,
      );
    } on AppFailure catch (e) {
      detailError = e.message;
    } finally {
      loadingDetail = false;
      _notify();
    }
  }

  /// "I've seen him": shares where the phone is now.
  Future<bool> shareSighting(String alertId, {String? note}) async {
    if (busy) return false;
    busy = true;
    actionError = null;
    notice = null;
    _notify();
    try {
      final here = await _services.location.current();
      if (here == null) {
        actionError = 'Turn on location to share where you saw them, or message the owner.';
        return false;
      }
      await _services.community.reportSighting(
        alertId,
        lat: here.lat,
        lng: here.lng,
        note: note,
      );
      notice = 'Thank you. The owner has been told.';
      await loadDetail(alertId);
      notice = 'Thank you. The owner has been told.';
      return true;
    } on AppFailure catch (e) {
      actionError = e.message;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> close(String alertId, {required bool found}) async {
    if (busy) return false;
    busy = true;
    actionError = null;
    _notify();
    try {
      await _services.community.closeAlert(alertId, found: found);
      await load();
      return true;
    } on AppFailure catch (e) {
      actionError = e.message;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Opens (or reuses) the chat with the owner. Returns the conversation id.
  Future<String?> openChat(String alertId) async {
    if (busy) return null;
    busy = true;
    actionError = null;
    _notify();
    try {
      return await _services.community.openAlertChat(alertId);
    } on AppFailure catch (e) {
      actionError = e.message;
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  // ------------------------------------------------------------------ raising an alert

  ({double lat, double lng})? spot;
  bool locating = false;
  bool sending = false;
  String? sendError;

  /// Uses where the phone is as the place the pet was last seen.
  Future<bool> useMyLocation() async {
    locating = true;
    sendError = null;
    _notify();
    try {
      spot = await _services.location.current();
      if (spot == null) {
        sendError =
            'We could not get your location. Turn on location, then try again.';
      }
      return spot != null;
    } finally {
      locating = false;
      _notify();
    }
  }

  void setSpot(double lat, double lng) {
    spot = (lat: lat, lng: lng);
    _notify();
  }

  /// Returns the new alert's id, or null (see [sendError]).
  Future<String?> raise({
    required String petId,
    required String address,
    required DateTime seenAt,
    required String description,
    required int radiusM,
  }) async {
    final s = spot;
    if (sending) return null;
    if (s == null) {
      sendError = 'Choose where your pet was last seen.';
      _notify();
      return null;
    }
    sending = true;
    sendError = null;
    _notify();
    try {
      final r = await _services.community.createLostAlert(
        petId: petId,
        lat: s.lat,
        lng: s.lng,
        address: address.trim(),
        seenAt: seenAt,
        description: description.trim(),
        radiusM: radiusM,
      );
      lastNotified = r.notified;
      spot = null;
      await load();
      return r.alertId;
    } on AppFailure catch (e) {
      sendError = e.message;
      return null;
    } finally {
      sending = false;
      _notify();
    }
  }

  int lastNotified = 0;

  void startRaise() {
    spot = null;
    sendError = null;
    _notify();
  }

  // ------------------------------------------------------------------ lifecycle

  void _onSession() {
    if (_disposed) return;
    if (_session.status == SessionStatus.signedOut) reset();
  }

  void reset() {
    alerts = const [];
    loaded = false;
    detail = null;
    where = null;
    spot = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_onSession);
    super.dispose();
  }
}
