import 'package:flutter/widgets.dart';

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
    required super.child,
  });

  final AppServices services;
  final SessionController session;
  final OnboardingController onboarding;
  final HealthController health;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope old) =>
      services != old.services ||
      session != old.session ||
      onboarding != old.onboarding ||
      health != old.health;
}
