import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../../partner/domain/models.dart' show SupportTopic;
import '../domain/account_logic.dart';
import '../domain/models.dart';
import '../state/privacy_controller.dart';

/// Privacy and sharing (design/screens/PrivacySharing.dc.html).
///
/// Shows what is shared right now (and lets the owner stop it), blocked accounts, and the two data requests.
/// Health records are private by default; nothing here can make them public.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  PrivacyController? _c;

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _ask({
    required String message,
    required String sent,
    String? confirmTitle,
    String? confirmBody,
    String confirmLabel = 'Send request',
  }) async {
    if (confirmTitle != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(confirmTitle, style: PawText.heading22),
          content: Text(confirmBody ?? '', style: PawText.body14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                confirmLabel,
                style: const TextStyle(color: PawColors.danger),
              ),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) {
        return;
      }
    }
    final partner = AppScope.of(context).partner;
    final done = await partner.sendTicket(SupportTopic.account, message);
    if (!mounted) {
      return;
    }
    _say(
      done
          ? sent
          : (partner.ticketError ?? 'We could not send that. Please try again.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    var c = _c;
    if (c == null) {
      final made = c = _c = PrivacyController(scope.services);
      WidgetsBinding.instance.addPostFrameCallback((_) => made.load());
    }
    final ctl = c;
    return ListenableBuilder(
      listenable: ctl,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: ctl.loading && !ctl.loaded
                ? const Center(child: CircularProgressIndicator())
                : !ctl.loaded && ctl.loadError != null
                ? Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(PawSpace.screenSide),
                        child: BookingHeader('Privacy & sharing'),
                      ),
                      Expanded(
                        child: PawErrorState(
                          title: 'We could not load this',
                          message: ctl.loadError!,
                          onAction: ctl.load,
                        ),
                      ),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: ctl.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        PawSpace.screenSide,
                        12,
                        PawSpace.screenSide,
                        32,
                      ),
                      children: [
                        const BookingHeader('Privacy & sharing'),
                        const SizedBox(height: 14),
                        _Banner(),
                        const SizedBox(height: 18),
                        const SectionLabel('Shared right now'),
                        const SizedBox(height: 8),
                        _Shares(
                          c: ctl,
                          now: scope.services.now(),
                          onStopped: () => _say(
                            'Sharing stopped. The link no longer works.',
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => context.push('/share'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(
                                PawSize.touch,
                                PawSize.touch,
                              ),
                            ),
                            child: Text(
                              'Share records with a vet',
                              style: PawText.body14Strong.copyWith(
                                color: PawColors.primaryText,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const SectionLabel('Blocked accounts'),
                        const SizedBox(height: 8),
                        _Blocked(c: ctl),
                        if (ctl.actionError != null) ...[
                          const SizedBox(height: 8),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              ctl.actionError!,
                              style: PawText.body14.copyWith(
                                color: PawColors.danger,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        const SectionLabel('Your data'),
                        const SizedBox(height: 8),
                        PawCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Column(
                            children: [
                              PawListRow(
                                title: 'Ask for a copy of my data',
                                onTap: () => _ask(
                                  message:
                                      'Please send me a copy of the data OurPawPass holds about me.',
                                  sent:
                                      'Request sent. We will reply by email within a day.',
                                ),
                              ),
                              PawListRow(
                                title: 'Delete my account',
                                destructive: true,
                                showDivider: false,
                                onTap: () => context.push('/delete-account'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Deleting removes your details at once. We keep payment records we must keep by law, without your name.',
                          style: PawText.meta12.copyWith(
                            color: PawColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PawColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const PawIcon(
            PawIconData.shieldCheck,
            size: 18,
            color: PawColors.primaryText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Your pets' health records are private. Only you see them unless you share.",
              style: PawText.body14Strong.copyWith(
                color: PawColors.primaryText,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shares extends StatelessWidget {
  const _Shares({required this.c, required this.now, required this.onStopped});
  final PrivacyController c;
  final DateTime now;
  final VoidCallback onStopped;

  @override
  Widget build(BuildContext context) {
    if (c.shares.isEmpty) {
      return PawCard(
        child: Text(
          'You are not sharing anything. When you share a passport with a vet, it shows here until it ends.',
          style: PawText.body14.copyWith(color: PawColors.muted),
        ),
      );
    }
    return PawCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (final s in c.shares)
            _ShareRow(
              share: s,
              now: now,
              last: s == c.shares.last,
              busy: c.isBusy(s.id),
              onStop: () async {
                final ok = await c.stopSharing(s.id);
                if (ok) {
                  onStopped();
                }
              },
            ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.share,
    required this.now,
    required this.last,
    required this.busy,
    required this.onStop,
  });
  final ActiveShare share;
  final DateTime now;
  final bool last;
  final bool busy;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final who = share.withName ?? 'Link or QR code';
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: PawColors.subtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(who, style: PawText.body14Strong),
                const SizedBox(height: 2),
                Text(
                  '${shareScopeSummary(share)} · ${shareEndsLabel(share.expiresAt, now)}',
                  style: PawText.meta12.copyWith(color: PawColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PawButton(
            label: 'Stop sharing',
            variant: PawButtonVariant.secondary,
            expand: false,
            height: 44,
            loading: busy,
            onPressed: onStop,
          ),
        ],
      ),
    );
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked({required this.c});
  final PrivacyController c;

  @override
  Widget build(BuildContext context) {
    if (c.blocked.isEmpty) {
      return PawCard(
        child: Text(
          'You have not blocked anyone. You can block someone from a profile or a message.',
          style: PawText.body14.copyWith(color: PawColors.muted),
        ),
      );
    }
    return PawCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (final b in c.blocked)
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                border: b == c.blocked.last
                    ? null
                    : const Border(bottom: BorderSide(color: PawColors.subtle)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(b.name, style: PawText.body15Strong)),
                  PawButton(
                    label: 'Unblock',
                    variant: PawButtonVariant.secondary,
                    expand: false,
                    height: 44,
                    loading: c.isBusy(b.id),
                    onPressed: () => c.unblock(b.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
