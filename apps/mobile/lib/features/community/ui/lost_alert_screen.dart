import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/domain/booking_logic.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/community_logic.dart';
import '../domain/models.dart';
import '../state/lost_controller.dart';
import 'community_widgets.dart';

/// Lost pet alert (design/screens/LostAlert.dc.html): what finders see, and what the owner manages.
class LostAlertScreen extends StatefulWidget {
  const LostAlertScreen({super.key, required this.alertId});
  final String alertId;

  @override
  State<LostAlertScreen> createState() => _LostAlertScreenState();
}

class _LostAlertScreenState extends State<LostAlertScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lost = scope.lost;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => lost.loadDetail(widget.alertId),
      );
    }
    return ListenableBuilder(
      listenable: lost,
      builder: (context, _) {
        final d = lost.detail;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: lost.loadingDetail && d == null
                ? const Center(child: CircularProgressIndicator())
                : d == null
                ? Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(PawSpace.screenSide),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PawBackButton(),
                        ),
                      ),
                      Expanded(
                        child: LoadError(
                          message:
                              lost.detailError ??
                              'We could not load this alert.',
                          onRetry: () => lost.loadDetail(widget.alertId),
                        ),
                      ),
                    ],
                  )
                : _body(context, scope, lost, d),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppScope scope,
    LostController lost,
    LostAlertDetail d,
  ) {
    final s = d.summary;
    final now = lost.now;
    final mine = s.isMine;
    final active = d.active;
    final name = s.petName;
    final sightings = d.sightings;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              PawSpace.screenSide,
              12,
              PawSpace.screenSide,
              24,
            ),
            children: [
              const BookingHeader('Lost pet alert'),
              const SizedBox(height: 18),
              if (active)
                PawBadge(
                  lostHeadline(s.lastSeenAt, now),
                  tone: PawBadgeTone.lost,
                )
              else
                PawBadge(
                  d.status == 'found' ? 'FOUND' : 'CLOSED',
                  tone: PawBadgeTone.verified,
                ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PetMark(
                    name: name,
                    path: s.photoPath,
                    size: 72,
                    square: true,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            mine ? '$name is missing' : 'Have you seen $name?',
                            style: PawText.title28,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            petKind(s.breed, s.species),
                            if (s.colour != null) s.colour,
                          ].join(' · '),
                          style: PawText.meta13.copyWith(
                            color: PawColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionLabel('Last seen'),
              const SizedBox(height: 6),
              if (s.address != null)
                Text(s.address!, style: PawText.body15Strong),
              Text(
                [
                  whenLabel(s.lastSeenAt),
                  if (s.distanceM != null)
                    '${distanceLabel(s.distanceM)} from you',
                ].join(' · '),
                style: PawText.meta13.copyWith(color: PawColors.muted),
              ),
              if (s.description != null) ...[
                const SizedBox(height: 16),
                PawCard(
                  radius: PawRadius.cardSmall,
                  child: Text(
                    '"${s.description}"',
                    style: PawText.body15.copyWith(
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SectionLabel('Sightings (${d.sightingCount})'),
              const SizedBox(height: 10),
              if (sightings.isEmpty)
                Text(
                  mine
                      ? 'Nobody has shared a sighting yet.'
                      : (d.sightingCount > 0
                            ? 'Others have shared sightings with the owner.'
                            : 'No sightings yet.'),
                  style: PawText.meta13.copyWith(color: PawColors.muted),
                )
              else
                for (final x in sightings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PawCard(
                      radius: PawRadius.cardSmall,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (x.note) ??
                                      (x.mine
                                          ? 'You shared a sighting'
                                          : 'A sighting was shared'),
                                  style: PawText.body14Strong,
                                ),
                                Text(
                                  timeAgoLong(x.seenAt, now),
                                  style: PawText.meta13.copyWith(
                                    color: PawColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (x.lat != null)
                            TextButton(
                              onPressed: () => scope.services.links.open(
                                mapsUri(x.lat!, x.lng!),
                              ),
                              child: const Text('Map'),
                            ),
                        ],
                      ),
                    ),
                  ),
              if (lost.notice != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    lost.notice!,
                    style: PawText.body14.copyWith(
                      color: PawColors.primaryText,
                    ),
                  ),
                ),
              ],
              if (lost.actionError != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    lost.actionError!,
                    style: PawText.body14.copyWith(color: PawColors.danger),
                  ),
                ),
              ],
              if (!mine) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      context.push('/report/lost_alert/${s.alertId}'),
                  child: const Text('Report this alert'),
                ),
              ],
            ],
          ),
        ),
        if (active)
          PawStickyFooter(
            children: mine
                ? [
                    PawButton(
                      label: 'Messages',
                      onPressed: () => context.push('/messages'),
                    ),
                    PawButton(
                      label: 'Mark $name as found',
                      variant: PawButtonVariant.secondary,
                      loading: lost.busy,
                      onPressed: (lost.busy)
                          ? null
                          : () => _close(context, lost, found: true),
                    ),
                    PawButton(
                      label: 'Close this alert',
                      variant: PawButtonVariant.secondary,
                      onPressed: (lost.busy)
                          ? null
                          : () => _close(context, lost, found: false),
                    ),
                  ]
                : [
                    PawButton(
                      label: "I've seen $name · share location",
                      variant: PawButtonVariant.warm,
                      loading: lost.busy,
                      onPressed: (lost.busy)
                          ? null
                          : () => lost.shareSighting(s.alertId),
                    ),
                    PawButton(
                      label: 'Message owner',
                      variant: PawButtonVariant.secondary,
                      onPressed: (lost.busy)
                          ? null
                          : () async {
                              final id = await lost.openChat(s.alertId);
                              if (id != null && context.mounted) {
                                context.push('/chat/$id');
                              }
                            },
                    ),
                  ],
          ),
      ],
    );
  }

  Future<void> _close(
    BuildContext context,
    LostController lost, {
    required bool found,
  }) async {
    final ok = await lost.close(widget.alertId, found: found);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              found
                  ? 'So glad you found them. The alert is closed.'
                  : 'The alert is closed.',
            ),
          ),
        );
      context.pop();
    }
  }
}
