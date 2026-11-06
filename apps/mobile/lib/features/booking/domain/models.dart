enum ServiceCategory {
  vet('vet', 'Vets'),
  grooming('grooming', 'Grooming'),
  training('training', 'Training'),
  boarding('boarding', 'Boarding');

  const ServiceCategory(this.value, this.label);
  final String value;
  final String label;

  static ServiceCategory? parse(String? v) {
    for (final c in values) {
      if (c.value == v) return c;
    }
    return null;
  }
}

/// A provider in the Services list.
class ProviderSummary {
  const ProviderSummary({
    required this.id,
    required this.name,
    this.area,
    this.address,
    this.categories = const [],
    this.ratingAvg,
    this.ratingCount = 0,
    this.fromPriceKobo,
    this.nextSlot,
    this.distanceM,
    this.openNow = false,
    this.open24h = false,
    this.closesAt,
    this.homeVisits = false,
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final String? area;
  final String? address;
  final List<ServiceCategory> categories;
  final double? ratingAvg;
  final int ratingCount;
  final int? fromPriceKobo;
  final DateTime? nextSlot;
  final int? distanceM;
  final bool openNow;
  final bool open24h;

  /// Closing time as "20:00:00" (Lagos), or null.
  final String? closesAt;
  final bool homeVisits;
  final double? lat;
  final double? lng;

  factory ProviderSummary.fromRow(Map<String, dynamic> r) => ProviderSummary(
    id: r['partner_id'] as String,
    name: r['name'] as String,
    area: r['area'] as String?,
    address: r['address'] as String?,
    categories: [
      for (final c in (r['categories'] as List? ?? const []))
        ?ServiceCategory.parse(c as String?),
    ],
    ratingAvg: (r['rating_avg'] as num?)?.toDouble(),
    ratingCount: (r['rating_count'] as num?)?.toInt() ?? 0,
    fromPriceKobo: (r['from_price_kobo'] as num?)?.toInt(),
    nextSlot: _time(r['next_slot']),
    distanceM: (r['distance_m'] as num?)?.toInt(),
    openNow: r['open_now'] == true,
    open24h: r['open_24h'] == true,
    closesAt: r['closes_at'] as String?,
    homeVisits: r['home_visits'] == true,
    lat: (r['lat'] as num?)?.toDouble(),
    lng: (r['lng'] as num?)?.toDouble(),
  );
}

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.priceKobo,
    required this.durationMin,
    this.category = ServiceCategory.vet,
    this.description,
  });

  final String id;
  final String name;
  final int priceKobo;
  final int durationMin;
  final ServiceCategory category;
  final String? description;

  factory ServiceItem.fromJson(Map<String, dynamic> r) => ServiceItem(
    id: r['id'] as String,
    name: r['name'] as String,
    priceKobo: (r['price_kobo'] as num).toInt(),
    durationMin: (r['duration_min'] as num?)?.toInt() ?? 30,
    category:
        ServiceCategory.parse(r['category'] as String?) ?? ServiceCategory.vet,
    description: r['description'] as String?,
  );
}

class ProviderDetail {
  const ProviderDetail({
    required this.summary,
    required this.services,
    this.verified = false,
    this.type,
  });

  final ProviderSummary summary;
  final List<ServiceItem> services;
  final bool verified;
  final String? type;

  String get id => summary.id;

  factory ProviderDetail.fromJson(Map<String, dynamic> r) => ProviderDetail(
    summary: ProviderSummary(
      id: r['id'] as String,
      name: r['name'] as String,
      area: r['area'] as String?,
      address: r['address'] as String?,
      ratingAvg: (r['rating_avg'] as num?)?.toDouble(),
      ratingCount: (r['rating_count'] as num?)?.toInt() ?? 0,
      distanceM: (r['distance_m'] as num?)?.toInt(),
      open24h: r['open_24h'] == true,
      closesAt: r['closes_at'] as String?,
      homeVisits: r['home_visits'] == true,
      lat: (r['lat'] as num?)?.toDouble(),
      lng: (r['lng'] as num?)?.toDouble(),
    ),
    services: [
      for (final s in (r['services'] as List? ?? const []))
        ServiceItem.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
    verified: r['verified'] == true,
    type: r['type'] as String?,
  );
}

class Slot {
  const Slot({
    required this.startsAt,
    required this.endsAt,
    required this.free,
  });
  final DateTime startsAt;
  final DateTime endsAt;
  final int free;

  bool get isFree => free > 0;

  factory Slot.fromRow(Map<String, dynamic> r) => Slot(
    startsAt: _time(r['starts_at'])!,
    endsAt: _time(r['ends_at'])!,
    free: (r['free'] as num?)?.toInt() ?? 0,
  );
}

class ReviewItem {
  const ReviewItem({
    required this.rating,
    this.tags = const [],
    this.body,
    this.reviewer,
    this.serviceName,
    this.createdAt,
  });

  final int rating;
  final List<String> tags;
  final String? body;
  final String? reviewer;
  final String? serviceName;
  final DateTime? createdAt;

