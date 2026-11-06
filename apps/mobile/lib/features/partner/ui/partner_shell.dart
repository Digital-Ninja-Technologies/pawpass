import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../community/ui/chat_screen.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/models.dart';
import 'dashboard_screens.dart';
import 'earnings_help_screens.dart';
import 'partner_widgets.dart';
import 'verify_screens.dart';

/// The partner frame: the partner tab bar under the current tab. Only an approved partner gets in.
class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final router = GoRouter.of(context);
        await p.refresh();
        if (!mounted) {
          return;
        }
        if (!p.isApprovedPartner && p.applicationLoaded) {
          p.leavePartnerMode();
          router.go('/me');
        } else {
          p.enterPartnerMode();
        }
      });
    }
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final a = p.application;
        if (a == null || !a.approved) {
          return Scaffold(
            backgroundColor: PawColors.ground,
            body: SafeArea(
              child: p.applicationError != null
                  ? LoadError(message: p.applicationError!, onRetry: p.refresh)
                  : const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: widget.shell,
          bottomNavigationBar: PartnerTabBar(
            type: a.type,
            index: widget.shell.currentIndex,
            onSelected: (i) => widget.shell.goBranch(
              i,
              initialLocation: i == widget.shell.currentIndex,
            ),
          ),
        );
      },
    );
  }
}

/// The second tab: Calendar for vets and service providers, Listings or Pets for breeders and shelters.
class PartnerSecondTab extends StatelessWidget {
  const PartnerSecondTab({super.key});

  @override
  Widget build(BuildContext context) {
    final type = AppScope.of(context).partner.type;
    return (type?.takesBookings ?? true)
        ? const CalendarTab()
        : const ListingsTab();
  }
}

/// The messages tab: the same inbox owners have.
class PartnerMessagesTab extends StatelessWidget {
  const PartnerMessagesTab({super.key});

  @override
  Widget build(BuildContext context) => const MessagesScreen(embedded: true);
}

/// The fourth tab: Applications for shelters, Earnings for everyone else.
class PartnerFourthTab extends StatelessWidget {
  const PartnerFourthTab({super.key});

  @override
  Widget build(BuildContext context) {
    final type = AppScope.of(context).partner.type;
    return type == PartnerType.shelter
        ? const ApplicationsTab()
        : const EarningsTab();
  }
}

/// The fifth tab: the verification state, for a partner who is live.
class PartnerBusinessTab extends StatelessWidget {
  const PartnerBusinessTab({super.key});

  @override
  Widget build(BuildContext context) => const KycScreen(embedded: true);
}
