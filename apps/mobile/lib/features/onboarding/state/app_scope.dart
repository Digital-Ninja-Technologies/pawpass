import 'package:flutter/widgets.dart';

import '../../adopt/state/adopt_controller.dart';
import '../../booking/state/booking_controller.dart';
import '../../community/state/chat_controller.dart';
import '../../community/state/community_controller.dart';
import '../../community/state/lost_controller.dart';
import '../../health/state/health_controller.dart';
import '../data/repositories.dart';
import 'onboarding_controller.dart';
import 'session_controller.dart';

/// Hands the services and the two controllers to every screen below it.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.services,
    required this.session,
    required this.onboarding,
    required this.health,
    required this.booking,
    required this.community,
    required this.lost,
    required this.chat,
    required this.adopt,
    required super.child,
  });

  final AppServices services;
  final SessionController session;
  final OnboardingController onboarding;
  final HealthController health;
  final BookingController booking;
  final CommunityController community;
  final LostController lost;
  final ChatController chat;
  final AdoptController adopt;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!;
  }

  static AppScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>();

  @override
  bool updateShouldNotify(AppScope old) =>
      services != old.services ||
      session != old.session ||
      onboarding != old.onboarding ||
      health != old.health ||
      booking != old.booking ||
      community != old.community ||
      lost != old.lost ||
      chat != old.chat ||
      adopt != old.adopt;
}
