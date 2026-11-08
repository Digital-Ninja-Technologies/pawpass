import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'account_repository.dart';

/// A pretend account back end for tests and the debug demo. Follows the database rules: a tag order waits for
/// payment, the price comes from settings, and only the caller's own orders are listed.
class InMemoryAccountRepository implements AccountRepository {
  InMemoryAccountRepository({
    DateTime Function()? now,
    this.prices = const TagPrices(priceKobo: 350000, deliveryKobo: 100000),
    this.petName,
    this.sharesSource,
  }) : _now = now ?? DateTime.now;

  /// Looks up a pet's name for an order (the demo wires this to the pretend pets).
  final String? Function(String petId)? petName;

  /// Extra shares to list, read live (the demo wires this to the pretend health repository's shares).
  final List<ActiveShare> Function()? sharesSource;

  final DateTime Function() _now;
  TagPrices prices;

  // Fixtures a test or the demo can set.
  List<String> deletionBlockerList = [];
  var deleted = false;
  List<ActiveShare> shares = [];
  List<BlockedAccount> blocked = [];
  AppFailure? failNext;

  final List<TagOrder> orders = [];
  final Map<String, String> _petNames = {};
  var _seq = 0;

  /// Lets the fake know a pet's name, so a listed order can show it.
  void knowPet(String id, String name) => _petNames[id] = name;

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  Future<TagPrices> tagPrices() async {
    _maybeFail();
    return prices;
  }

  @override
  Future<TagIntent> createTagOrder({
    required String petId,
    required TagColour colour,
    required String address,
    required String area,
  }) async {
    _maybeFail();
    if (address.trim().length < 5) {
      throw const AppFailure('Enter the street address');
    }
    if (area.trim().length < 2) {
      throw const AppFailure('Enter the area');
    }
    _seq++;
    final id = 'tag-$_seq';
    final reference = 'pt_${_seq.toString().padLeft(32, '0')}';
    orders.insert(
      0,
      TagOrder(
        id: id,
        petName: _petNames[petId] ?? petName?.call(petId) ?? 'Your pet',
        colour: colour,
        status: TagOrderStatus.pendingPayment,
        totalKobo: prices.totalKobo,
        createdAt: _now(),
        reference: reference,
      ),
    );
    return TagIntent(
      orderId: id,
      reference: reference,
      totalKobo: prices.totalKobo,
    );
  }

  /// What the payments webhook does once Paystack confirms the money. False if the reference is not a tag order.
  bool markPaid(String reference) {
    final i = orders.indexWhere((o) => o.reference == reference);
    if (i < 0) {
      return false;
    }
    final o = orders[i];
    if (o.status == TagOrderStatus.pendingPayment) {
      orders[i] = TagOrder(
        id: o.id,
        petName: o.petName,
        colour: o.colour,
        status: TagOrderStatus.paid,
        totalKobo: o.totalKobo,
        createdAt: o.createdAt,
        reference: o.reference,
      );
    }
    return true;
  }

  @override
  Future<List<TagOrder>> myTagOrders() async {
    _maybeFail();
    return List.of(orders);
  }

  @override
  Future<List<ActiveShare>> activeShares() async {
    _maybeFail();
    final now = _now();
    return [
      for (final s in [...shares, ...?sharesSource?.call()])
        if (s.expiresAt.isAfter(now)) s,
    ];
  }

  /// Mirrors revoking a share elsewhere (the health repository does the real revoke).
  void dropShare(String id) => shares = [
    for (final s in shares)
      if (s.id != id) s,
  ];

  @override
  Future<List<String>> deletionBlockers() async {
    _maybeFail();
    return List.of(deletionBlockerList);
  }

  @override
  Future<void> deleteAccount() async {
    _maybeFail();
    if (deletionBlockerList.isNotEmpty) {
      throw AppFailure(deletionBlockerList.join(' '));
    }
    deleted = true;
  }

  @override
  Future<List<BlockedAccount>> blocks() async {
    _maybeFail();
    return List.of(blocked);
  }

  @override
  Future<void> unblock(String blockId) async {
    _maybeFail();
    blocked = [
      for (final b in blocked)
        if (b.id != blockId) b,
    ];
  }
}
