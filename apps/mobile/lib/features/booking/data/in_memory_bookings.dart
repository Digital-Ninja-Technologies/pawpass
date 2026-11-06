import '../../onboarding/domain/models.dart';
import '../domain/booking_logic.dart';
import '../domain/models.dart';
import 'booking_repositories.dart';

class _Provider {
  _Provider({required this.summary, required this.services});
  final ProviderSummary summary;
  final List<ServiceItem> services;
  final List<int> slotHours = const [9, 10, 14, 16, 18];
}

class _Row {
  _Row({
    required this.id,
    required this.reference,
    required this.provider,
    required this.service,
    required this.petId,
    required this.petName,
    required this.startsAt,
    required this.createdAt,
  });

  final String id;
  final String reference;
  final _Provider provider;
  final ServiceItem service;
  final String petId;
  final String petName;
  DateTime startsAt;
  final DateTime createdAt;
  BookingStatus status = BookingStatus.pendingPayment;
  EscrowStatus? escrow;
  int? rating;
  DateTime? partnerDoneAt;
  String? disputeStatus;
  DateTime? disputeDueAt;
}

/// Stand in for the database: the same rules (slot capacity, free cancellation, escrow moves), so tests and
/// the demo build behave like the real thing.
class InMemoryBookingsRepository implements BookingsRepository {
  InMemoryBookingsRepository({
    DateTime Function()? now,
    this.freeCancelHours = 2,
  }) : _now = now ?? DateTime.now {
    _providers = _seed();
  }

  final DateTime Function() _now;
  final int freeCancelHours;
  late final List<_Provider> _providers;
  final _rows = <_Row>[];
  final _reviews = <String, List<ReviewItem>>{};
  var _seq = 0;

  /// Set to make the next call of that name fail.
  AppFailure? failNextCreate;
  AppFailure? failNextConfirm;
  AppFailure? failNextCancel;
  AppFailure? failNextDispute;
  AppFailure? failNextLoad;

  /// What was sent to [openDispute], for tests.
  final disputes =
      <
        ({String bookingId, DisputeReason reason, String? details, int photos})
      >[];

  DateTime get _utcNow => _now().toUtc();

  /// A Wednesday at this hour in Lagos, `days` after today, as a UTC instant.
  DateTime at(int days, int hour, [int minute = 0]) {
    final l = lagosDay(_utcNow)
        .add(Duration(days: days, hours: hour, minutes: minute));
    return l.subtract(const Duration(hours: 1));
  }

  List<_Provider> _seed() {
    ServiceItem s(
      String id,
      String name,
      int naira,
      int min,
      ServiceCategory c,
    ) => ServiceItem(
      id: id,
      name: name,
      priceKobo: naira * 100,
      durationMin: min,
      category: c,
    );
    return [
      _Provider(
        summary: const ProviderSummary(
          id: 'p1',
          name: 'Paws & Claws Vet Clinic',
          area: 'Lekki Phase 1',
          address: 'Admiralty Way, Lekki',
          categories: [ServiceCategory.vet],
          ratingAvg: 4.8,
          ratingCount: 126,
          fromPriceKobo: 1000000,
          distanceM: 2100,
          openNow: true,
          closesAt: '20:00:00',
          lat: 6.4474,
          lng: 3.4723,
        ),
        services: [
          s('s1', 'Consultation', 10000, 30, ServiceCategory.vet),
          s('s2', 'Vaccination (rabies)', 15000, 20, ServiceCategory.vet),
          s('s3', 'Full check-up', 25000, 45, ServiceCategory.vet),
        ],
      ),
      _Provider(
        summary: const ProviderSummary(
          id: 'p2',
          name: 'Lekki Animal Hospital',
          area: 'Lekki',
          address: 'Admiralty Way, Lekki',
          categories: [ServiceCategory.vet],
          ratingAvg: 4.7,
          ratingCount: 88,
          fromPriceKobo: 1200000,
          distanceM: 3400,
          openNow: true,
          open24h: true,
          lat: 6.44,
          lng: 3.48,
        ),
        services: [s('s4', 'Consultation', 12000, 30, ServiceCategory.vet)],
      ),
      _Provider(
        summary: const ProviderSummary(
          id: 'p3',
          name: 'Dr. Amina Bello',
          area: 'Ikate',
          categories: [ServiceCategory.vet],
          ratingAvg: 4.9,
          ratingCount: 54,
          fromPriceKobo: 1500000,
          homeVisits: true,
          lat: 6.44,
          lng: 3.46,
        ),
        services: [s('s5', 'Home visit', 15000, 45, ServiceCategory.vet)],
      ),
      _Provider(
        summary: const ProviderSummary(
          id: 'p4',
          name: 'Glam Paws Grooming',
          area: 'Lekki Phase 1',
          address: 'Fola Osibo Street, Lekki',
          categories: [ServiceCategory.grooming],
          ratingAvg: 4.6,
          ratingCount: 41,
          fromPriceKobo: 800000,
          distanceM: 1200,
          openNow: true,
          closesAt: '18:00:00',
          lat: 6.45,
          lng: 3.47,
        ),
        services: [s('s6', 'Full groom', 12000, 90, ServiceCategory.grooming)],
      ),
      _Provider(
        summary: const ProviderSummary(
          id: 'p5',
          name: 'K9 Academy Lagos',
          area: 'Victoria Island',
          categories: [ServiceCategory.training],
          fromPriceKobo: 2000000,
          lat: 6.43,
          lng: 3.42,
        ),
        services: [
          s('s7', 'Obedience session', 20000, 60, ServiceCategory.training),
        ],
      ),
    ];
  }

