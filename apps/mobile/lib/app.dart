import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/booking/state/booking_controller.dart';
import 'features/community/state/chat_controller.dart';
import 'features/community/state/community_controller.dart';
import 'features/community/state/lost_controller.dart';
import 'features/health/state/health_controller.dart';
import 'features/onboarding/data/repositories.dart';
import 'features/onboarding/state/app_scope.dart';
import 'features/onboarding/state/onboarding_controller.dart';
import 'features/onboarding/state/session_controller.dart';
import 'router.dart';
import 'ui/ui.dart';

class PawPassApp extends StatefulWidget {
  const PawPassApp({super.key, required this.services, this.demo = false});

  final AppServices services;

  /// True in the debug build with no Supabase project: shows a "DEMO" corner so it is never mistaken
  /// for the real thing.
  final bool demo;

  @override
  State<PawPassApp> createState() => _PawPassAppState();
}

class _PawPassAppState extends State<PawPassApp> {
  late final SessionController _session = SessionController(widget.services);
  late final OnboardingController _onboarding = OnboardingController(
    widget.services,
    _session,
  );
  late final HealthController _health = HealthController(
    widget.services,
    _session,
  );
  late final BookingController _booking = BookingController(
    widget.services,
    _session,
  );
  late final CommunityController _community = CommunityController(
    widget.services,
    _session,
  );
  late final LostController _lost = LostController(widget.services, _session);
  late final ChatController _chat = ChatController(widget.services, _session);
  late final GoRouter _router = buildRouter(
    session: _session,
    onboarding: _onboarding,
  );

  @override
  void dispose() {
    _router.dispose();
    _chat.dispose();
    _lost.dispose();
    _community.dispose();
    _booking.dispose();
    _health.dispose();
    _onboarding.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      session: _session,
      onboarding: _onboarding,
      health: _health,
      booking: _booking,
      community: _community,
      lost: _lost,
      chat: _chat,
      child: MaterialApp.router(
        title: 'PawPass',
        theme: buildAppTheme(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => widget.demo
            ? Banner(
                message: 'DEMO',
                location: BannerLocation.topEnd,
                color: PawColors.warm,
                child: child ?? const SizedBox.shrink(),
              )
            : child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Shown when a release build has no Supabase project configured (a build mistake, not a user one).
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'PawPass is not set up yet. Please update the app or try again later.',
              textAlign: TextAlign.center,
              style: PawText.body15,
            ),
          ),
        ),
      ),
    );
  }
}
