import 'package:flutter/foundation.dart';

import '../../../core/analytics.dart';

import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/session_controller.dart';
import '../domain/booking_logic.dart';
import '../domain/models.dart';

enum PayStage {
  idle,

  /// Making the booking and asking for the payment page.
  starting,

  /// The payment page is open somewhere else; waiting for the person to come back.
  waiting,

  /// Asking whether the money arrived.
  checking,
}

/// Everything the Book tab and Bookings show: the provider list, the one provider being booked, the
/// payment in progress, and the person's bookings. Forgets everything on sign out.
class BookingController extends ChangeNotifier {
  BookingController(this._services, this._session) {
    _session.addListener(_onSession);
  }

  final AppServices _services;
  final SessionController _session;
  var _disposed = false;

  DateTime get now => _services.now();

  // ------------------------------------------------------------------ services list

  ServiceCategory category = ServiceCategory.vet;
  String query = '';
  List<ProviderSummary> providers = const [];
  bool loadingProviders = false;
  bool providersLoaded = false;
  String? providersError;
  ({double lat, double lng})? where;
  var _searchSeq = 0;

  Future<void> loadProviders() async {
    final seq = ++_searchSeq;
    loadingProviders = true;
    providersError = null;
    _notify();
    try {
      where ??= await _services.location.current();
      final result = await _services.bookings.search(
        category: category,
        query: query,
        lat: where?.lat,
        lng: where?.lng,
      );
      if (seq != _searchSeq) return;
      providers = result;
      providersLoaded = true;
    } on AppFailure catch (e) {
      if (seq != _searchSeq) return;
      providersError = e.message;
    } finally {
      if (seq == _searchSeq) {
        loadingProviders = false;
        _notify();
      }
    }
  }

  Future<void> setCategory(ServiceCategory c) {
    category = c;
    return loadProviders();
  }

  Future<void> search(String q) {
    query = q;
    return loadProviders();
  }

  // ------------------------------------------------------------------ one provider

  ProviderDetail? detail;
  List<Slot> slots = const [];
  List<ReviewItem> reviews = const [];
  bool loadingDetail = false;
  String? detailError;

  String? serviceId;
  Slot? slot;
  String? petId;

  /// The unpaid booking and its Paystack reference, while a payment is under way.
  BookingIntent? intent;
  PayStage stage = PayStage.idle;
  String? payError;
  String? payNotice;

  /// Set when a payment is confirmed; the Booked screen reads it.
  BookingIntent? booked;

  Future<void> openProvider(String id) async {
    detail = null;
    slots = const [];
    reviews = const [];
    serviceId = null;
    slot = null;
    intent = null;
    booked = null;
    stage = PayStage.idle;
    payError = null;
    payNotice = null;
    detailError = null;
    loadingDetail = true;
    _notify();
    try {
      final results = await Future.wait([
        _services.bookings.provider(id, lat: where?.lat, lng: where?.lng),
        _services.bookings.slots(id),
        _services.bookings.reviews(id),
      ]);
      detail = results[0] as ProviderDetail;
      slots = results[1] as List<Slot>;
      reviews = results[2] as List<ReviewItem>;
      if (detail!.services.length == 1) serviceId = detail!.services.first.id;
    } on AppFailure catch (e) {
      detailError = e.message;
    } finally {
      loadingDetail = false;
      _notify();
    }
  }

  ServiceItem? get service {
    final d = detail;
    if (d == null || serviceId == null) return null;
    for (final s in d.services) {
      if (s.id == serviceId) return s;
    }
    return null;
  }

  void chooseService(String id) {
    serviceId = id;
    payError = null;
    _notify();
  }

  void chooseSlot(Slot s) {
    if (!s.isFree) return;
    slot = s;
    payError = null;
    _notify();
  }

  void choosePet(String? id) {
    petId = id;
    _notify();
  }

  bool get canPay =>
      service != null &&
      slot != null &&
      petId != null &&
      stage == PayStage.idle;

  bool get paying => stage != PayStage.idle;

