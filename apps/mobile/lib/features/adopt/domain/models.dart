DateTime? _time(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();

enum ListingKind {
  sale('sale'),
  adoption('adoption');

  const ListingKind(this.value);
  final String value;

  static ListingKind parse(String? v) => v == 'adoption' ? adoption : sale;
}

/// A pet in the Adopt list.
class AdoptListing {
  const AdoptListing({
    required this.id,
    required this.kind,
    required this.petId,
    required this.petName,
    required this.species,
    required this.partnerId,
    required this.partnerName,
    this.priceKobo,
    this.breed,
    this.sex,
    this.bornOn,
    this.photoPath,
    this.partnerType,
    this.partnerArea,
    this.reserved = false,
  });

  final String id;
  final ListingKind kind;
  final int? priceKobo;
  final String petId;
  final String petName;
  final String species;
  final String? breed;
  final String? sex;
  final DateTime? bornOn;
  final String? photoPath;
  final String partnerId;
  final String partnerName;
  final String? partnerType;
  final String? partnerArea;
  final bool reserved;

  factory AdoptListing.fromRow(Map<String, dynamic> r) => AdoptListing(
    id: r['listing_id'] as String,
    kind: ListingKind.parse(r['kind'] as String?),
    priceKobo: (r['price_kobo'] as num?)?.toInt(),
    petId: r['pet_id'] as String,
    petName: r['pet_name'] as String,
    species: r['species'] as String,
    breed: r['breed'] as String?,
    sex: r['sex'] as String?,
    bornOn: r['born_on'] == null
        ? null
        : DateTime.parse(r['born_on'] as String),
    photoPath: r['photo_path'] as String?,
    partnerId: r['partner_id'] as String,
    partnerName: r['partner_name'] as String,
    partnerType: r['partner_type'] as String?,
    partnerArea: r['partner_area'] as String?,
    reserved: r['reserved'] == true,
  );
}

/// One line of the pet's health record the seller chose to show with the listing.
class ListingRecord {
  const ListingRecord({
    required this.type,
    required this.name,
    this.givenOn,
    this.verified = false,
  });
  final String type;
  final String name;
  final DateTime? givenOn;
  final bool verified;

  factory ListingRecord.fromJson(Map<String, dynamic> r) => ListingRecord(
    type: r['type'] as String,
    name: r['name'] as String,
    givenOn: r['given_on'] == null
        ? null
        : DateTime.parse(r['given_on'] as String),
    verified: r['verified'] == true,
  );
}

class ListingDetail {
  const ListingDetail({
    required this.listing,
    required this.status,
    this.depositKobo,
    this.protectionFeeKobo,
    this.dueTodayKobo,
    this.balanceKobo,
    this.handoverBy,
    this.colour,
    this.motherName,
    this.fatherName,
    this.partnerVerified = false,
    this.records = const [],
    this.isMine = false,
    this.myOrderId,
    this.myOrderStatus,
    this.myApplicationId,
    this.myApplicationStatus,
    this.myTransferId,
  });

  final AdoptListing listing;
  final String status;
  final int? depositKobo;
  final int? protectionFeeKobo;
  final int? dueTodayKobo;
  final int? balanceKobo;
  final DateTime? handoverBy;
  final String? colour;
  final String? motherName;
  final String? fatherName;
  final bool partnerVerified;
  final List<ListingRecord> records;
  final bool isMine;
  final String? myOrderId;
  final String? myOrderStatus;
  final String? myApplicationId;
  final String? myApplicationStatus;
  final String? myTransferId;

  bool get available => status == 'live';

  factory ListingDetail.fromJson(Map<String, dynamic> r) {
    final pet = Map<String, dynamic>.from(r['pet'] as Map);
    final partner = Map<String, dynamic>.from(r['partner'] as Map);
    return ListingDetail(
      listing: AdoptListing(
        id: r['listing_id'] as String,
        kind: ListingKind.parse(r['kind'] as String?),
        priceKobo: (r['price_kobo'] as num?)?.toInt(),
        petId: pet['id'] as String,
        petName: pet['name'] as String,
        species: pet['species'] as String,
        breed: pet['breed'] as String?,
        sex: pet['sex'] as String?,
        bornOn: pet['born_on'] == null
            ? null
            : DateTime.parse(pet['born_on'] as String),
        photoPath: pet['photo_path'] as String?,
        partnerId: partner['id'] as String,
        partnerName: partner['name'] as String,
        partnerType: partner['type'] as String?,
        partnerArea: partner['area'] as String?,
        reserved: r['status'] == 'reserved',
      ),
      status: r['status'] as String,
      depositKobo: (r['deposit_kobo'] as num?)?.toInt(),
      protectionFeeKobo: (r['protection_fee_kobo'] as num?)?.toInt(),
      dueTodayKobo: (r['due_today_kobo'] as num?)?.toInt(),
      balanceKobo: (r['balance_kobo'] as num?)?.toInt(),
      handoverBy: _time(r['handover_by']),
      colour: pet['colour'] as String?,
      motherName: r['mother_name'] as String?,
      fatherName: r['father_name'] as String?,
      partnerVerified: partner['verified'] == true,
      records: [
        for (final x in (r['records'] as List? ?? const []))
          ListingRecord.fromJson(Map<String, dynamic>.from(x as Map)),
      ],
      isMine: r['is_mine'] == true,
      myOrderId: r['my_order_id'] as String?,
      myOrderStatus: r['my_order_status'] as String?,
      myApplicationId: r['my_application_id'] as String?,
      myApplicationStatus: r['my_application_status'] as String?,
      myTransferId: r['my_transfer_id'] as String?,
    );
  }
}

/// The unpaid order and its Paystack reference (deposit), or the balance payment reference.
class OrderPayment {
  const OrderPayment({
    required this.orderId,
    required this.reference,
    required this.amountKobo,
    this.petName,
    this.partnerName,
  });

  final String orderId;
  final String reference;
  final int amountKobo;
  final String? petName;
  final String? partnerName;

  factory OrderPayment.fromJson(Map<String, dynamic> r) => OrderPayment(
    orderId: r['order_id'] as String,
    reference: r['reference'] as String,
    amountKobo: (r['amount_kobo'] as num).toInt(),
    petName: r['pet_name'] as String?,
    partnerName: r['partner_name'] as String?,
  );
}

enum OrderStatus {
  pendingDeposit('pending_deposit'),
  depositPaid('deposit_paid'),
  balancePaid('balance_paid'),
  handedOver('handed_over'),
  completed('completed'),
  disputed('disputed'),
  cancelled('cancelled');

  const OrderStatus(this.value);
  final String value;

  static OrderStatus parse(String v) =>
      values.firstWhere((s) => s.value == v, orElse: () => pendingDeposit);
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.status,
    required this.petId,
    required this.petName,
    required this.species,
    required this.partnerName,
    required this.priceKobo,
    required this.depositKobo,
    required this.protectionFeeKobo,
    required this.balanceKobo,
    required this.isBuyer,
    this.listingId,
    this.breed,
    this.photoPath,
    this.buyerName,
    this.depositPaid = false,
    this.balancePaid = false,
    this.handoverBy,
    this.handedOverAt,
    this.vetCheckEndsAt,
    this.acceptedAt,
    this.transferId,
    this.transferCompleted = false,
    this.disputeStatus,
    this.disputeDueAt,
    this.cancelReason,
  });

  final String id;
  final OrderStatus status;
  final String? listingId;
  final String petId;
  final String petName;
  final String species;
  final String? breed;
  final String? photoPath;
  final String partnerName;
  final String? buyerName;
  final int priceKobo;
  final int depositKobo;
  final int protectionFeeKobo;
  final int balanceKobo;
  final bool isBuyer;
  final bool depositPaid;
  final bool balancePaid;
  final DateTime? handoverBy;
  final DateTime? handedOverAt;
  final DateTime? vetCheckEndsAt;
  final DateTime? acceptedAt;
  final String? transferId;
  final bool transferCompleted;
  final String? disputeStatus;
  final DateTime? disputeDueAt;
  final String? cancelReason;

  factory OrderDetail.fromJson(Map<String, dynamic> r) => OrderDetail(
    id: r['order_id'] as String,
    status: OrderStatus.parse(r['status'] as String),
    listingId: r['listing_id'] as String?,
    petId: r['pet_id'] as String,
    petName: r['pet_name'] as String,
    species: r['species'] as String,
    breed: r['breed'] as String?,
    photoPath: r['photo_path'] as String?,
    partnerName: r['partner_name'] as String,
    buyerName: r['buyer_name'] as String?,
    priceKobo: (r['price_kobo'] as num).toInt(),
    depositKobo: (r['deposit_kobo'] as num).toInt(),
    protectionFeeKobo: (r['protection_fee_kobo'] as num).toInt(),
    balanceKobo: (r['balance_kobo'] as num).toInt(),
    isBuyer: r['is_buyer'] == true,
    depositPaid: r['deposit_paid'] == true,
    balancePaid: r['balance_paid'] == true,
    handoverBy: _time(r['handover_by']),
    handedOverAt: _time(r['handed_over_at']),
    vetCheckEndsAt: _time(r['vet_check_ends_at']),
    acceptedAt: _time(r['accepted_at']),
    transferId: r['transfer_id'] as String?,
    transferCompleted: r['transfer_completed'] == true,
    disputeStatus: r['dispute_status'] as String?,
    disputeDueAt: _time(r['dispute_due_at']),
    cancelReason: r['cancel_reason'] as String?,
  );
}

