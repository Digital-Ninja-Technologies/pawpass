import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'adopt_repository.dart';

class _Listing {
  _Listing({
    required this.id,
    required this.kind,
    required this.petId,
    required this.petName,
    required this.species,
    required this.partnerId,
    required this.partnerName,
    required this.partnerType,
    required this.partnerArea,
    this.priceKobo,
    this.breed,
    this.sex,
    this.bornOn,
    this.colour,
    this.mother,
    this.father,
    this.records = const [],
    this.handoverBy,
  });

  final String id;
  final ListingKind kind;
  final String petId;
  final String petName;
  final String species;
  final String? breed;
  final String? sex;
  final DateTime? bornOn;
  final String? colour;
  final String partnerId;
  final String partnerName;
  final String partnerType;
  final String partnerArea;
  final int? priceKobo;
  final String? mother;
  final String? father;
  final List<ListingRecord> records;
  final DateTime? handoverBy;
  String status = 'live';
}

class _Order {
  _Order(
    this.id,
    this.listing,
    this.depositRef,
    this.deposit,
    this.fee,
    this.balance,
    this.createdAt,
  );
  final String id;
  final _Listing listing;
  final String depositRef;
  final int deposit;
  final int fee;
  final int balance;
  final DateTime createdAt;
  String? balanceRef;
  OrderStatus status = OrderStatus.pendingDeposit;
  bool depositPaid = false;
  bool balancePaid = false;
  DateTime? handedOverAt;
  DateTime? vetEnds;
  DateTime? acceptedAt;
  String? transferId;
  bool transferDone = false;
  String? disputeStatus;
  DateTime? disputeDue;
}

class _Application {
  _Application(this.id, this.listing, this.createdAt);
  final String id;
  final _Listing listing;
  final DateTime createdAt;
  String status = 'submitted';
  String? transferId;
}

/// Stand in for the server with the same rules (one paid buyer per pet, deposit a third plus 5% of it, a 72 hour
/// window, accepting moves the pet). The signed in person is the buyer.
class InMemoryAdoptRepository implements AdoptRepository {
  InMemoryAdoptRepository({
    DateTime Function()? now,
    this.onPassport,
    this.vetCheckHours = 72,
  }) : _now = now ?? DateTime.now {
    final t = _now().toUtc();
    _listings.addAll([
      _Listing(
        id: 'l-duke',
        kind: ListingKind.sale,
        priceKobo: 45000000,
        petId: 'pet-duke',
        petName: 'Duke',
        species: 'dog',
        breed: 'Boerboel',
        sex: 'male',
        bornOn: t.subtract(const Duration(days: 63)),
        colour: 'fawn',
        partnerId: 'p-royal',
        partnerName: 'Royal Paws Kennels',
        partnerType: 'breeder',
        partnerArea: 'Ikeja',
        mother: 'Bella',
        father: 'Max',
        handoverBy: t.add(const Duration(days: 7)),
        records: [
          ListingRecord(
            type: 'vaccine',
            name: 'DHPP',
            givenOn: t.subtract(const Duration(days: 14)),
            verified: true,
          ),
          ListingRecord(
            type: 'vet_visit',
            name: 'Health check',
            givenOn: t.subtract(const Duration(days: 8)),
            verified: true,
          ),
          ListingRecord(
            type: 'deworming',
            name: 'Deworming (2 doses)',
            givenOn: t.subtract(const Duration(days: 20)),
          ),
        ],
      ),
      _Listing(
        id: 'l-nala',
        kind: ListingKind.sale,
        priceKobo: 38000000,
        petId: 'pet-nala',
        petName: 'Nala',
        species: 'dog',
        breed: 'German Shepherd',
        sex: 'female',
        bornOn: t.subtract(const Duration(days: 70)),
        partnerId: 'p-shepherds',
        partnerName: 'Ikeja Shepherds',
        partnerType: 'breeder',
        partnerArea: 'Ikeja',
      ),
      _Listing(
        id: 'l-ada',
        kind: ListingKind.adoption,
        petId: 'pet-ada',
        petName: 'Ada',
        species: 'dog',
        breed: 'Mixed breed',
        sex: 'female',
        bornOn: t.subtract(const Duration(days: 400)),
        colour: 'tan and white',
        partnerId: 'p-rescue',
        partnerName: 'Lagos Paws Rescue',
        partnerType: 'shelter',
        partnerArea: 'Surulere',
        records: [
          ListingRecord(
            type: 'vaccine',
            name: 'Core vaccines',
            givenOn: t.subtract(const Duration(days: 60)),
            verified: true,
          ),
        ],
      ),
      _Listing(
        id: 'l-mia',
        kind: ListingKind.adoption,
        petId: 'pet-mia',
        petName: 'Mia',
        species: 'cat',
        breed: 'Domestic shorthair',
        sex: 'female',
        bornOn: t.subtract(const Duration(days: 200)),
        partnerId: 'p-rescue',
        partnerName: 'Lagos Paws Rescue',
        partnerType: 'shelter',
        partnerArea: 'Surulere',
      ),
    ]);
  }

