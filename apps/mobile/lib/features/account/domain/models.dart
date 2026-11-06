import 'package:flutter/painting.dart';

import '../../health/domain/models.dart' show ShareScope;

/// The three tag colours (design/screens/QrTagOrder.dc.html).
enum TagColour {
  teal('teal', 'Teal', Color(0xFF0E6B63), Color(0xFFE3F1EE)),
  black('black', 'Black', Color(0xFF1F1A17), Color(0xFFF3EBE2)),
  orange('orange', 'Orange', Color(0xFFB4501C), Color(0xFFFFEBD9));

  const TagColour(this.value, this.label, this.colour, this.ring);
  final String value;
  final String label;
  final Color colour;
  final Color ring;

  static TagColour fromValue(String? v) => values.firstWhere(
    (c) => c.value == v,
    orElse: () => TagColour.teal,
  );
}

/// What a tag and its delivery cost. Set by the team in settings, never in the app.
class TagPrices {
  const TagPrices({required this.priceKobo, required this.deliveryKobo});
  final int priceKobo;
  final int deliveryKobo;
  int get totalKobo => priceKobo + deliveryKobo;
}

enum TagOrderStatus {
  pendingPayment('pending_payment', 'Waiting for payment'),
  paid('paid', 'Paid, getting ready to ship'),
  shipped('shipped', 'On its way'),
  delivered('delivered', 'Delivered'),
  cancelled('cancelled', 'Cancelled');

  const TagOrderStatus(this.value, this.label);
  final String value;
  final String label;

  static TagOrderStatus fromValue(String? v) => values.firstWhere(
    (s) => s.value == v,
    orElse: () => TagOrderStatus.pendingPayment,
  );
}

class TagOrder {
  const TagOrder({
    required this.id,
    required this.petName,
    required this.colour,
    required this.status,
    required this.totalKobo,
    required this.createdAt,
    required this.reference,
  });

  final String id;
  final String petName;
  final TagColour colour;
  final TagOrderStatus status;
  final int totalKobo;
  final DateTime createdAt;
  final String reference;

  factory TagOrder.fromJson(Map<String, dynamic> j) => TagOrder(
    id: j['id'] as String,
    petName: j['pet_name'] as String,
    colour: TagColour.fromValue(j['colour'] as String?),
    status: TagOrderStatus.fromValue(j['status'] as String?),
    totalKobo: (j['total_kobo'] as num).toInt(),
    createdAt: DateTime.parse(j['created_at'] as String),
    reference: (j['reference'] as String?) ?? '',
  );
}

/// An order that was just placed and still has to be paid.
class TagIntent {
  const TagIntent({
    required this.orderId,
    required this.reference,
    required this.totalKobo,
  });
  final String orderId;
  final String reference;
  final int totalKobo;

  factory TagIntent.fromJson(Map<String, dynamic> j) => TagIntent(
    orderId: j['order_id'] as String,
    reference: j['reference'] as String,
    totalKobo: (j['total_kobo'] as num).toInt(),
  );
}

/// A passport the owner is sharing right now, with someone or through a link.
class ActiveShare {
  const ActiveShare({
    required this.id,
    required this.petId,
    required this.petName,
    required this.scopes,
    required this.expiresAt,
    this.withName,
  });

  final String id;
  final String petId;
  final String petName;

  /// The partner it was shared with, or null for a link anyone with it can open.
  final String? withName;
  final Set<ShareScope> scopes;
  final DateTime expiresAt;

  factory ActiveShare.fromJson(Map<String, dynamic> j) => ActiveShare(
    id: j['id'] as String,
    petId: j['pet_id'] as String,
    petName: j['pet_name'] as String,
    withName: j['with_name'] as String?,
    scopes: {
      for (final s in (j['scopes'] as List? ?? const []))
        ?ShareScope.fromValue(s as String),
    },
    expiresAt: DateTime.parse(j['expires_at'] as String),
  );
}

class BlockedAccount {
  const BlockedAccount({required this.id, required this.name});
  final String id;
  final String name;

  factory BlockedAccount.fromJson(Map<String, dynamic> j) =>
      BlockedAccount(id: j['id'] as String, name: j['name'] as String);
}
