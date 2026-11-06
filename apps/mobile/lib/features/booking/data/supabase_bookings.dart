import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/domain/models.dart';
import '../domain/models.dart';
import 'booking_repositories.dart';

AppFailure _failure(Object e, String fallback) {
  if (e is AppFailure) return e;
  if (e is SocketException || e is HttpException) {
    return const AppFailure(
      'No connection. Check your internet and try again.',
    );
  }
  if (e is PostgrestException) {
    // Our own checks (P0001 state rules, 22023 input rules) carry a message meant to be read.
    if (e.code == 'P0001' || e.code == '22023') return AppFailure(e.message);
    if (e.code == '42501') {
      return const AppFailure('That booking could not be found.');
    }
  }
  return AppFailure(fallback);
}

class SupabaseBookingsRepository implements BookingsRepository {
  SupabaseBookingsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<ProviderSummary>> search({
    ServiceCategory? category,
    String? query,
    double? lat,
    double? lng,
  }) async {
    try {
      final rows = await _client.rpc(
        'search_services',
        params: {
          'p_category': category?.value,
          'p_query': query?.trim().isEmpty ?? true ? null : query!.trim(),
          'p_lat': lat,
          'p_lng': lng,
        },
      ) as List;
      return [
        for (final r in rows)
          ProviderSummary.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e) {
      throw _failure(e, 'We could not load providers.');
    }
  }

  @override
  Future<ProviderDetail> provider(String id, {double? lat, double? lng}) async {
    try {
      final r = await _client.rpc(
        'provider_detail',
        params: {'p_partner': id, 'p_lat': lat, 'p_lng': lng},
      );
      return ProviderDetail.fromJson(Map<String, dynamic>.from(r as Map));
    } catch (e) {
      throw _failure(e, 'We could not load this provider.');
    }
  }

  @override
  Future<List<Slot>> slots(String providerId, {int days = 14}) async {
    try {
      final rows = await _client.rpc(
        'provider_slots',
        params: {'p_partner': providerId, 'p_days': days},
      ) as List;
      return [
        for (final r in rows) Slot.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e) {
      throw _failure(e, 'We could not load available times.');
    }
  }

  @override
  Future<List<ReviewItem>> reviews(String providerId) async {
    try {
      final rows = await _client.rpc(
        'provider_reviews',
        params: {'p_partner': providerId},
      ) as List;
      return [
        for (final r in rows)
          ReviewItem.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e) {
      throw _failure(e, 'We could not load reviews.');
    }
  }

  @override
  Future<BookingIntent> createBooking({
    required String serviceId,
    required String petId,
    required DateTime startsAt,
  }) async {
    try {
      final r = await _client.rpc(
        'create_booking',
        params: {
          'p_service': serviceId,
          'p_pet': petId,
          'p_starts_at': startsAt.toUtc().toIso8601String(),
        },
      );
      return BookingIntent.fromJson(Map<String, dynamic>.from(r as Map));
    } catch (e) {
      throw _failure(e, 'We could not start your booking. Please try again.');
    }
  }

  @override
  Future<List<Booking>> myBookings() async {
    try {
      final rows = await _client.rpc('my_bookings') as List;
      return [
        for (final r in rows)
          Booking.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (e) {
      throw _failure(e, 'We could not load your bookings.');
    }
  }

  @override
  Future<void> cancel(String bookingId, {String? reason}) async {
    try {
      await _client.rpc(
        'cancel_booking',
        params: {'p_booking': bookingId, 'p_reason': reason},
      );
    } catch (e) {
      throw _failure(e, 'We could not cancel this booking.');
    }
  }

  @override
  Future<void> confirmVisit(
    String bookingId, {
    int? rating,
    List<String> tags = const [],
    String? body,
  }) async {
    try {
      await _client.rpc(
        'confirm_visit',
        params: {
          'p_booking': bookingId,
          'p_rating': rating,
          'p_tags': tags,
          'p_body': body,
        },
      );
    } catch (e) {
      throw _failure(e, 'We could not confirm the visit. Please try again.');
    }
  }

  @override
  Future<String> openDispute({
    required String bookingId,
    required DisputeReason reason,
    String? details,
    List<PickedPhoto> evidence = const [],
  }) async {
    try {
      final uid = _client.auth.currentUser!.id;
      final paths = <String>[];
      for (final photo in evidence) {
        final path = '$uid/${_id()}.${photo.extension}';
        await _client.storage
            .from('dispute-evidence')
            .uploadBinary(path, photo.bytes);
        paths.add(path);
      }
      final id = await _client.rpc(
        'open_dispute',
        params: {
          'p_booking': bookingId,
          'p_reason': reason.value,
          'p_details': details,
          'p_evidence': paths,
        },
      );
      return id as String;
    } catch (e) {
      throw _failure(e, 'We could not send your report. Please try again.');
    }
  }

  String _id() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

/// Talks to the `paystack-initialize` and `paystack-verify` edge functions. The Paystack secret key
/// only ever exists in those functions.
class SupabasePaymentsRepository implements PaymentsRepository {
  SupabasePaymentsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<PaymentCheckout> start(String reference) async {
    try {
      final res = await _client.functions.invoke(
        'paystack-initialize',
        body: {'reference': reference},
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      return PaymentCheckout(
        url: Uri.parse(data['authorization_url'] as String),
        reference: reference,
      );
    } catch (e) {
      throw _failure(
        e,
        'We could not open the payment page. Please try again.',
      );
    }
  }

  @override
  Future<PaymentOutcome> verify(String reference) async {
    try {
      final res = await _client.functions.invoke(
        'paystack-verify',
        body: {'reference': reference},
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      return switch (data['status']) {
        'paid' => PaymentOutcome.paid,
        'failed' => PaymentOutcome.failed,
        _ => PaymentOutcome.pending,
      };
    } catch (e) {
      throw _failure(e, 'We could not check your payment. Please try again.');
    }
  }
}
