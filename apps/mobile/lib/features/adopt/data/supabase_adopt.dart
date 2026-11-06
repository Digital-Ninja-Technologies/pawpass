import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'adopt_repository.dart';

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

class SupabaseAdoptRepository implements AdoptRepository {
  SupabaseAdoptRepository(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> _rows(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    final res = await _client.rpc(fn, params: params) as List;
    return [for (final r in res) Map<String, dynamic>.from(r as Map)];
  }

  Future<Map<String, dynamic>> _json(
    String fn,
    Map<String, dynamic> params,
  ) async =>
      Map<String, dynamic>.from(await _client.rpc(fn, params: params) as Map);

  @override
  Future<List<AdoptListing>> listings({
    ListingKind? kind,
    String? species,
    String? query,
  }) async {
    try {
      final rows = await _rows('adopt_listings', {
        'p_kind': kind?.value,
        'p_species': species,
        'p_query': (query ?? '').trim().isEmpty ? null : query!.trim(),
      });
      return [for (final r in rows) AdoptListing.fromRow(r)];
    } catch (e) {
      throw _failure(e, 'We could not load pets.');
    }
  }

  @override
  Future<ListingDetail> listing(String listingId) async {
    try {
      return ListingDetail.fromJson(
        await _json('listing_detail', {'p_listing': listingId}),
      );
    } catch (e) {
      throw _failure(e, 'We could not load this listing.');
    }
  }

  @override
  Future<OrderPayment> createOrder(String listingId) async {
    try {
      return OrderPayment.fromJson(
        await _json('create_puppy_order', {'p_listing': listingId}),
      );
    } catch (e) {
      throw _failure(e, 'We could not start your order. Please try again.');
    }
  }

  @override
  Future<void> cancelUnpaidOrder(String orderId) async {
    try {
      await _client.rpc('cancel_unpaid_order', params: {'p_order': orderId});
    } catch (e) {
      throw _failure(e, 'We could not cancel this order.');
    }
  }

  @override
  Future<OrderPayment> balancePayment(String orderId) async {
    try {
      return OrderPayment.fromJson(
        await _json('create_balance_payment', {'p_order': orderId}),
      );
    } catch (e) {
      throw _failure(e, 'We could not start the payment. Please try again.');
    }
  }

  @override
  Future<List<OrderSummary>> orders() async {
    try {
      return [
        for (final r in await _rows('my_orders')) OrderSummary.fromRow(r),
      ];
    } catch (e) {
      throw _failure(e, 'We could not load your orders.');
    }
  }

  @override
  Future<OrderDetail> order(String orderId) async {
    try {
      return OrderDetail.fromJson(
        await _json('puppy_order_detail', {'p_order': orderId}),
      );
    } catch (e) {
      throw _failure(e, 'We could not load this order.');
    }
  }

  @override
  Future<void> acceptPassport(String transferId) async {
    try {
      await _client.rpc('accept_passport', params: {'p_transfer': transferId});
    } catch (e) {
      throw _failure(e, 'We could not accept the passport. Please try again.');
    }
  }

  @override
  Future<void> reportProblem(
    String orderId,
    OrderProblem reason, {
    String? details,
  }) async {
    try {
      await _client.rpc(
        'open_order_dispute',
        params: {
          'p_order': orderId,
          'p_reason': reason.value,
          'p_details': details,
        },
      );
    } catch (e) {
      throw _failure(e, 'We could not send your report. Please try again.');
    }
  }

  @override
  Future<String> openListingChat(String listingId) async {
    try {
      return await _client.rpc(
        'open_listing_chat',
        params: {'p_listing': listingId},
      ) as String;
    } catch (e) {
      throw _failure(e, 'We could not open the chat. Please try again.');
    }
  }

  @override
  Future<String> apply(String listingId, AdoptionAnswers answers) async {
    try {
      return await _client.rpc(
        'apply_to_adopt',
        params: {'p_listing': listingId, 'p_answers': answers.toJson()},
      ) as String;
    } catch (e) {
      throw _failure(
        e,
        'We could not send your application. Please try again.',
      );
    }
  }

  @override
  Future<List<ApplicationSummary>> applications() async {
    try {
      return [
        for (final r in await _rows('my_applications'))
          ApplicationSummary.fromRow(r),
      ];
    } catch (e) {
      throw _failure(e, 'We could not load your applications.');
    }
  }

  @override
  Future<TransferDetail> transfer(String transferId) async {
    try {
      return TransferDetail.fromJson(
        await _json('transfer_detail', {'p_transfer': transferId}),
      );
    } catch (e) {
      throw _failure(e, 'We could not load this transfer.');
    }
  }

  @override
  Future<String?> photoUrl(String path) async {
    try {
      return await _client.storage
          .from('pet-photos')
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }
}
