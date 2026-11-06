import '../domain/models.dart';

/// Finding a pet, paying a deposit into escrow, the handover, the passport transfer, and adoption applications.
/// The money rules live in the database; this only asks. Failures are [AppFailure]s with a readable message.
abstract class AdoptRepository {
  Future<List<AdoptListing>> listings({
    ListingKind? kind,
    String? species,
    String? query,
  });
  Future<ListingDetail> listing(String listingId);

  /// Starts (or reuses) the unpaid order for a sale, ready to pay.
  Future<OrderPayment> createOrder(String listingId);

  /// Drops an unpaid order.
  Future<void> cancelUnpaidOrder(String orderId);

  /// The balance, paid at pick up.
  Future<OrderPayment> balancePayment(String orderId);

  Future<List<OrderSummary>> orders();
  Future<OrderDetail> order(String orderId);

  /// The buyer takes the pet's passport. Moves the pet to them.
  Future<void> acceptPassport(String transferId);

  Future<void> reportProblem(
    String orderId,
    OrderProblem reason, {
    String? details,
  });

  Future<String> openListingChat(String listingId);

  Future<String> apply(String listingId, AdoptionAnswers answers);
  Future<List<ApplicationSummary>> applications();
  Future<TransferDetail> transfer(String transferId);

  /// A short lived link to a pet photo (the bucket is private).
  Future<String?> photoUrl(String path);
}