  final DateTime Function() _now;

  /// Called when the person accepts a passport, so the pet appears in their list.
  final void Function(String name, String species, String? breed)? onPassport;
  final int vetCheckHours;

  final _listings = <_Listing>[];
  final _orders = <_Order>[];
  final _apps = <_Application>[];
  var _seq = 0;

  /// Set to make the next call of that name fail.
  AppFailure? failNextLoad;
  AppFailure? failNextOrder;
  AppFailure? failNextApply;
  AppFailure? failNextAccept;

  final problems = <({String orderId, OrderProblem reason, String? details})>[];

  DateTime get _t => _now().toUtc();

  T _fail<T>(AppFailure? f, void Function() clear) {
    clear();
    throw f!;
  }

  _Listing _listing(String id) => _listings.firstWhere(
    (l) => l.id == id,
    orElse: () => throw const AppFailure(
      'We could not find that. It may have been removed.',
    ),
  );

  _Order _order(String id) => _orders.firstWhere(
    (o) => o.id == id,
    orElse: () => throw const AppFailure(
      'We could not find that. It may have been removed.',
    ),
  );

  bool _taken(_Listing l) => _orders.any(
    (o) =>
        o.listing == l &&
        {
          OrderStatus.depositPaid,
          OrderStatus.balancePaid,
          OrderStatus.handedOver,
          OrderStatus.completed,
          OrderStatus.disputed,
        }.contains(o.status),
  );

  @override
  Future<List<AdoptListing>> listings({
    ListingKind? kind,
    String? species,
    String? query,
  }) async {
    if (failNextLoad != null) {
      return _fail(failNextLoad, () => failNextLoad = null);
    }
    final q = (query ?? '').trim().toLowerCase();
    return [
      for (final l in _listings)
        if ((l.status == 'live' || l.status == 'reserved') &&
            (kind == null || l.kind == kind) &&
            (species == null || l.species == species) &&
            (q.isEmpty ||
                l.petName.toLowerCase().contains(q) ||
                (l.breed ?? '').toLowerCase().contains(q) ||
                l.partnerName.toLowerCase().contains(q)))
          _row(l),
    ];
  }

  AdoptListing _row(_Listing l) => AdoptListing(
    id: l.id,
    kind: l.kind,
    priceKobo: l.priceKobo,
    petId: l.petId,
    petName: l.petName,
    species: l.species,
    breed: l.breed,
    sex: l.sex,
    bornOn: l.bornOn,
    partnerId: l.partnerId,
    partnerName: l.partnerName,
    partnerType: l.partnerType,
    partnerArea: l.partnerArea,
    reserved: l.status == 'reserved',
  );

