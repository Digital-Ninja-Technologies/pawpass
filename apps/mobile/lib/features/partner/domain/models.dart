import '../../onboarding/domain/models.dart' show Species, PetSex;

/// The four kinds of partner. The value is what the database stores.
enum PartnerType {
  vet('vet', 'Vet clinic or vet', 'Bookings, verified health records'),
  service('service', 'Groomer, trainer or boarding', 'Bookings and payouts'),
  breeder('breeder', 'Breeder', 'Litter listings, escrow sales'),
  shelter(
    'shelter',
    'Shelter or rescue',
    'Free listings, adoption applications',
  );

  const PartnerType(this.value, this.label, this.blurb);
  final String value;
  final String label;
  final String blurb;

  static PartnerType? parse(String? v) {
    for (final t in values) {
      if (t.value == v) {
        return t;
      }
    }
    return null;
  }

  /// Vets and service providers take bookings; breeders and shelters list pets.
  bool get takesBookings => this == vet || this == service;
  bool get listsPets => this == breeder || this == shelter;

  /// Short name used in the dashboard overline ("PARTNER MODE · BREEDER").
  String get shortLabel => switch (this) {
    vet => 'Vet',
    service => 'Service',
    breeder => 'Breeder',
    shelter => 'Shelter',
  };
}

enum PartnerStatus {
  draft,
  submitted,
  needsInfo,
  approved,
  rejected,
  suspended;

  static PartnerStatus parse(String? v) => switch (v) {
    'submitted' => submitted,
    'needs_info' => needsInfo,
    'approved' => approved,
    'rejected' => rejected,
    'suspended' => suspended,
    _ => draft,
  };

  /// Still being filled in by the applicant.
  bool get editable => this == draft || this == needsInfo;
}

/// The verification steps. [facilityPayout] is "Facility photos & payout account".
enum StepKey {
  business('business'),
  ownerId('owner_id'),
  cac('cac'),
  licence('licence'),
  facilityPayout('facility_payout');

  const StepKey(this.value);
  final String value;

  static StepKey? parse(String? v) {
    for (final k in values) {
      if (k.value == v) {
        return k;
      }
    }
    return null;
  }
}

class VerifyStep {
  const VerifyStep({
    required this.key,
    required this.done,
    this.photos = 0,
    this.hasPayout = false,
  });
  final StepKey key;
  final bool done;
  final int photos;
  final bool hasPayout;
}

class PayoutSummary {
  const PayoutSummary({
    required this.bankName,
    required this.last4,
    required this.accountName,
  });
  final String bankName;
  final String last4;
  final String accountName;
}

/// The caller's partner application: where they stand and what is left.
class PartnerApplication {
  const PartnerApplication({
    required this.partnerId,
    required this.type,
    required this.status,
    required this.businessName,
    required this.area,
    required this.steps,
    this.verified = false,
    this.submittedAt,
    this.decisionNote,
    this.payout,
  });

  final String partnerId;
  final PartnerType type;
  final PartnerStatus status;
  final String businessName;
  final String area;
  final bool verified;
  final DateTime? submittedAt;
  final String? decisionNote;
  final List<VerifyStep> steps;
  final PayoutSummary? payout;

  int get stepsTotal => steps.length;
  int get stepsDone => steps.where((s) => s.done).length;
  bool get canSubmit => status.editable && stepsDone == stepsTotal;
  bool get approved => status == PartnerStatus.approved;

  VerifyStep? step(StepKey key) {
    for (final s in steps) {
      if (s.key == key) {
        return s;
      }
    }
    return null;
  }
}

/// A document the applicant can upload.
enum DocumentKind {
  ownerId('owner_id'),
  cac('cac'),
  licence('licence'),
  facilityPhoto('facility_photo');

  const DocumentKind(this.value);
  final String value;
}

// ---------------------------------------------------------------- dashboards

class PartnerSummary {
  const PartnerSummary({
    required this.id,
    required this.type,
    required this.name,
    this.area,
  });
  final String id;
  final PartnerType type;
  final String name;
  final String? area;
}

class VisitItem {
  const VisitItem({
    required this.bookingId,
    required this.startsAt,
    required this.service,
    required this.petName,
    required this.petId,
    required this.ownerName,
    required this.status,
    required this.passportShared,
    this.breed,
  });
  final String bookingId;
  final DateTime startsAt;
  final String service;
  final String petName;
  final String petId;
  final String ownerName;
  final String status;
  final bool passportShared;
  final String? breed;

  bool get done =>
      status == 'completed' || status == 'completed_awaiting_owner';
}

/// A free time a partner has opened for booking.
class OpenSlot {
  const OpenSlot({
    required this.slotId,
    required this.startsAt,
    required this.endsAt,
  });
  final String slotId;
  final DateTime startsAt;
  final DateTime endsAt;
}

/// Visits and free times over a stretch of days, for the partner calendar.
class PartnerCalendar {
  const PartnerCalendar({this.visits = const [], this.open = const []});
  final List<VisitItem> visits;
  final List<OpenSlot> open;
}

class PartnerListing {
  const PartnerListing({
    required this.listingId,
    required this.petId,
    required this.petName,
    required this.status,
    required this.sale,
    this.photoPath,
    this.priceKobo,
    this.handoverBy,
    this.enquiries = 0,
    this.applications = 0,
    this.orderId,
    this.orderStatus,
    this.buyerName,
  });
  final String listingId;
  final String petId;
  final String petName;
  final String? photoPath;
  final String status;
  final bool sale;
  final int? priceKobo;
  final DateTime? handoverBy;
  final int enquiries;
  final int applications;
  final String? orderId;
  final String? orderStatus;
  final String? buyerName;