/// A row of "your orders".
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.status,
    required this.petName,
    required this.partnerName,
    required this.priceKobo,
    required this.createdAt,
    required this.isBuyer,
  });

  final String id;
  final OrderStatus status;
  final String petName;
  final String partnerName;
  final int priceKobo;
  final DateTime createdAt;
  final bool isBuyer;

  factory OrderSummary.fromRow(Map<String, dynamic> r) => OrderSummary(
    id: r['order_id'] as String,
    status: OrderStatus.parse(r['status'] as String),
    petName: r['pet_name'] as String,
    partnerName: r['partner_name'] as String,
    priceKobo: (r['price_kobo'] as num).toInt(),
    createdAt: _time(r['created_at'])!,
    isBuyer: r['is_buyer'] == true,
  );
}

class ApplicationSummary {
  const ApplicationSummary({
    required this.id,
    required this.listingId,
    required this.status,
    required this.petName,
    required this.partnerName,
    required this.createdAt,
    this.transferId,
  });

  final String id;
  final String listingId;
  final String status;
  final String petName;
  final String partnerName;
  final DateTime createdAt;
  final String? transferId;

  factory ApplicationSummary.fromRow(Map<String, dynamic> r) =>
      ApplicationSummary(
        id: r['application_id'] as String,
        listingId: r['listing_id'] as String,
        status: r['status'] as String,
        petName: r['pet_name'] as String,
        partnerName: r['partner_name'] as String,
        createdAt: _time(r['created_at'])!,
        transferId: r['transfer_id'] as String?,
      );
}

