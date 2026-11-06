import 'package:flutter/foundation.dart';

import '../../booking/domain/models.dart' show PaymentOutcome;
import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../domain/account_logic.dart';
import '../domain/models.dart';

enum TagStage { idle, starting, waiting, checking }

/// Ordering a QR tag: pick a pet and colour, give a delivery address, pay on Paystack, then check the money arrived.
/// The price is read from the server; nothing is charged until Paystack confirms.
class TagOrderController extends ChangeNotifier {
  TagOrderController(this._services);

  final AppServices _services;
  var _disposed = false;

  TagPrices? prices;
  String? loadError;
  var loading = false;

  List<TagOrder> orders = const [];

  String? petId;
  var colour = TagColour.teal;
  String address = '';
  String area = '';

  /// Shown under a field after a failed Pay tap.
  String? addressError;
  String? areaError;

  var stage = TagStage.idle;
  String? payError;
  String? payNotice;

  /// The order that is waiting to be paid. Kept so a second tap on Pay does not make a second order.
  TagIntent? intent;

  /// Set once the payment is confirmed.
  TagOrder? paid;

  bool get busy => stage != TagStage.idle;

  Future<void> load() async {
    if (loading) {
      return;
    }
    loading = true;
    loadError = null;
    _notify();
    try {
      prices = await _services.account.tagPrices();
      orders = await _services.account.myTagOrders();
    } on AppFailure catch (e) {
      loadError = e.message;
    } finally {
      loading = false;
      _notify();
    }
  }

  void choosePet(String? id) {
    if (id != petId) {
      petId = id;
      intent = null;
      _notify();
    }
  }

  void chooseColour(TagColour c) {
    if (c != colour) {
      colour = c;
      intent = null;
      _notify();
    }
  }

  void setAddress(String v) {
    if (v != address) {
      address = v;
      intent = null;
    }
    if (addressError != null) {
      addressError = null;
      _notify();
    }
  }

  void setArea(String v) {
    if (v != area) {
      area = v;
      intent = null;
    }
    if (areaError != null) {
      areaError = null;
      _notify();
    }
  }

  bool get canPay => prices != null && petId != null && !busy && paid == null;

  /// Places the order (once), then opens Paystack.
  Future<void> pay() async {
    final pet = petId;
    if (pet == null || prices == null || busy) {
      return;
    }
    addressError = validateTagAddress(address);
    areaError = validateTagArea(area);
    payError = null;
    payNotice = null;
    if (addressError != null || areaError != null) {
      _notify();
      return;
    }
    stage = TagStage.starting;
    _notify();
    try {
      intent ??= await _services.account.createTagOrder(
        petId: pet,
        colour: colour,
        address: address,
        area: area,
      );
      final checkout = await _services.payments.start(intent!.reference);
      final opened = await _services.links.open(checkout.url);
      if (opened) {
        stage = TagStage.waiting;
      } else {
        payError = 'We could not open the payment page. Please try again.';
        stage = TagStage.idle;
      }
    } on AppFailure catch (e) {
      payError = e.message;
      stage = TagStage.idle;
    }
    _notify();
  }

  /// Called when the person comes back from the Paystack page.
  Future<void> checkPayment() async {
    final made = intent;
    if (made == null || stage == TagStage.checking || stage == TagStage.idle) {
      return;
    }
    stage = TagStage.checking;
    payError = null;
    payNotice = null;
    _notify();
    try {
      final outcome = await _services.payments.verify(made.reference);
      switch (outcome) {
        case PaymentOutcome.paid:
          orders = await _services.account.myTagOrders();
          paid = orders.where((o) => o.reference == made.reference).firstOrNull;
          stage = TagStage.idle;
          intent = null;
        case PaymentOutcome.pending:
          stage = TagStage.waiting;
          payNotice =
              'We have not received your payment yet. If you have paid, wait a moment and check again.';
        case PaymentOutcome.failed:
          stage = TagStage.idle;
          intent = null;
          payError =
              'The payment did not go through. You have not been charged.';
      }
    } on AppFailure catch (e) {
      stage = TagStage.waiting;
      payError = e.message;
    }
    _notify();
  }

  /// Gives up on a payment that is open on Paystack, so the form can be changed.
  void cancelWaiting() {
    if (stage == TagStage.waiting) {
      stage = TagStage.idle;
      payNotice = null;
      payError = null;
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
