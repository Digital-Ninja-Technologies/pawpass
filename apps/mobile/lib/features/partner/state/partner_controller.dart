import 'package:flutter/foundation.dart';

import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/session_controller.dart';
import '../data/partner_repository.dart';
import '../domain/models.dart';
import '../domain/partner_logic.dart';

/// Becoming a partner, the partner dashboards and money, listing pets, and help and support.
/// Forgets everything on sign out.
class PartnerController extends ChangeNotifier {
  PartnerController(this._services, this._session) {
    _session.addListener(_onSession);
  }

  final AppServices _services;
  final SessionController _session;
  var _disposed = false;

  DateTime get now => _services.now();

  // ------------------------------------------------------------------ mode

  /// True while the person is looking at the partner side of the app.
  bool inPartnerMode = false;

  void enterPartnerMode() {
    inPartnerMode = true;
    _notify();
  }

  void leavePartnerMode() {
    inPartnerMode = false;
    _notify();
  }

  // ----------------------------------------------------------- application

  PartnerApplication? application;
  bool applicationLoaded = false;
  bool loadingApplication = false;
  String? applicationError;

  /// The kind picked on "Become a partner", before the business details are saved.
  PartnerType? chosenType;

  bool get isApprovedPartner => application?.approved ?? false;
  PartnerType? get type => application?.type;

  void chooseType(PartnerType t) {
    chosenType = t;
    _notify();
  }

  Future<void> loadApplication() async {
    if (loadingApplication) {
      return;
    }
    loadingApplication = true;
    applicationError = null;
    _notify();
    try {
      application = await _services.partner.application();
      applicationLoaded = true;
    } on AppFailure catch (e) {
      applicationError = e.message;
    } finally {
      loadingApplication = false;
      _notify();
    }
  }

  // The first step: kind, name and area.
  bool saving = false;
  String? saveError;

  Future<bool> saveBusiness({
    required PartnerType type,
    required String name,
    required String area,
  }) async {
    if (saving) {
      return false;
    }
    final problem = validateBusinessName(name) ?? validateArea(area);
    if (problem != null) {
      saveError = problem;
      _notify();
      return false;
    }
    return _act(() async {
      await _services.partner.start(type: type, businessName: name, area: area);
      application = await _services.partner.application();
    });
  }

  Future<bool> addDocument(DocumentKind kind, PickedPhoto photo) {
    final id = application?.partnerId;
    if (id == null) {
      return Future.value(false);
    }
    return _act(() async {
      await _services.partner.addDocument(id, kind, photo);
      application = await _services.partner.application();
    });
  }

  Future<bool> savePayout({
    required Bank bank,
    required String accountNumber,
    required String accountName,
  }) {
    final id = application?.partnerId;
    final problem =
        validateAccountNumber(accountNumber) ??
        validateAccountName(accountName);
    if (id == null) {
      return Future.value(false);
    }
    if (problem != null) {
      saveError = problem;
      _notify();
      return Future.value(false);
    }
    return _act(() async {
      await _services.partner.savePayout(
        id,
        bankCode: bank.code,
        bankName: bank.name,
        accountNumber: accountNumber.trim(),
        accountName: accountName.trim(),
      );
      application = await _services.partner.application();
    });
  }

  Future<bool> submit() {
    final id = application?.partnerId;
    if (id == null) {
      return Future.value(false);
    }
    return _act(() async {
      await _services.partner.submit(id);
      application = await _services.partner.application();
    });
  }