enum HomeType {
  house('house', 'House with compound'),
  flat('flat', 'Flat or apartment'),
  other('other', 'Other');

  const HomeType(this.value, this.label);
  final String value;
  final String label;
}

class AdoptionAnswers {
  const AdoptionAnswers({
    required this.homeType,
    required this.why,
    required this.agreeVisit,
    this.otherPets = '',
    this.daytime = '',
  });

  final HomeType homeType;
  final String otherPets;
  final String daytime;
  final String why;
  final bool agreeVisit;

  Map<String, dynamic> toJson() => {
    'home_type': homeType.value,
    'other_pets': otherPets.trim(),
    'daytime': daytime.trim(),
    'why': why.trim(),
    'agree_visit': agreeVisit,
  };
}

class TransferDetail {
  const TransferDetail({
    required this.id,
    required this.kind,
    required this.petId,
    required this.petName,
    required this.species,
    required this.partnerName,
    required this.isReceiver,
    this.breed,
    this.handoverConfirmedAt,
    this.completedAt,
    this.records = 0,
    this.verifiedRecords = 0,
    this.orderId,
  });

  final String id;
  final ListingKind kind;
  final String petId;
  final String petName;
  final String species;
  final String? breed;
  final String partnerName;
  final bool isReceiver;
  final DateTime? handoverConfirmedAt;
  final DateTime? completedAt;
  final int records;
  final int verifiedRecords;
  final String? orderId;

  factory TransferDetail.fromJson(Map<String, dynamic> r) => TransferDetail(
    id: r['transfer_id'] as String,
    kind: ListingKind.parse(r['kind'] as String?),
    petId: r['pet_id'] as String,
    petName: r['pet_name'] as String,
    species: r['species'] as String,
    breed: r['breed'] as String?,
    partnerName: r['partner_name'] as String,
    isReceiver: r['is_receiver'] == true,
    handoverConfirmedAt: _time(r['handover_confirmed_at']),
    completedAt: _time(r['completed_at']),
    records: (r['records'] as num?)?.toInt() ?? 0,
    verifiedRecords: (r['verified_records'] as num?)?.toInt() ?? 0,
    orderId: r['order_id'] as String?,
  );
}

enum OrderProblem {
  healthProblem('health_problem', 'A vet found a health problem'),
  notAsDescribed('not_as_described', 'Not as described'),
  other('other', 'Something else');

  const OrderProblem(this.value, this.label);
  final String value;
  final String label;
}
