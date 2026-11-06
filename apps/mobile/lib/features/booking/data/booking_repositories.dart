import '../../onboarding/domain/models.dart';
import '../domain/models.dart';

/// Browsing providers and managing bookings. The money rules live in the database; this only asks.
abstract class BookingsRepository {
  Future<List<ProviderSummary>> search({
    ServiceCategory? category,
    String? query,
    double? lat,
    double? lng,
  });

  Future<ProviderDetail> provider(String id, {double? lat, double? lng});

  Future<List<Slot>> slots(String providerId, {int days = 14});

  Future<List<ReviewItem>> reviews(String providerId);

  /// Makes (or reuses) an unpaid booking for this time. Throws [AppFailure] if the time was just taken.
  Future<BookingIntent> createBooking({
    required String serviceId,
    required String petId,
    required DateTime startsAt,
  });

  Future<List<Booking>> myBookings();

  Future<void> cancel(String bookingId, {String? reason});

  /// The visit happened: releases the payment, and saves the review if a rating is given.
  Future<void> confirmVisit(
    String bookingId, {
    int? rating,
    List<String> tags = const [],
    String? body,
  });

  /// Holds the payment and asks PawPass to decide. Returns the report's id.
  Future<String> openDispute({
    required String bookingId,
    required DisputeReason reason,
    String? details,
    List<PickedPhoto> evidence = const [],
  });
}

/// Paying through Paystack. Needs the server (secret key), so the app only starts and checks.
abstract class PaymentsRepository {
  /// Asks the payments function for a Paystack checkout page for this booking reference.
  Future<PaymentCheckout> start(String reference);

  /// Asks the payments function whether Paystack has the money yet.
  Future<PaymentOutcome> verify(String reference);
}