  ({int deposit, int fee, int balance}) _amounts(int price) {
    final deposit = (price / 3).ceil();
    return (
      deposit: deposit,
      fee: (deposit * 0.05).round(),
      balance: price - deposit,
    );
  }

  @override
  Future<ListingDetail> listing(String listingId) async {
    if (failNextLoad != null) {
      return _fail(failNextLoad, () => failNextLoad = null);
    }
    final l = _listing(listingId);
    final sale = l.kind == ListingKind.sale && l.priceKobo != null;
    final a = sale ? _amounts(l.priceKobo!) : null;
    final order = _orders
        .where((o) => o.listing == l && o.status != OrderStatus.cancelled)
        .lastOrNull;
    final app = _apps.where((x) => x.listing == l).lastOrNull;
    return ListingDetail(
      listing: _row(l),
      status: l.status,
      depositKobo: a?.deposit,
      protectionFeeKobo: a?.fee,
      dueTodayKobo: a == null ? null : a.deposit + a.fee,
      balanceKobo: a?.balance,
      handoverBy: l.handoverBy,
      colour: l.colour,
      motherName: l.mother,
      fatherName: l.father,
      partnerVerified: true,
      records: l.records,
      myOrderId: order?.id,
      myOrderStatus: order?.status.value,
      myApplicationId: app?.id,
      myApplicationStatus: app?.status,
      myTransferId: app?.transferId,
    );
  }

  @override
  Future<OrderPayment> createOrder(String listingId) async {
    if (failNextOrder != null) {
      return _fail(failNextOrder, () => failNextOrder = null);
    }
    final l = _listing(listingId);
    if (l.kind != ListingKind.sale) {
      throw const AppFailure('This pet is not for sale');
    }
    if (l.status != 'live') {
      throw const AppFailure('This pet is no longer available');
    }
    var o = _orders
        .where((o) => o.listing == l && o.status == OrderStatus.pendingDeposit)
        .lastOrNull;
    if (o == null) {
      final a = _amounts(l.priceKobo!);
      o = _Order(
        'o${++_seq}',
        l,
        'pd_ref$_seq',
        a.deposit,
        a.fee,
        a.balance,
        _t,
      );
      _orders.add(o);
    }
    return OrderPayment(
      orderId: o.id,
      reference: o.depositRef,
      amountKobo: o.deposit + o.fee,
      petName: l.petName,
      partnerName: l.partnerName,
    );
  }

  @override
  Future<void> cancelUnpaidOrder(String orderId) async {
    final o = _order(orderId);
    if (o.status != OrderStatus.pendingDeposit) {
      throw const AppFailure('This order cannot be cancelled');
    }
    o.status = OrderStatus.cancelled;
  }

  @override
  Future<OrderPayment> balancePayment(String orderId) async {
    final o = _order(orderId);
    if (o.status != OrderStatus.depositPaid) {
      throw const AppFailure(
        'The balance can be paid once the deposit is in and before handover',
      );
    }
    o.balanceRef ??= 'pb_ref${++_seq}';
    return OrderPayment(
      orderId: o.id,
      reference: o.balanceRef!,
      amountKobo: o.balance,
      petName: o.listing.petName,
    );
  }

  /// What the payments webhook does once Paystack confirms the money. Returns false if the reference is not ours.
  bool markPaid(String reference) {
    for (final o in _orders) {
      if (o.depositRef == reference) {
        if (o.depositPaid) {
          return true;
        }
        if (o.status != OrderStatus.pendingDeposit ||
            o.listing.status != 'live' ||
            _taken(o.listing)) {
          o.status = OrderStatus.cancelled;
          return true;
        }
        o.depositPaid = true;
        o.status = OrderStatus.depositPaid;
        o.listing.status = 'reserved';
        return true;
      }
      if (o.balanceRef == reference) {
        if (!o.balancePaid && o.status == OrderStatus.depositPaid) {
          o.balancePaid = true;
          o.status = OrderStatus.balancePaid;
        }
        return true;
      }
    }
    return false;
  }