  _Provider _find(String id) => _providers.firstWhere(
    (p) => p.summary.id == id,
    orElse: () => throw const AppFailure('Provider not found'),
  );

  /// Bookings that occupy a slot right now (unpaid ones count while their 20 minute hold lasts).
  int _taken(String providerId, DateTime at, [String? except]) =>
      _rows.where((r) {
        if (r.provider.summary.id != providerId ||
            r.startsAt != at ||
            r.id == except) {
          return false;
        }
        if (r.status == BookingStatus.pendingPayment) {
          return _utcNow.difference(r.createdAt) < const Duration(minutes: 20);
        }
        return r.status != BookingStatus.cancelled;
      }).length;

  List<Slot> _allSlots(_Provider p, int days) => [
    for (var d = 0; d < days; d++)
      for (final h in p.slotHours)
        if (at(d, h).isAfter(_utcNow))
          Slot(
            startsAt: at(d, h),
            endsAt: at(d, h).add(const Duration(minutes: 30)),
            free: 1 - _taken(p.summary.id, at(d, h)),
          ),
  ];

  @override
  Future<List<ProviderSummary>> search({
    ServiceCategory? category,
    String? query,
    double? lat,
    double? lng,
  }) async {
    final f = failNextLoad;
    if (f != null) {
      failNextLoad = null;
      throw f;
    }
    final q = query?.trim().toLowerCase() ?? '';
    final out = <ProviderSummary>[];
    for (final p in _providers) {
      if (category != null && !p.summary.categories.contains(category)) {
        continue;
      }
      if (q.isNotEmpty &&
          !p.summary.name.toLowerCase().contains(q) &&
          !p.services.any((s) => s.name.toLowerCase().contains(q))) {
        continue;
      }
      final free = _allSlots(p, 14).where((s) => s.isFree);
      final a = p.summary;
      out.add(
        ProviderSummary(
          id: a.id,
          name: a.name,
          area: a.area,
          address: a.address,
          categories: a.categories,
          ratingAvg: a.ratingAvg,
          ratingCount: a.ratingCount,
          fromPriceKobo: a.fromPriceKobo,
          nextSlot: free.isEmpty ? null : free.first.startsAt,
          distanceM: lat == null ? null : a.distanceM,
          openNow: a.openNow,
          open24h: a.open24h,
          closesAt: a.closesAt,
          homeVisits: a.homeVisits,
          lat: a.lat,
          lng: a.lng,
        ),
      );
    }
    if (lat != null) {
      out.sort(
        (x, y) => (x.distanceM ?? 1 << 30).compareTo(y.distanceM ?? 1 << 30),
      );
    }
    return out;
  }

  @override
  Future<ProviderDetail> provider(String id, {double? lat, double? lng}) async {
    final p = _find(id);
    return ProviderDetail(
      summary: p.summary,
      services: p.services,
      verified: true,
      type: 'Licensed vet',
    );
  }

