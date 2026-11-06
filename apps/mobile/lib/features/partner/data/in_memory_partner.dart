import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'partner_repository.dart';

/// A pretend partner back end for tests and the debug demo. It follows the database rules: steps from documents,
/// nothing editable after submit, nothing sent until every step is done. Hooks (`review`, `visits`, ...) stand in
/// for the PawPass team and for bookings made by owners.
class InMemoryPartnerRepository implements PartnerRepository {
  InMemoryPartnerRepository({
    DateTime Function()? now,
    this.onConfirmHandover,
    this.onCancelOrder,
    this.onCompleteAdoption,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final void Function(String orderId)? onConfirmHandover;
  final void Function(String orderId)? onCancelOrder;
  final String Function(String applicationId)? onCompleteAdoption;

  var _seq = 0;
  String? _id;
  PartnerType? _type;
  var _status = PartnerStatus.draft;
  String _name = '';
  String _area = '';
  String? _note;
  DateTime? _submittedAt;
  final Map<DocumentKind, int> _docs = {};
  PayoutSummary? _payout;

  // Fixtures a test or the demo can set.
  List<VisitItem> visits = [];
  List<PartnerListing> listings = [];
  List<Enquiry> enquiries = [];
  List<ShelterApplication> applications = [];
  Earnings? earningsData;
  double? rating;
  int reviewCount = 0;
  int weekKobo = 0;
  int nextPayoutKobo = 0;
  int inEscrowKobo = 0;
  int adoptedMonth = 0;
  final List<SupportTicket> _tickets = [];

  /// Calls recorded for tests.
  final List<String> calls = [];

  /// Stands in for the PawPass team's decision.
  void review(PartnerStatus status, {String? note}) {
    _status = status;
    _note = note;
  }

  /// Makes an approved partner of [type] straight away (for the demo and for dashboard tests).
  void approveAs(PartnerType type, String name, {String area = 'Lekki'}) {
    _id = 'p1';
    _type = type;
    _name = name;
    _area = area;
    _status = PartnerStatus.approved;
    _payout = PayoutSummary(
      bankName: 'Guaranty Trust Bank',
      last4: '2291',
      accountName: name,
    );
    _docs.addAll({
      DocumentKind.ownerId: 1,
      DocumentKind.cac: 1,
      DocumentKind.licence: 1,
      DocumentKind.facilityPhoto: 3,
    });
  }

  List<VerifyStep> _steps() {
    final t = _type!;
    final photos = _docs[DocumentKind.facilityPhoto] ?? 0;
    return [
      VerifyStep(
        key: StepKey.business,
        done: _name.trim().length >= 2 && _area.trim().isNotEmpty,
      ),
      VerifyStep(
        key: StepKey.ownerId,
        done: (_docs[DocumentKind.ownerId] ?? 0) > 0,
      ),
      VerifyStep(key: StepKey.cac, done: (_docs[DocumentKind.cac] ?? 0) > 0),
      if (t == PartnerType.vet)
        VerifyStep(
          key: StepKey.licence,
          done: (_docs[DocumentKind.licence] ?? 0) > 0,
        ),
      VerifyStep(
        key: StepKey.facilityPayout,
        done: photos >= 3 && _payout != null,
        photos: photos,
        hasPayout: _payout != null,
      ),
    ];
  }

  /// Test hook: while set, reading the application fails.
  AppFailure? failApplication;

  @override
  Future<PartnerApplication?> application() async {
    final f = failApplication;
    if (f != null) {
      throw f;
    }
    if (_id == null) {
      return null;
    }
    return PartnerApplication(
      partnerId: _id!,
      type: _type!,
      status: _status,
      businessName: _name,
      area: _area,
      verified: _status == PartnerStatus.approved,
      submittedAt: _submittedAt,
      decisionNote: _note,
      steps: _steps(),
      payout: _payout,
    );
  }

  @override
  Future<String> start({
    required PartnerType type,
    required String businessName,
    required String area,
  }) async {
    calls.add('start');
    if (validNameArea(businessName, area) case final String message) {
      throw AppFailure(message);
    }
    if (_status == PartnerStatus.approved ||
        _status == PartnerStatus.suspended) {
      throw const AppFailure('You already have a partner account');
    }
    if (_status == PartnerStatus.submitted && _id != null) {
      throw const AppFailure('Your application is already being reviewed');
    }
    if (_id == null || _status == PartnerStatus.rejected) {
      _id = 'p${++_seq}';
      _docs.clear();
      _payout = null;
      _type = type;
      _status = PartnerStatus.draft;
    } else if (_status == PartnerStatus.draft) {
      _type = type;
    }
    _name = businessName.trim();
    _area = area.trim();
    return _id!;
  }

  static String? validNameArea(String name, String area) {
    if (name.trim().length < 2 || name.trim().length > 60) {
      return 'Enter your business name (2 to 60 characters)';
    }
    if (area.trim().length < 2 || area.trim().length > 60) {
      return 'Enter the area your business is in';
    }
    return null;
  }

  void _requireEditable() {
    if (_id == null || !_status.editable) {
      throw const AppFailure('This application can no longer be changed');
    }
  }

  @override
  Future<void> addDocument(
    String partnerId,
    DocumentKind kind,
    PickedPhoto photo,
  ) async {
    calls.add('doc:${kind.value}');
    _requireEditable();
    if (kind == DocumentKind.licence && _type != PartnerType.vet) {
      throw const AppFailure(
        'A practising licence is only needed for vet clinics',
      );
    }
    if (kind == DocumentKind.facilityPhoto) {
      if ((_docs[kind] ?? 0) >= 6) {
        throw const AppFailure('You can add up to 6 facility photos');
      }
      _docs[kind] = (_docs[kind] ?? 0) + 1;
    } else {
      _docs[kind] = 1;
    }
  }

  @override
  Future<void> savePayout(
    String partnerId, {
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    calls.add('payout');
    _requireEditable();
    if (!RegExp(r'^\d{10}$').hasMatch(accountNumber)) {
      throw const AppFailure('An account number has 10 digits');
    }
    _payout = PayoutSummary(
      bankName: bankName,
      last4: accountNumber.substring(6),
      accountName: accountName,
    );
  }

  @override
  Future<void> submit(String partnerId) async {
    calls.add('submit');
    _requireEditable();
    if (_steps().any((s) => !s.done)) {
      throw const AppFailure('Finish every step before you submit');
    }
    _status = PartnerStatus.submitted;
    _submittedAt = _now();
    _note = null;
  }

  @override
  Future<PartnerDashboard> dashboard(String partnerId) async {
    if (_status != PartnerStatus.approved) {
      throw const AppFailure('Your partner account is not approved yet');
    }
    final type = _type!;
    return PartnerDashboard(
      partner: PartnerSummary(id: _id!, type: type, name: _name, area: _area),
      visitsToday: visits.length,
      weekKobo: weekKobo,
      rating: rating,
      reviewCount: reviewCount,
      nextPayoutKobo: nextPayoutKobo,
      liveListings: listings.where((l) => l.live).length,
      newEnquiries: enquiries.where((e) => e.unread > 0).length,
      inEscrowKobo: inEscrowKobo,
      petsListed: listings.where((l) => l.live || l.reserved).length,
      newApplications: applications
          .where((a) => a.state == ApplicationState.submitted)
          .length,
      adoptedMonth: adoptedMonth,
      schedule: List.of(visits),
      listings: List.of(listings),
      enquiries: List.of(enquiries),
      applications: List.of(applications),
    );
  }

  @override
  Future<Earnings> earnings(String partnerId) async {
    if (_status != PartnerStatus.approved) {
      throw const AppFailure('Your partner account is not approved yet');
    }
    return earningsData ??
        Earnings(
          nextPayoutOn: DateTime(2026, 11, 9),
          nextPayoutKobo: nextPayoutKobo,
          heldKobo: 0,
          paidMonthKobo: 0,
          bankName: _payout?.bankName,
          accountLast4: _payout?.last4,
          recent: const [],
        );
  }

  @override
  Future<List<CreatedListing>> createListings(
    String partnerId,
    NewListing listing, {
    PickedPhoto? photo,
  }) async {
    calls.add('listing');
    if (_status != PartnerStatus.approved || !(_type?.listsPets ?? false)) {
      throw const AppFailure(
        'Only approved breeders and shelters can list pets',
      );
    }
    final sale = _type == PartnerType.breeder;
    if (sale && (listing.priceKobo ?? 0) < 100000) {
      throw const AppFailure('Enter a price of at least 1,000 naira');
    }
    final created = <CreatedListing>[];
    final fresh = <PartnerListing>[];
    for (var i = 1; i <= listing.count; i++) {
      final n = ++_seq;
      final name = listing.count == 1 ? listing.name : '${listing.name} $i';
      fresh.add(
        PartnerListing(
          listingId: 'l$n',
          petId: 'pet$n',
          petName: name,
          status: 'live',
          sale: sale,
          priceKobo: sale ? listing.priceKobo : null,
        ),
      );
      created.add(CreatedListing(listingId: 'l$n', petId: 'pet$n'));
    }
    listings.insertAll(0, fresh);
    return created;
  }

  @override
  Future<void> setListingLive(String listingId, {required bool live}) async {
    calls.add('status:$listingId:$live');
    final i = listings.indexWhere((l) => l.listingId == listingId);
    if (i < 0) {
      throw const AppFailure(
        'We could not find that. It may have been removed.',
      );
    }
    final l = listings[i];
    if (l.reserved) {
      throw const AppFailure(
        'This listing is in the middle of a sale or adoption',
      );
    }
    if (live) {
      listings[i] = _copy(l, 'live');
    } else {
      listings.removeAt(i);
    }
  }

  PartnerListing _copy(PartnerListing l, String status) => PartnerListing(
    listingId: l.listingId,
    petId: l.petId,
    petName: l.petName,
    status: status,
    sale: l.sale,
    photoPath: l.photoPath,
    priceKobo: l.priceKobo,
    handoverBy: l.handoverBy,
    enquiries: l.enquiries,
    applications: l.applications,
    orderId: l.orderId,
    orderStatus: l.orderStatus,
    buyerName: l.buyerName,
  );

  @override
  Future<void> decide(
    String applicationId,
    ApplicationDecision decision,
  ) async {
    calls.add('decide:$applicationId:${decision.value}');
    final i = applications.indexWhere((a) => a.id == applicationId);
    if (i < 0) {
      throw const AppFailure(
        'We could not find that. It may have been removed.',
      );
    }
    final a = applications[i];
    if (a.state == ApplicationState.approved) {
      throw const AppFailure('This application has already been decided');
    }
    if (decision == ApplicationDecision.decline) {
      applications.removeAt(i);
      return;
    }
    applications[i] = ShelterApplication(
      id: a.id,
      listingId: a.listingId,
      petName: a.petName,
      photoPath: a.photoPath,
      applicantName: a.applicantName,
      state: decision == ApplicationDecision.approve
          ? ApplicationState.approved
          : ApplicationState.homeVisit,
      createdAt: a.createdAt,
      homeType: a.homeType,
      otherPets: a.otherPets,
      daytime: a.daytime,
      why: a.why,
      petsTotal: a.petsTotal,
      petsVaccinated: a.petsVaccinated,
      transferId: a.transferId,
    );
  }

  @override
  Future<String> openApplicationChat(String applicationId) async {
    calls.add('chat:$applicationId');
    return 'conv-$applicationId';
  }

  @override
  Future<String> completeAdoption(String applicationId) async {
    calls.add('handover:$applicationId');
    final a = applications.firstWhere((x) => x.id == applicationId);
    if (a.state != ApplicationState.approved) {
      throw const AppFailure('Approve the application before handing over');
    }
    applications.removeWhere((x) => x.id == applicationId);
    return onCompleteAdoption?.call(applicationId) ?? 't${++_seq}';
  }

  @override
  Future<void> confirmHandover(String orderId) async {
    calls.add('confirm:$orderId');
    onConfirmHandover?.call(orderId);
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    calls.add('cancel:$orderId');
    onCancelOrder?.call(orderId);
  }

  @override
  Future<List<SupportTicket>> tickets() async => List.of(_tickets.reversed);

  @override
  Future<void> createTicket(SupportTopic topic, String message) async {
    calls.add('ticket:${topic.value}');
    final m = message.trim();
    if (m.length < 5 || m.length > 2000) {
      throw const AppFailure('Tell us a little more (5 to 2000 characters)');
    }
    if (_tickets.length >= 5) {
      throw const AppFailure(
        'You have sent a few requests already. We will reply soon.',
      );
    }
    _tickets.add(
      SupportTicket(
        id: 't${_tickets.length + 1}',
        number: _tickets.length + 1,
        topic: topic.value,
        subject: m.length > 80 ? m.substring(0, 80) : m,
        state: TicketState.open,
        createdAt: _now(),
      ),
    );
  }
}