  /// Makes the booking, then opens Paystack. The money is only counted once [checkPayment] (or the
  /// server, through Paystack's webhook) confirms it.
  Future<void> pay() async {
    final s = service, sl = slot, pet = petId;
    if (s == null || sl == null || pet == null || paying) return;
    payError = null;
    payNotice = null;
    stage = PayStage.starting;
    _notify();
    BookingIntent made;
    try {
      _services.analytics.track(AppEvent.bookingStarted);
      made = await _services.bookings.createBooking(
        serviceId: s.id,
        petId: pet,
        startsAt: sl.startsAt,
      );
    } on AppFailure catch (e) {
      // Most often "that time was just taken": show what is free now.
      payError = e.message;
      stage = PayStage.idle;
      if (detail != null) {
        _refreshSlots(detail!.id);
      }
      _notify();
      return;
    }
    intent = made;
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
      // The booking is held for this person, so the time stays chosen and Pay can be tapped again.
      payError = e.message;
      stage = PayStage.idle;
    }
    _notify();
  }

  Future<void> _refreshSlots(String id) async {
    try {
      slots = await _services.bookings.slots(id);
      if (slot != null &&
          !slots.any((x) => x.startsAt == slot!.startsAt && x.isFree)) {
        slot = null;
      }
      _notify();
    } on AppFailure {
      // The list stays as it was.
    }
  }

  /// Asks whether the payment arrived. Called when the person comes back from Paystack.
  Future<void> checkPayment() async {
    final made = intent;
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
          booked = made;
          stage = PayStage.idle;
          intent = null;
          await loadBookings();
        case PaymentOutcome.pending:
          stage = PayStage.waiting;
          payNotice = 'We have not received your payment yet. If you have paid, wait a moment and check again.';
        case PaymentOutcome.failed:
          stage = PayStage.idle;
          intent = null;
          payError =
              'The payment did not go through. You have not been charged.';
      }
    } on AppFailure catch (e) {
      stage = PayStage.waiting;
      payError = e.message;
    }
    _notify();
  }

  /// Gives up on the payment in progress. The held time is released.
  Future<void> abandonPayment() async {
    final made = intent;
    stage = PayStage.idle;
    intent = null;
    payNotice = null;
    _notify();
    if (made != null) {
      try {
        await _services.bookings.cancel(made.bookingId);
      } on AppFailure {
        // The hold expires on its own after a few minutes.
      }
      if (detail != null) _refreshSlots(detail!.id);
    }
  }

  // ------------------------------------------------------------------ my bookings

  List<Booking> bookings = const [];
  bool loadingBookings = false;
  bool bookingsLoaded = false;
  String? bookingsError;

  /// The booking an action is running on, so its buttons can show progress.
  String? busyId;
  String? actionError;

  Future<void> loadBookings() async {
    loadingBookings = true;
    bookingsError = null;
    _notify();
    try {
      bookings = await _services.bookings.myBookings();
      bookingsLoaded = true;
    } on AppFailure catch (e) {
      bookingsError = e.message;
    } finally {
      loadingBookings = false;
      _notify();
    }
  }

  List<Booking> inGroup(BookingGroup g) => [
    for (final b in bookings)
      if (groupOf(b, now) == g) b,
  ];

  /// Upcoming first (soonest), past newest first.
  List<Booking> get needsAction => inGroup(BookingGroup.needsAction);
  List<Booking> get upcoming =>
      inGroup(BookingGroup.upcoming)
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  List<Booking> get past => inGroup(BookingGroup.past);

  Booking? bookingById(String id) {
    for (final b in bookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<bool> _act(String id, Future<void> Function() run) async {
    if (busyId != null) return false;
    busyId = id;
    actionError = null;
    _notify();
    try {
      await run();
      busyId = null;
      await loadBookings();
      return true;
    } on AppFailure catch (e) {
      actionError = e.message;
      busyId = null;
      _notify();
      return false;
    }
  }

  Future<bool> cancel(String id, {String? reason}) =>
      _act(id, () => _services.bookings.cancel(id, reason: reason));

  Future<bool> confirmVisit(
    String id, {
    int? rating,
    List<String> tags = const [],
    String? body,
  }) => _act(
    id,
    () => _services.bookings.confirmVisit(
      id,
      rating: rating,
      tags: tags,
      body: body,
    ),
  );

  Future<bool> report(
    String id, {
    required DisputeReason reason,
    String? details,
    List<PickedPhoto> evidence = const [],
  }) => _act(id, () async {
    await _services.bookings.openDispute(
      bookingId: id,
      reason: reason,
      details: details,
      evidence: evidence,
    );
  });

  void clearActionError() {
    actionError = null;
    _notify();
  }

  // ------------------------------------------------------------------ lifecycle

  void _onSession() {
    if (_disposed) return;
    if (_session.status == SessionStatus.signedOut) reset();
  }

  void reset() {
    _searchSeq++;
    category = ServiceCategory.vet;
    query = '';
    providers = const [];
    providersLoaded = false;
    where = null;
    detail = null;
    slots = const [];
    reviews = const [];
    serviceId = null;
    slot = null;
    petId = null;
    intent = null;
    booked = null;
    stage = PayStage.idle;
    bookings = const [];
    bookingsLoaded = false;
    busyId = null;
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