  factory ReviewItem.fromRow(Map<String, dynamic> r) => ReviewItem(
    rating: (r['rating'] as num).toInt(),
    tags: [for (final t in (r['tags'] as List? ?? const [])) t as String],
    body: r['body'] as String?,
    reviewer: r['reviewer'] as String?,
    serviceName: r['service_name'] as String?,
    createdAt: _time(r['created_at']),
  );
}

/// What `create_booking` hands back: the unpaid booking and the Paystack reference to pay.
class BookingIntent {
  const BookingIntent({
    required this.bookingId,
    required this.reference,
    required this.amountKobo,
    required this.serviceName,
    required this.partnerName,
    required this.startsAt,
  });

  final String bookingId;
  final String reference;
  final int amountKobo;
  final String serviceName;
  final String partnerName;
  final DateTime startsAt;

  factory BookingIntent.fromJson(Map<String, dynamic> r) => BookingIntent(
    bookingId: r['booking_id'] as String,
    reference: r['reference'] as String,
    amountKobo: (r['amount_kobo'] as num).toInt(),
    serviceName: r['service_name'] as String,
    partnerName: r['partner_name'] as String,
    startsAt: _time(r['starts_at'])!,
  );
}

enum BookingStatus {
  pendingPayment('pending_payment'),
  confirmed('confirmed'),
  completedAwaitingOwner('completed_awaiting_owner'),
  completed('completed'),
  cancelled('cancelled'),
  disputed('disputed');

  const BookingStatus(this.value);
  final String value;

  static BookingStatus parse(String v) =>
      values.firstWhere((s) => s.value == v, orElse: () => confirmed);
}

enum EscrowStatus {
  held('held'),
  ready('ready'),
  paused('paused'),
  released('released'),
  refunded('refunded'),
  partiallyRefunded('partially_refunded');

  const EscrowStatus(this.value);
  final String value;

  static EscrowStatus? parse(String? v) {
    for (final s in values) {
      if (s.value == v) return s;
    }
    return null;
  }
}

/// One of the owner's bookings (the `my_bookings` function).
class Booking {
  const Booking({
    required this.id,
    required this.status,
    required this.startsAt,
    required this.serviceName,
    required this.amountKobo,
    required this.partnerId,
    required this.partnerName,
    required this.petId,
    required this.petName,
    this.partnerAddress,
    this.partnerLat,
    this.partnerLng,
    this.escrow,
    this.rating,
    this.partnerDoneAt,
    this.disputeStatus,
    this.disputeDueAt,
    this.canCancelUntil,
  });

  final String id;
  final BookingStatus status;
  final DateTime startsAt;
  final String serviceName;
  final int amountKobo;
  final String partnerId;
  final String partnerName;
  final String? partnerAddress;
  final double? partnerLat;
  final double? partnerLng;
  final String petId;
  final String petName;
  final EscrowStatus? escrow;
  final int? rating;
  final DateTime? partnerDoneAt;
  final String? disputeStatus;
  final DateTime? disputeDueAt;

  /// The last moment cancelling is free.
  final DateTime? canCancelUntil;

  factory Booking.fromRow(Map<String, dynamic> r) => Booking(
    id: r['booking_id'] as String,
    status: BookingStatus.parse(r['status'] as String),
    startsAt: _time(r['starts_at'])!,
    serviceName: (r['service_name'] as String?) ?? 'Visit',
    amountKobo: (r['amount_kobo'] as num?)?.toInt() ?? 0,
    partnerId: r['partner_id'] as String,
    partnerName: r['partner_name'] as String,
    partnerAddress: r['partner_address'] as String?,
    partnerLat: (r['partner_lat'] as num?)?.toDouble(),
    partnerLng: (r['partner_lng'] as num?)?.toDouble(),
    petId: r['pet_id'] as String,
    petName: r['pet_name'] as String,
    escrow: EscrowStatus.parse(r['escrow_status'] as String?),
    rating: (r['rating'] as num?)?.toInt(),
    partnerDoneAt: _time(r['partner_done_at']),
    disputeStatus: r['dispute_status'] as String?,
    disputeDueAt: _time(r['dispute_due_at']),
    canCancelUntil: _time(r['can_cancel_until']),
  );
}

enum DisputeReason {
  notDone('not_done', "Service didn't happen"),
  hurtOrSick('hurt_or_sick', 'My pet was hurt or got sick'),
  notAsPromised('not_as_promised', 'Not what was promised'),
  other('other', 'Something else');

  const DisputeReason(this.value, this.label);
  final String value;
  final String label;
}

/// The quick tags on the review screen.
const reviewTags = [
  'On time',
  'Gentle',
  'Clean space',
  'Good value',
  'Friendly',
];

/// Words for each star rating.
String ratingWord(int stars) => switch (stars) {
  1 => 'Poor',
  2 => 'Fair',
  3 => 'Good',
  4 => 'Great',
  5 => 'Excellent',
  _ => '',
};

/// Where a payment attempt stands.
enum PaymentOutcome { paid, pending, failed }

class PaymentCheckout {
  const PaymentCheckout({required this.url, required this.reference});
  final Uri url;
  final String reference;
}

DateTime? _time(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();
