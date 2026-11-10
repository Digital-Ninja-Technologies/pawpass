import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/analytics.dart';
import 'features/adopt/state/adopt_controller.dart';
import 'features/booking/state/booking_controller.dart';
import 'features/community/state/chat_controller.dart';
import 'features/community/state/community_controller.dart';
import 'features/community/state/lost_controller.dart';
import 'core/push.dart';
import 'features/health/domain/health_logic.dart' show notificationRoute;
import 'features/health/state/health_controller.dart';
import 'features/onboarding/data/repositories.dart';
import 'features/partner/state/partner_controller.dart';
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

class _PawPassAppState extends State<PawPassApp> with WidgetsBindingObserver {
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
  late final AdoptController _adopt = AdoptController(
    widget.services,
    _session,
  );
  late final PartnerController _partner = PartnerController(
    widget.services,
    _session,
  );
  late final GoRouter _router = buildRouter(
    session: _session,
    onboarding: _onboarding,
  );

  StreamSubscription<PushTap>? _tapSub;
  StreamSubscription<void>? _foregroundSub;

  /// A notification that was tapped before the person was signed in and set up: opened once they are.
  String? _pendingLink;
  var _pushStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(_onSession);
    final push = widget.services.push;
    _tapSub = push.taps.listen((tap) => _openLink(tap.link));
    _foregroundSub = push.foreground.listen((_) {
      if (_session.signedIn) _health.refreshNotifications();
    });
    push.launchTap().then((tap) {
      if (tap?.link != null) _openLink(tap!.link);
    });
  }

  void _onSession() {
    if (_session.signedIn && _session.onboarded) {
      if (!_pushStarted) {
        _pushStarted = true;
        widget.services.push.signedIn();
      }
      final link = _pendingLink;
      if (link != null) {
        _pendingLink = null;
        _openLink(link);
      }
    } else if (_session.status == SessionStatus.signedOut) {
      _pushStarted = false;
      _pendingLink = null;
    }
  }

  /// Where a tapped notification goes (the same places as tapping it in the Notifications list).
  void _openLink(String? link) {
    if (!(_session.signedIn && _session.onboarded)) {
      _pendingLink = link;
      return;
    }
    final target = notificationRoute(link);
    if (target == null) return;
    if (target.root) {
      _router.go(target.route);
    } else {
      _router.push(target.route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app counts as using it (the database counts a person once per 30 minutes).
    if (state == AppLifecycleState.resumed && _session.signedIn) {
      widget.services.analytics.track(AppEvent.appOpen);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_onSession);
    _tapSub?.cancel();
    _foregroundSub?.cancel();
    widget.services.push.dispose();
    _router.dispose();
    _partner.dispose();
    _adopt.dispose();
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
      adopt: _adopt,
      partner: _partner,
      child: MaterialApp.router(
        title: 'OurPawPass',
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
              'OurPawPass is not set up yet. Please update the app or try again later.',
              textAlign: TextAlign.center,
              style: PawText.body15,
            ),
          ),
        ),
      ),
    );
  }
}