  /// Test and demo hook: the seller confirms the handover (needs the balance paid).
  void sellerConfirmHandover(String orderId) {
    final o = _order(orderId);
    if (o.status != OrderStatus.balancePaid) {
      throw const AppFailure(
        'Handover can be confirmed once the buyer has paid the balance',
      );
    }
    o.status = OrderStatus.handedOver;
    o.handedOverAt = _t;
    o.vetEnds = _t.add(Duration(hours: vetCheckHours));
    o.listing.status = 'sold';
    o.transferId = 't${++_seq}';
  }

  /// Test and demo hook: the vet check window passes with no problem.
  void endVetWindow(String orderId) {
    final o = _order(orderId);
    if (o.status == OrderStatus.handedOver) {
      o.status = OrderStatus.completed;
      _complete(o);
    }
  }

  /// Test and demo hook: the seller cancels before handover. Everything paid is refunded.
  void sellerCancel(String orderId) {
    final o = _order(orderId);
    if (o.status == OrderStatus.depositPaid ||
        o.status == OrderStatus.balancePaid) {
      o.status = OrderStatus.cancelled;
      o.listing.status = 'live';
    }
  }

  /// Test and demo hook: the shelter approves, then hands the pet over.
  void shelterHandOver(String applicationId) {
    final a = _apps.firstWhere((x) => x.id == applicationId);
    a.status = 'approved';
    a.transferId = 't${++_seq}';
    a.listing.status = 'adopted';
  }

  void _complete(_Order o) {
    if (o.transferDone) {
      return;
    }
    o.transferDone = true;
    o.acceptedAt = _t;
    onPassport?.call(o.listing.petName, o.listing.species, o.listing.breed);
  }

  @override
  Future<List<OrderSummary>> orders() async => [
    for (final o in _orders.reversed)
      if (o.status != OrderStatus.pendingDeposit)
        OrderSummary(
          id: o.id,
          status: o.status,
          petName: o.listing.petName,
          partnerName: o.listing.partnerName,
          priceKobo: o.listing.priceKobo!,
          createdAt: o.createdAt,
          isBuyer: true,
        ),
  ];

  @override
  Future<OrderDetail> order(String orderId) async {
    if (failNextLoad != null) {
      return _fail(failNextLoad, () => failNextLoad = null);
    }
    final o = _order(orderId);
    final l = o.listing;
    return OrderDetail(
      id: o.id,
      status: o.status,
      listingId: l.id,
      petId: l.petId,
      petName: l.petName,
      species: l.species,
      breed: l.breed,
      partnerName: l.partnerName,
      buyerName: 'Tolu',
      priceKobo: l.priceKobo!,
      depositKobo: o.deposit,
      protectionFeeKobo: o.fee,
      balanceKobo: o.balance,
      isBuyer: true,
      depositPaid: o.depositPaid,
      balancePaid: o.balancePaid,
      handoverBy: l.handoverBy,
      handedOverAt: o.handedOverAt,
      vetCheckEndsAt: o.vetEnds,
      acceptedAt: o.acceptedAt,
      transferId: o.transferId,
      transferCompleted: o.transferDone,
      disputeStatus: o.disputeStatus,
      disputeDueAt: o.disputeDue,
    );
  }

  @override
  Future<void> acceptPassport(String transferId) async {
    if (failNextAccept != null) {
      return _fail(failNextAccept, () => failNextAccept = null);
    }
    final o = _orders.where((o) => o.transferId == transferId).firstOrNull;
    if (o != null) {
      if (o.transferDone) {
        throw const AppFailure('This passport has already been accepted');
      }
      if (o.status == OrderStatus.disputed) {
        throw const AppFailure('A problem report is open for this order');
      }
      _complete(o);
      return;
    }
    final a = _apps.where((x) => x.transferId == transferId).firstOrNull;
    if (a == null) {
      throw const AppFailure(
        'We could not find that. It may have been removed.',
      );
    }
    if (a.transferId == 'done:$transferId') {
      throw const AppFailure('This passport has already been accepted');
    }
    a.transferId = null;
    _doneTransfers.add(transferId);
    onPassport?.call(a.listing.petName, a.listing.species, a.listing.breed);
  }

