import '../domain/models.dart';

/// QR tag orders, who an owner is sharing records with, and blocked accounts.
/// Every rule lives in the database; this only asks. Failures are [AppFailure]s with a readable message.
abstract class AccountRepository {
  /// What a tag and its delivery cost right now (set in admin settings).
  Future<TagPrices> tagPrices();

  /// Places an order that waits for payment. The price is read on the server.
  Future<TagIntent> createTagOrder({
    required String petId,
    required TagColour colour,
    required String address,
    required String area,
  });

  Future<List<TagOrder>> myTagOrders();

  /// Passports the owner is sharing now (not revoked, not expired).
  Future<List<ActiveShare>> activeShares();

  Future<List<BlockedAccount>> blocks();
  Future<void> unblock(String blockId);
}
