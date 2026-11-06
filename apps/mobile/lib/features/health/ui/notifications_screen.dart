import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../onboarding/state/app_scope.dart';
import '../../onboarding/ui/onboarding_page.dart';
import '../domain/health_logic.dart';
import '../domain/models.dart';
import 'health_widgets.dart';

/// Notifications (design/screens/Notifications.dc.html).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppScope.of(context).health.refreshNotifications(),
    );
  }

  /// Marks it read, then opens whatever it points at (if this version of the app knows where).
  void _open(BuildContext context, AppNotification n) {
    final health = AppScope.of(context).health;
    health.markNotificationRead(n.id);
    final target = notificationRoute(n.link);
    if (target == null) {
      return;
    }
    if (target.root) {
      context.go(target.route);
    } else {
      context.push(target.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).health;
    return ListenableBuilder(
      listenable: h,
      builder: (context, _) {
        final groups = groupNotifications(h.notifications, h.now);
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: h.refreshNotifications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.screenSide,
                  12,
                  PawSpace.screenSide,
                  32,
                ),
                children: [
                  Row(
                    children: [
                      const PawBackButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Notifications',
                            style: PawText.heading22,
                          ),
                        ),
                      ),
                      if (h.unread > 0)
                        TextLinkButton(
                          label: 'Mark all read',
                          alignment: Alignment.centerRight,
                          onPressed: h.markAllRead,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!h.loaded)
                    FirstLoad(error: h.error, onRetry: h.load)
                  else if (groups.isEmpty)
                    const InfoCard(
                      title: "You're all caught up",
                      body: 'Reminders, verified records and nearby lost pet alerts will show up here.',
                      icon: PawIconData.bell,
                    )
                  else ...[
                    if (groups.today.isNotEmpty) ...[
                      const SectionLabel('Today'),
                      const SizedBox(height: 10),
                      for (final n in groups.today)
                        _Item(n: n, now: h.now, onTap: () => _open(context, n)),
                    ],
                    if (groups.earlier.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      const SectionLabel('Earlier'),
                      const SizedBox(height: 10),
                      for (final n in groups.earlier)
                        _Item(n: n, now: h.now, onTap: () => _open(context, n)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.n, required this.now, required this.onTap});
  final AppNotification n;
  final DateTime now;
  final VoidCallback onTap;

  (PawIconData, Color, Color) get _look => switch (n.kind) {
    NotificationKind.reminderDue => (
      PawIconData.calendar,
      PawColors.primarySoft,
      PawColors.primaryText,
    ),
    NotificationKind.recordVerified => (
      PawIconData.shieldCheck,
      PawColors.primarySoft,
      PawColors.primaryText,
    ),
    NotificationKind.lostAlert => (
      PawIconData.alertTriangle,
      PawColors.warmSoft,
      PawColors.warmText,
    ),
    NotificationKind.booking => (
      PawIconData.scissors,
      const Color(0xFFF1E8FB),
      const Color(0xFF5A2E8C),
    ),
    NotificationKind.community => (
      PawIconData.community,
      const Color(0xFFDCE7F7),
      const Color(0xFF23407A),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _look;
    final when = relativeTime(n.createdAt, now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PawCard(
        radius: PawRadius.cardSmall,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        semanticLabel:
            '${n.read ? '' : 'Unread. '}${n.title}. ${n.body ?? ''} $when',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Center(child: PawIcon(icon, size: 20, color: fg)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: PawText.body14Strong),
                  if ((n.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.body!,
                      style: PawText.meta13.copyWith(color: PawColors.ink2),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    when,
                    style: PawText.meta12.copyWith(color: PawColors.muted),
                  ),
                ],
              ),
            ),
            if (!n.read)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: PawColors.dot,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 8, height: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
