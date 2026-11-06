import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'account_repository.dart';

AppFailure _failure(Object e, String fallback) {
  if (e is AppFailure) {
    return e;
  }
  if (e is SocketException || e is HttpException) {
    return const AppFailure(
      'No connection. Check your internet and try again.',
    );
  }
  if (e is PostgrestException) {
    if (e.code == 'P0001' || e.code == '22023') {
      return AppFailure(e.message);
    }
    if (e.code == 'P0002' || e.code == '42501') {
      return const AppFailure(
        'We could not find that. It may have been removed.',
      );
    }
  }
  return AppFailure(fallback);
}

List<Map<String, dynamic>> _rows(Object? v) => [
  if (v is List)
    for (final e in v)
      if (e is Map) Map<String, dynamic>.from(e),
];

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<TagPrices> tagPrices() async {
    try {
      final r = Map<String, dynamic>.from(
        await _client.rpc('tag_prices') as Map,
      );
      return TagPrices(
        priceKobo: (r['price_kobo'] as num).toInt(),
        deliveryKobo: (r['delivery_kobo'] as num).toInt(),
      );
    } catch (e) {
      throw _failure(e, 'We could not load the price. Please try again.');
    }
  }

  @override
  Future<TagIntent> createTagOrder({
    required String petId,
    required TagColour colour,
    required String address,
    required String area,
  }) async {
    try {
      final r = await _client.rpc(
        'create_tag_order',
        params: {
          'p_pet': petId,
          'p_colour': colour.value,
          'p_address': address.trim(),
          'p_area': area.trim(),
        },
      );
      return TagIntent.fromJson(Map<String, dynamic>.from(r as Map));
    } catch (e) {
      throw _failure(e, 'We could not place the order. Please try again.');
    }
  }

  @override
  Future<List<TagOrder>> myTagOrders() async {
    try {
      final r = await _client.rpc('my_tag_orders');
      return [for (final j in _rows(r)) TagOrder.fromJson(j)];
    } catch (e) {
      throw _failure(e, 'We could not load your tag orders.');
    }
  }

  @override
  Future<List<ActiveShare>> activeShares() async {
    try {
      final r = await _client.rpc('my_active_shares');
      return [for (final j in _rows(r)) ActiveShare.fromJson(j)];
    } catch (e) {
      throw _failure(e, 'We could not load what you are sharing.');
    }
  }

  @override
  Future<List<BlockedAccount>> blocks() async {
    try {
      final r = await _client.rpc('my_blocks');
      return [for (final j in _rows(r)) BlockedAccount.fromJson(j)];
    } catch (e) {
      throw _failure(e, 'We could not load your blocked accounts.');
    }
  }

  @override
  Future<void> unblock(String blockId) async {
    try {
      await _client.rpc('unblock', params: {'p_block': blockId});
    } catch (e) {
      throw _failure(e, 'We could not unblock that account. Try again.');
    }
  }
}