  @override
  Future<List<Slot>> slots(String providerId, {int days = 14}) async =>
      _allSlots(_find(providerId), days);

  @override
  Future<List<ReviewItem>> reviews(String providerId) async =>
      _reviews[providerId] ?? const [];

  @override
  Future<BookingIntent> createBooking({
    required String serviceId,
    required String petId,
    required DateTime startsAt,
  }) async {
    final f = failNextCreate;
    if (f != null) {
      failNextCreate = null;
      throw f;
    }
    final p = _providers.firstWhere(
      (p) => p.services.any((s) => s.id == serviceId),
      orElse: () => throw const AppFailure('That service is not available'),
    );
    final service = p.services.firstWhere((s) => s.id == serviceId);
    final start = startsAt.toUtc();
    if (!start.isAfter(_utcNow)) throw const AppFailure('That time has passed');
    final slot = _allSlots(p, 30).where((s) => s.startsAt == start);
    if (slot.isEmpty) throw const AppFailure('That time is not available');
    var row = _rows
        .where(
          (r) =>
              r.service == service &&
              r.petId == petId &&
              r.startsAt == start &&
              r.status == BookingStatus.pendingPayment &&
              _utcNow.difference(r.createdAt) < const Duration(minutes: 20),
        )
        .firstOrNull;
    if (row == null) {
      if (_taken(p.summary.id, start) >= 1) {
        throw const AppFailure('That time was just taken. Pick another.');
      }
      _seq++;
      row = _Row(
        id: 'b$_seq',
        reference: 'pp_ref$_seq',
        provider: p,
        service: service,
        petId: petId,
        petName: _petNames[petId] ?? 'Your pet',
        startsAt: start,
        createdAt: _utcNow,
      );
      _rows.add(row);
    }
    return BookingIntent(
      bookingId: row.id,
      reference: row.reference,
      amountKobo: service.priceKobo,
      serviceName: service.name,
      partnerName: p.summary.name,
      startsAt: start,
    );
  }

  final _petNames = <String, String>{};

  /// Tests and the demo tell the repository the pet names (the real one reads them from the database).
  void knowPets(Iterable<Pet> pets) {
    for (final p in pets) {
      _petNames[p.id] = p.name;
    }
  }

  /// What the payments webhook does once Paystack confirms the money.
  bool markPaid(String reference) {
    final r = _rows.where((r) => r.reference == reference).firstOrNull;
    if (r == null) return false;
    if (r.escrow != null) return true;
    r.escrow = EscrowStatus.held;
    r.status = BookingStatus.confirmed;
    return true;
  }

  /// Test hook: pretend time passed so the visit has started.
  void startVisit(String bookingId, {bool providerDone = false}) {
    final r = _rows.firstWhere((r) => r.id == bookingId);
    r.startsAt = _utcNow.subtract(const Duration(hours: 1));
    if (providerDone) {
      r.status = BookingStatus.completedAwaitingOwner;
      r.partnerDoneAt = _utcNow;
    }
  }

  @override
  Future<List<Booking>> myBookings() async {
    final f = failNextLoad;
    if (f != null) {
      failNextLoad = null;
      throw f;
    }
    final rows =
        _rows.where((r) => r.status != BookingStatus.pendingPayment).toList()
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return [
      for (final r in rows)
        Booking(
          id: r.id,
          status: r.status,
          startsAt: r.startsAt,
          serviceName: r.service.name,
          amountKobo: r.service.priceKobo,
          partnerId: r.provider.summary.id,
          partnerName: r.provider.summary.name,
          partnerAddress: r.provider.summary.address,
          partnerLat: r.provider.summary.lat,
          partnerLng: r.provider.summary.lng,
          petId: r.petId,
          petName: r.petName,
          escrow: r.escrow,
          rating: r.rating,
          partnerDoneAt: r.partnerDoneAt,
          disputeStatus: r.disputeStatus,
          disputeDueAt: r.disputeDueAt,
          canCancelUntil: r.startsAt.subtract(Duration(hours: freeCancelHours)),
        ),
    ];
  }