  bool get reserved => status == 'reserved';
  bool get live => status == 'live';
}

class Enquiry {
  const Enquiry({
    required this.conversationId,
    required this.listingId,
    required this.petName,
    required this.otherName,
    required this.unread,
    this.lastBody,
    this.lastAt,
  });
  final String conversationId;
  final String listingId;
  final String petName;
  final String otherName;
  final String? lastBody;
  final DateTime? lastAt;
  final int unread;
}

enum ApplicationState {
  submitted,
  homeVisit,
  approved;

  static ApplicationState parse(String? v) => switch (v) {
    'home_visit' => homeVisit,
    'approved' => approved,
    _ => submitted,
  };
}

class ShelterApplication {
  const ShelterApplication({
    required this.id,
    required this.listingId,
    required this.petName,
    required this.applicantName,
    required this.state,
    required this.createdAt,
    this.photoPath,
    this.homeType,
    this.otherPets,
    this.daytime,
    this.why,
    this.petsTotal = 0,
    this.petsVaccinated = 0,
    this.transferId,
  });
  final String id;
  final String listingId;
  final String petName;
  final String? photoPath;
  final String applicantName;
  final ApplicationState state;
  final DateTime createdAt;
  final String? homeType;
  final String? otherPets;
  final String? daytime;
  final String? why;
  final int petsTotal;
  final int petsVaccinated;
  final String? transferId;

  /// "Current pets are vaccinated, per their passports": only said when they have pets and all have a vaccine.
  bool get petsVaccinatedAll => petsTotal > 0 && petsVaccinated == petsTotal;
}

class PartnerDashboard {
  const PartnerDashboard({
    required this.partner,
    this.visitsToday = 0,
    this.weekKobo = 0,
    this.rating,
    this.reviewCount = 0,
    this.nextPayoutKobo = 0,
    this.liveListings = 0,
    this.newEnquiries = 0,
    this.inEscrowKobo = 0,
    this.petsListed = 0,
    this.newApplications = 0,
    this.adoptedMonth = 0,
    this.stalePets = 0,
    this.schedule = const [],
    this.listings = const [],
    this.enquiries = const [],
    this.applications = const [],
  });
  final PartnerSummary partner;
  final int visitsToday;
  final int weekKobo;
  final double? rating;
  final int reviewCount;
  final int nextPayoutKobo;
  final int liveListings;
  final int newEnquiries;
  final int inEscrowKobo;
  final int petsListed;
  final int newApplications;
  final int adoptedMonth;
  final int stalePets;
  final List<VisitItem> schedule;
  final List<PartnerListing> listings;
  final List<Enquiry> enquiries;
  final List<ShelterApplication> applications;
}

// ------------------------------------------------------------------ earnings

enum EarningState { held, ready, paused, released, refunded, sent, other }

class EarningItem {
  const EarningItem({
    required this.title,
    required this.state,
    required this.amountKobo,
    required this.at,
    required this.payout,
  });
  final String title;
  final EarningState state;
  final int amountKobo;
  final DateTime at;

  /// True for a weekly payout row rather than a payment.
  final bool payout;
}

class Earnings {
  const Earnings({
    required this.nextPayoutOn,
    required this.nextPayoutKobo,
    required this.heldKobo,
    required this.paidMonthKobo,
    required this.recent,
    this.bankName,
    this.accountLast4,
  });
  final DateTime nextPayoutOn;
  final int nextPayoutKobo;
  final int heldKobo;
  final int paidMonthKobo;
  final String? bankName;
  final String? accountLast4;
  final List<EarningItem> recent;
}

// ------------------------------------------------------------------- listing

/// What a breeder or shelter fills in to list a pet or a litter.
class NewListing {
  const NewListing({
    required this.name,
    required this.species,
    this.breed,
    this.sex = PetSex.unknown,
    this.bornOn,
    this.priceKobo,
    this.count = 1,
    this.motherPetId,
    this.fatherPetId,
    this.handoverBy,
  });
  final String name;
  final Species species;
  final String? breed;
  final PetSex sex;
  final DateTime? bornOn;
  final int? priceKobo;
  final int count;
  final String? motherPetId;
  final String? fatherPetId;
  final DateTime? handoverBy;
}

/// A listing and pet just created (the app uploads each pet's photo into its own folder).
class CreatedListing {
  const CreatedListing({required this.listingId, required this.petId});
  final String listingId;
  final String petId;
}

// ------------------------------------------------------------------- support

enum SupportTopic {
  payments('payments', 'Payments & refunds'),
  bookings('bookings', 'Bookings'),
  account('account', 'My account'),
  lostPet('lost_pet', 'Lost pet alerts & QR tags'),
  partner('partner', 'Being a partner'),
  other('other', 'Something else');

  const SupportTopic(this.value, this.label);
  final String value;
  final String label;
}

enum TicketState { open, replied, closed }

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.number,
    required this.topic,
    required this.subject,
    required this.state,
    required this.createdAt,
  });
  final String id;
  final int number;
  final String topic;
  final String subject;
  final TicketState state;
  final DateTime createdAt;

  /// The number people quote: "#S-2201".
  String get label => '#S-${2200 + number}';
}
