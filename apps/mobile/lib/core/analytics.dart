import 'package:supabase_flutter/supabase_flutter.dart';

/// The only things the app ever reports. No screen contents, no text a person typed, no location: just that one of
/// these happened, for the signed in person. The same list is enforced by the database.
enum AppEvent {
  appOpen('app_open'),
  bookingStarted('booking_started'),
  checkoutStarted('checkout_started'),
  shareStarted('share_started'),
  partnerStarted('partner_started'),
  helpOpened('help_opened');

  const AppEvent(this.value);
  final String value;
}

abstract class Analytics {
  /// Never throws and never waits: reporting must not slow down or break a screen.
  void track(AppEvent event);
}

class NoAnalytics implements Analytics {
  const NoAnalytics();
  @override
  void track(AppEvent event) {}
}

/// Keeps the events in a list (for tests and the debug demo).
class RecordingAnalytics implements Analytics {
  final List<AppEvent> events = [];
  @override
  void track(AppEvent event) => events.add(event);
}

class SupabaseAnalytics implements Analytics {
  SupabaseAnalytics(this._client);
  final SupabaseClient _client;

  @override
  void track(AppEvent event) {
    if (_client.auth.currentUser == null) {
      return;
    }
    // Fire and forget. A lost event is fine; a slow or failing screen is not.
    _client
        .rpc('track_event', params: {'p_name': event.value})
        .then<void>((_) {}, onError: (Object _) {});
  }
}
