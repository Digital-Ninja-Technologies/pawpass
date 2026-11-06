import '../../onboarding/domain/models.dart';
import '../domain/models.dart';

enum ApplicationDecision {
  homeVisit('home_visit'),
  approve('approve'),
  decline('decline');

  const ApplicationDecision(this.value);
  final String value;
}

/// Becoming a partner, the partner dashboards and money, listing pets, and help and support.
/// Every rule lives in the database; this only asks. Failures are [AppFailure]s with a readable message.
abstract class PartnerRepository {
  /// The caller's partner application, or null if they never started one.
  Future<PartnerApplication?> application();

  /// Starts the application, or updates the one in progress. Returns the partner id.
  Future<String> start({
    required PartnerType type,
    required String businessName,
    required String area,
  });

  /// Uploads a document into the private bucket, then records it.
  Future<void> addDocument(
    String partnerId,
    DocumentKind kind,
    PickedPhoto photo,
  );

  Future<void> savePayout(
    String partnerId, {
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  });

  /// Sends a finished application to the PawPass team.
  Future<void> submit(String partnerId);

  Future<PartnerDashboard> dashboard(String partnerId);
  Future<Earnings> earnings(String partnerId);

  /// Lists one pet or a litter. Each pet's photo goes into its own folder.
  Future<List<CreatedListing>> createListings(
    String partnerId,
    NewListing listing, {
    PickedPhoto? photo,
  });

  Future<void> setListingLive(String listingId, {required bool live});

  Future<void> decide(String applicationId, ApplicationDecision decision);

  /// The chat with an applicant (to arrange a home visit).
  Future<String> openApplicationChat(String applicationId);

  /// The shelter hands the pet over. Returns the transfer the adopter then accepts.
  Future<String> completeAdoption(String applicationId);

  /// The seller confirms the pet was handed over.
  Future<void> confirmHandover(String orderId);

  /// The seller cancels before handover. The buyer is refunded in full.
  Future<void> cancelOrder(String orderId, {String? reason});

  Future<List<SupportTicket>> tickets();
  Future<void> createTicket(SupportTopic topic, String message);
}