  /// Runs one save. Returns true if it worked; otherwise [saveError] says why.
  Future<bool> _act(Future<void> Function() work) async {
    if (saving) {
      return false;
    }
    saving = true;
    saveError = null;
    _notify();
    try {
      await work();
      return true;
    } on AppFailure catch (e) {
      saveError = e.message;
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  // ------------------------------------------------------------ dashboard

  PartnerDashboard? dashboard;
  bool loadingDashboard = false;
  String? dashboardError;

  Future<void> loadDashboard() async {
    final id = application?.partnerId;
    if (id == null || loadingDashboard) {
      return;
    }
    loadingDashboard = true;
    dashboardError = null;
    _notify();
    try {
      dashboard = await _services.partner.dashboard(id);
    } on AppFailure catch (e) {
      dashboardError = e.message;
    } finally {
      loadingDashboard = false;
      _notify();
    }
  }

  /// Loads the application, then the dashboard if the partner is approved.
  Future<void> refresh() async {
    await loadApplication();
    if (isApprovedPartner) {
      await Future.wait([loadDashboard(), loadEarnings()]);
    }
  }

  // -------------------------------------------------------------- earnings

  Earnings? earnings;
  bool loadingEarnings = false;
  String? earningsError;

  Future<void> loadEarnings() async {
    final id = application?.partnerId;
    if (id == null || loadingEarnings) {
      return;
    }
    loadingEarnings = true;
    earningsError = null;
    _notify();
    try {
      earnings = await _services.partner.earnings(id);
    } on AppFailure catch (e) {
      earningsError = e.message;
    } finally {
      loadingEarnings = false;
      _notify();
    }
  }

  // -------------------------------------------------------------- listings

  bool publishing = false;
  String? publishError;

  /// Publishes a pet or litter. Returns true when it is live.
  Future<bool> publish(NewListing listing, {PickedPhoto? photo}) async {
    final id = application?.partnerId;
    if (id == null || publishing) {
      return false;
    }
    publishing = true;
    publishError = null;
    _notify();
    try {
      await _services.partner.createListings(id, listing, photo: photo);
      dashboard = await _services.partner.dashboard(id);
      return true;
    } on AppFailure catch (e) {
      publishError = e.message;
      return false;
    } finally {
      publishing = false;
      _notify();
    }
  }

  String? actionError;

  Future<bool> setListingLive(String listingId, {required bool live}) =>
      _dash(() => _services.partner.setListingLive(listingId, live: live));

  Future<bool> decide(String applicationId, ApplicationDecision d) =>
      _dash(() => _services.partner.decide(applicationId, d));

  /// The shelter hands the pet over. Returns the transfer id for the adopter, or null on failure.
  Future<String?> completeAdoption(String applicationId) async {
    String? transfer;
    final ok = await _dash(() async {
      transfer = await _services.partner.completeAdoption(applicationId);
    });
    return ok ? transfer : null;
  }

  Future<String?> chatWith(String applicationId) async {
    actionError = null;
    try {
      return await _services.partner.openApplicationChat(applicationId);
    } on AppFailure catch (e) {
      actionError = e.message;
      _notify();
      return null;
    }
  }

  /// Runs a change, then refreshes the dashboard. [actionError] says why it failed.
  Future<bool> _dash(Future<void> Function() work) async {
    actionError = null;
    busy = true;
    _notify();
    try {
      await work();
    } on AppFailure catch (e) {
      actionError = e.message;
      return false;
    } finally {
      busy = false;
      _notify();
    }
    await loadDashboardQuietly();
    return true;
  }

  bool busy = false;

  Future<void> loadDashboardQuietly() async {
    final id = application?.partnerId;
    if (id == null) {
      return;
    }
    try {
      dashboard = await _services.partner.dashboard(id);
    } on AppFailure {
      // Keep what is on screen.
    }
    _notify();
  }

  // ------------------------------------------------------- seller on orders

  bool sellerBusy = false;
  String? sellerError;

  /// The seller confirms the handover or cancels an order. Returns true if it went through.
  Future<bool> sellerAction(
    Future<void> Function(PartnerRepository r) work,
  ) async {
    if (sellerBusy) {
      return false;
    }
    sellerBusy = true;
    sellerError = null;
    _notify();
    try {
      await work(_services.partner);
      return true;
    } on AppFailure catch (e) {
      sellerError = e.message;
      return false;
    } finally {
      sellerBusy = false;
      _notify();
    }
  }

  Future<bool> confirmHandover(String orderId) =>
      sellerAction((r) => r.confirmHandover(orderId));

  Future<bool> cancelOrder(String orderId) =>
      sellerAction((r) => r.cancelOrder(orderId));

  // --------------------------------------------------------------- support

  List<SupportTicket> tickets = const [];
  bool loadingTickets = false;
  bool sendingTicket = false;
  String? ticketError;

  Future<void> loadTickets() async {
    if (loadingTickets) {
      return;
    }
    loadingTickets = true;
    _notify();
    try {
      tickets = await _services.partner.tickets();
      ticketError = null;
    } on AppFailure catch (e) {
      ticketError = e.message;
    } finally {
      loadingTickets = false;
      _notify();
    }
  }

  Future<bool> sendTicket(SupportTopic topic, String message) async {
    if (sendingTicket) {
      return false;
    }
    final problem = validateSupportMessage(message);
    if (problem != null) {
      ticketError = problem;
      _notify();
      return false;
    }
    sendingTicket = true;
    ticketError = null;
    _notify();
    try {
      await _services.partner.createTicket(topic, message);
      tickets = await _services.partner.tickets();
      return true;
    } on AppFailure catch (e) {
      ticketError = e.message;
      return false;
    } finally {
      sendingTicket = false;
      _notify();
    }
  }

  // ----------------------------------------------------------------- misc

  void _onSession() {
    if (_disposed) {
      return;
    }
    if (_session.status == SessionStatus.signedOut) {
      reset();
    }
  }

  void reset() {
    inPartnerMode = false;
    application = null;
    applicationLoaded = false;
    applicationError = null;
    chosenType = null;
    saveError = null;
    dashboard = null;
    dashboardError = null;
    earnings = null;
    earningsError = null;
    tickets = const [];
    ticketError = null;
    actionError = null;
    publishError = null;
    sellerError = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_onSession);
    super.dispose();
  }
}