  _Row _mine(String id) => _rows.firstWhere(
    (r) => r.id == id,
    orElse: () => throw const AppFailure('That booking could not be found.'),
  );

  @override
  Future<void> cancel(String bookingId, {String? reason}) async {
    final f = failNextCancel;
    if (f != null) {
      failNextCancel = null;
      throw f;
    }
    final r = _mine(bookingId);
    if (r.status == BookingStatus.pendingPayment) {
      r.status = BookingStatus.cancelled;
      return;
    }
    if (r.status != BookingStatus.confirmed) {
      throw const AppFailure('This booking can no longer be cancelled');
    }
    if (r.startsAt.difference(_utcNow) < Duration(hours: freeCancelHours)) {
      throw AppFailure(
        'Free cancellation ended $freeCancelHours hours before the visit. Contact the provider, or report a problem after the visit.',
      );
    }
    r.escrow = EscrowStatus.refunded;
    r.status = BookingStatus.cancelled;
  }

  @override
  Future<void> confirmVisit(
    String bookingId, {
    int? rating,
    List<String> tags = const [],
    String? body,
  }) async {
    final f = failNextConfirm;
    if (f != null) {
      failNextConfirm = null;
      throw f;
    }
    final r = _mine(bookingId);
    if (r.status != BookingStatus.confirmed &&
        r.status != BookingStatus.completedAwaitingOwner) {
      throw const AppFailure('This booking cannot be confirmed');
    }
    if (r.status == BookingStatus.confirmed && r.startsAt.isAfter(_utcNow)) {
      throw const AppFailure('You can confirm once the visit has started');
    }
    if (r.escrow != EscrowStatus.held) {
      throw const AppFailure(
        'The payment for this booking is not waiting for your confirmation',
      );
    }
    r.escrow = EscrowStatus.ready;
    r.status = BookingStatus.completed;
    if (rating != null) {
      r.rating = rating;
      (_reviews[r.provider.summary.id] ??= []).insert(
        0,
        ReviewItem(
          rating: rating,
          tags: tags,
          body: body,
          reviewer: 'Tolu',
          serviceName: r.service.name,
        ),
      );
    }
  }

  @override
  Future<String> openDispute({
    required String bookingId,
    required DisputeReason reason,
    String? details,
    List<PickedPhoto> evidence = const [],
  }) async {
    final f = failNextDispute;
    if (f != null) {
      failNextDispute = null;
      throw f;
    }
    final r = _mine(bookingId);
    final started = r.status == BookingStatus.confirmed
        ? !r.startsAt.isAfter(_utcNow)
        : r.status == BookingStatus.completedAwaitingOwner ||
              r.status == BookingStatus.completed;
    if (!started) {
      throw const AppFailure(
        'A problem can be reported once the visit has started',
      );
    }
    if (r.escrow != EscrowStatus.held && r.escrow != EscrowStatus.ready) {
      throw const AppFailure(
        'This payment has already been paid out or refunded',
      );
    }
    r.escrow = EscrowStatus.paused;
    r.status = BookingStatus.disputed;
    r.disputeStatus = 'open';
    r.disputeDueAt = _utcNow.add(const Duration(hours: 72));
    disputes.add((
      bookingId: bookingId,
      reason: reason,
      details: details,
      photos: evidence.length,
    ));
    return 'd${disputes.length}';
  }
}

/// Pays instantly (or as told), and, like the real webhook, marks the booking paid.
class InMemoryPaymentsRepository implements PaymentsRepository {
  InMemoryPaymentsRepository(this._bookings);
  final InMemoryBookingsRepository _bookings;

  /// What [verify] answers. Defaults to paid.
  PaymentOutcome outcome = PaymentOutcome.paid;
  AppFailure? failNextStart;
  final started = <String>[];

  @override
  Future<PaymentCheckout> start(String reference) async {
    final f = failNextStart;
    if (f != null) {
      failNextStart = null;
      throw f;
    }
    started.add(reference);
    return PaymentCheckout(
      url: Uri.parse('https://checkout.paystack.com/$reference'),
      reference: reference,
    );
  }

  @override
  Future<PaymentOutcome> verify(String reference) async {
    if (outcome == PaymentOutcome.paid) _bookings.markPaid(reference);
    return outcome;
  }
}