  final _doneTransfers = <String>{};

  @override
  Future<void> reportProblem(
    String orderId,
    OrderProblem reason, {
    String? details,
  }) async {
    final o = _order(orderId);
    if (o.status != OrderStatus.handedOver) {
      throw const AppFailure(
        'A problem can be reported after the handover, during the vet check window',
      );
    }
    if (_t.isAfter(o.vetEnds!)) {
      throw const AppFailure('The vet check window has ended');
    }
    o.status = OrderStatus.disputed;
    o.disputeStatus = 'open';
    o.disputeDue = _t.add(const Duration(hours: 72));
    problems.add((orderId: orderId, reason: reason, details: details));
  }

  final chats = <String>[];

  @override
  Future<String> openListingChat(String listingId) async {
    _listing(listingId);
    chats.add(listingId);
    return 'conv-$listingId';
  }

  @override
  Future<String> apply(String listingId, AdoptionAnswers a) async {
    if (failNextApply != null) {
      return _fail(failNextApply, () => failNextApply = null);
    }
    final l = _listing(listingId);
    if (l.kind != ListingKind.adoption || l.status != 'live') {
      throw const AppFailure('This pet is no longer open for adoption');
    }
    if (a.why.trim().length < 10) {
      throw const AppFailure(
        'Tell the shelter a little about why you want to adopt (at least 10 characters)',
      );
    }
    if (!a.agreeVisit) {
      throw const AppFailure(
        'The shelter needs your agreement to a short home visit or video call',
      );
    }
    if (_apps.any((x) => x.listing == l)) {
      throw const AppFailure('You have already applied for this pet');
    }
    final app = _Application('a${++_seq}', l, _t);
    _apps.add(app);
    return app.id;
  }

  @override
  Future<List<ApplicationSummary>> applications() async => [
    for (final a in _apps.reversed)
      ApplicationSummary(
        id: a.id,
        listingId: a.listing.id,
        status: a.status,
        petName: a.listing.petName,
        partnerName: a.listing.partnerName,
        createdAt: a.createdAt,
        transferId: a.transferId,
      ),
  ];

  @override
  Future<TransferDetail> transfer(String transferId) async {
    final o = _orders.where((o) => o.transferId == transferId).firstOrNull;
    if (o != null) {
      return TransferDetail(
        id: transferId,
        kind: ListingKind.sale,
        petId: o.listing.petId,
        petName: o.listing.petName,
        species: o.listing.species,
        breed: o.listing.breed,
        partnerName: o.listing.partnerName,
        isReceiver: true,
        handoverConfirmedAt: o.handedOverAt,
        completedAt: o.transferDone ? o.acceptedAt : null,
        records: o.listing.records.length,
        verifiedRecords: o.listing.records.where((r) => r.verified).length,
        orderId: o.id,
      );
    }
    final a = _apps.where((x) => x.transferId == transferId).firstOrNull;
    final l =
        a?.listing ??
        _listings.firstWhere(
          (l) =>
              _doneTransfers.contains(transferId) &&
              l.kind == ListingKind.adoption,
        );
    return TransferDetail(
      id: transferId,
      kind: ListingKind.adoption,
      petId: l.petId,
      petName: l.petName,
      species: l.species,
      breed: l.breed,
      partnerName: l.partnerName,
      isReceiver: true,
      handoverConfirmedAt: _t,
      completedAt: _doneTransfers.contains(transferId) ? _t : null,
      records: l.records.length,
      verifiedRecords: l.records.where((r) => r.verified).length,
    );
  }

  @override
  Future<String?> photoUrl(String path) async => null;
}
