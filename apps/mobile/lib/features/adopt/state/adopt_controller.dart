import 'package:flutter/foundation.dart';

import '../../booking/domain/models.dart' show PaymentOutcome;
import '../../booking/state/booking_controller.dart' show PayStage;
import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/session_controller.dart';
import '../domain/models.dart';

/// Browsing pets, the listing, paying the deposit and balance, the order, the passport, and applications.
/// Forgets everything on sign out.
class AdoptController extends ChangeNotifier {
  AdoptController(this._services, this._session) {
    _session.addListener(_onSession);
  }

  final AppServices _services;
  final SessionController _session;
  var _disposed = false;
  var _seq = 0;

  DateTime get now => _services.now();

  // ------------------------------------------------------------------ browse

  ListingKind kind = ListingKind.sale;
  String? species;
  String query = '';
  List<AdoptListing> listings = const [];
  bool loading = false;
  bool loaded = false;
  String? error;

  List<OrderSummary> orders = const [];
  List<ApplicationSummary> applications = const [];

  Future<void> load() async {
    final seq = ++_seq;
    loading = true;
    error = null;
    _notify();
    try {
      final results = await Future.wait([
        _services.adopt.listings(kind: kind, species: species, query: query),
        _services.adopt.orders(),
        _services.adopt.applications(),
      ]);
      if (seq != _seq) {
        return;
      }
      listings = results[0] as List<AdoptListing>;
      orders = results[1] as List<OrderSummary>;
      applications = results[2] as List<ApplicationSummary>;
      loaded = true;
    } on AppFailure catch (e) {
      if (seq != _seq) {
        return;
      }
      error = e.message;
    } finally {
      if (seq == _seq) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> setKind(ListingKind k) {
    kind = k;
    return load();
  }

  Future<void> setSpecies(String? s) {
    species = s;
    return load();
  }

  Future<void> search(String q) {
    query = q;
    return load();
  }

  /// Orders and applications that still need the person's attention, for the top of the list.
  List<OrderSummary> get activeOrders => [
    for (final o in orders)
      if (o.isBuyer &&
          o.status != OrderStatus.cancelled &&
          o.status != OrderStatus.completed)
        o,
  ];

  List<ApplicationSummary> get activeApplications => [
    for (final a in applications)
      if (a.status != 'declined' &&
          !(a.status == 'approved' && a.transferId == null))
        a,
  ];

  // ------------------------------------------------------------------ photos

  final Map<String, String?> _urls = {};

  String? urlFor(String? path) {
    if (path == null) {
      return null;
    }
    if (_urls.containsKey(path)) {
      return _urls[path];
    }
    _urls[path] = null;
    _services.adopt.photoUrl(path).then((u) {
      if (u != null) {
        _urls[path] = u;
        _notify();
      }
    });
    return null;
  }

  // ------------------------------------------------------------------ one listing

  ListingDetail? detail;
  bool loadingDetail = false;
  String? detailError;
  String? actionError;

  Future<void> openListing(String id) async {
    detail = null;
    detailError = null;
    actionError = null;
    payError = null;
    payNotice = null;
    stage = PayStage.idle;
    payment = null;
    paidOrderId = null;
    loadingDetail = true;
    _notify();
    try {
      detail = await _services.adopt.listing(id);
    } on AppFailure catch (e) {
      detailError = e.message;
    } finally {
      loadingDetail = false;
      _notify();
    }
  }

  /// Opens (or reuses) the chat with the seller. Returns the conversation id.
  Future<String?> openChat(String listingId) async {
    actionError = null;
    try {
      return await _services.adopt.openListingChat(listingId);
    } on AppFailure catch (e) {
      actionError = e.message;
      _notify();
      return null;
    }
  }

  /// Re-reads the open listing without blanking the screen (its buttons change once an order exists).
  Future<void> _refreshDetail() async {
    final id = detail?.listing.id;
    if (id == null) {
      return;
    }
    try {
      detail = await _services.adopt.listing(id);
    } on AppFailure {
      // The old copy stays until the next visit.
    }
  }

  // ------------------------------------------------------------------ paying (deposit and balance)

  PayStage stage = PayStage.idle;
  OrderPayment? payment;
  bool payingBalance = false;
  String? payError;
  String? payNotice;

  /// Set when a payment is confirmed; the screen then goes to the order.
  String? paidOrderId;

  bool get paying => stage != PayStage.idle;

  Future<void> payDeposit(String listingId) =>
      _start(() => _services.adopt.createOrder(listingId), balance: false);

  Future<void> payBalance(String orderId) =>
      _start(() => _services.adopt.balancePayment(orderId), balance: true);

  Future<void> _start(
    Future<OrderPayment> Function() make, {
    required bool balance,
  }) async {
    if (paying) {
      return;
    }
    payError = null;
    payNotice = null;
    paidOrderId = null;
    stage = PayStage.starting;
    _notify();
    OrderPayment made;
    try {
      made = await make();
    } on AppFailure catch (e) {
      payError = e.message;
      stage = PayStage.idle;
      _notify();
      return;
    }
    payment = made;
    payingBalance = balance;
    try {
      final checkout = await _services.payments.start(made.reference);
      final opened = await _services.links.open(checkout.url);
      if (!opened) {
        payError = 'We could not open the payment page. Please try again.';
        stage = PayStage.idle;
      } else {
        stage = PayStage.waiting;
      }
    } on AppFailure catch (e) {
      payError = e.message;
      stage = PayStage.idle;
    }
    _notify();
  }

  /// Asks whether the money arrived (the person has come back from Paystack).
  Future<void> checkPayment() async {
    final made = payment;
    if (made == null || stage == PayStage.checking || stage == PayStage.idle) {
      return;
    }
    stage = PayStage.checking;
    payError = null;
    payNotice = null;
    _notify();
    try {
      final outcome = await _services.payments.verify(made.reference);
      switch (outcome) {
        case PaymentOutcome.paid:
          paidOrderId = made.orderId;
          stage = PayStage.idle;
          payment = null;
          await Future.wait([load(), _refreshDetail()]);
        case PaymentOutcome.pending:
          stage = PayStage.waiting;
          payNotice = 'We have not received your payment yet. If you have paid, wait a moment and check again.';
        case PaymentOutcome.failed:
          stage = PayStage.idle;
          payment = null;
          payError =
              'The payment did not go through. You have not been charged.';
      }
    } on AppFailure catch (e) {
      stage = PayStage.waiting;
      payError = e.message;
    }
    _notify();
  }

  /// Gives up on a deposit in progress. (A balance stays payable, so only the screen state is cleared.)
  Future<void> abandonPayment() async {
    final made = payment;
    final wasBalance = payingBalance;
    stage = PayStage.idle;
    payment = null;
    payNotice = null;
    _notify();
    if (made != null && !wasBalance) {
      try {
        await _services.adopt.cancelUnpaidOrder(made.orderId);
      } on AppFailure {
        // The hold expires on its own after a few minutes.
      }
    }
  }

  // ------------------------------------------------------------------ one order

  OrderDetail? order;
  bool loadingOrder = false;
  String? orderError;
  bool accepting = false;
  String? acceptError;
  bool reporting = false;
  String? problemError;

  Future<void> openOrder(String id) async {
    order = null;
    orderError = null;
    acceptError = null;
    payError = null;
    payNotice = null;
    paidOrderId = null;
    loadingOrder = true;
    _notify();
    await _refreshOrder(id);
  }

  Future<void> _refreshOrder(String id) async {
    try {
      order = await _services.adopt.order(id);
    } on AppFailure catch (e) {
      orderError = e.message;
    } finally {
      loadingOrder = false;
      _notify();
    }
  }

  Future<void> reloadOrder() async {
    final id = order?.id;
    if (id != null) {
      await _refreshOrder(id);
    }
  }

  /// The buyer takes the passport. Returns true when the pet is now theirs.
  Future<bool> acceptPassport(String transferId) async {
    if (accepting) {
      return false;
    }
    accepting = true;
    acceptError = null;
    _notify();
    try {
      await _services.adopt.acceptPassport(transferId);
      accepting = false;
      await Future.wait([
        load(),
        if (order != null) _refreshOrder(order!.id),
        if (transfer != null) openTransfer(transferId),
      ]);
      return true;
    } on AppFailure catch (e) {
      acceptError = e.message;
      accepting = false;
      _notify();
      return false;
    }
  }

  Future<bool> reportProblem(
    String orderId,
    OrderProblem reason, {
    String? details,
  }) async {
    if (reporting) {
      return false;
    }
    reporting = true;
    problemError = null;
    _notify();
    try {
      await _services.adopt.reportProblem(orderId, reason, details: details);
      reporting = false;
      await _refreshOrder(orderId);
      await load();
      return true;
    } on AppFailure catch (e) {
      problemError = e.message;
      reporting = false;
      _notify();
      return false;
    }
  }

  // ------------------------------------------------------------------ adoption

  bool applying = false;
  String? applyError;

  Future<bool> apply(String listingId, AdoptionAnswers answers) async {
    if (applying) {
      return false;
    }
    applying = true;
    applyError = null;
    _notify();
    try {
      await _services.adopt.apply(listingId, answers);
      applying = false;
      await Future.wait([openListing(listingId), load()]);
      return true;
    } on AppFailure catch (e) {
      applyError = e.message;
      applying = false;
      _notify();
      return false;
    }
  }

  TransferDetail? transfer;
  String? transferError;

  Future<void> openTransfer(String id) async {
    transferError = null;
    try {
      transfer = await _services.adopt.transfer(id);
    } on AppFailure catch (e) {
      transferError = e.message;
    }
    _notify();
  }

  // ------------------------------------------------------------------ lifecycle

  void _onSession() {
    if (_disposed) {
      return;
    }
    if (_session.status == SessionStatus.signedOut) {
      reset();
    }
  }

  void reset() {
    _seq++;
    kind = ListingKind.sale;
    species = null;
    query = '';
    listings = const [];
    orders = const [];
    applications = const [];
    loaded = false;
    detail = null;
    order = null;
    transfer = null;
    payment = null;
    stage = PayStage.idle;
    _urls.clear();
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
