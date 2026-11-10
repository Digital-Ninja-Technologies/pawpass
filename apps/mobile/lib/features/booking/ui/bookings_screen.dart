import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/booking_logic.dart';
import '../domain/models.dart';
import '../state/booking_controller.dart';

/// My bookings (design/screens/Bookings.dc.html): upcoming, anything needing a confirmation, and past.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  var _past = false;
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).booking;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => c.loadBookings());
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final needs = c.needsAction;
        final upcoming = c.upcoming;
        final past = c.past;
        final shownUpcoming = [...needs, ...upcoming];
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: c.loadBookings,
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
                          child: Text('My bookings', style: PawText.heading22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PawSegmented<bool>(
                    segments: [
                      PawSegment(false, 'Upcoming (${shownUpcoming.length})'),
                      const PawSegment(true, 'Past'),
                    ],
                    value: _past,
                    onChanged: (v) => setState(() => _past = v),
                  ),
                  const SizedBox(height: 16),
                  if (c.actionError != null) _ErrorNote(c),
                  if (c.loadingBookings && !c.bookingsLoaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (c.bookingsError != null && !c.bookingsLoaded)
                    LoadError(
                      message: c.bookingsError!,
                      onRetry: c.loadBookings,
                    )
                  else if (!_past) ...[
                    if (shownUpcoming.isEmpty)
                      InfoCard(
                        title: 'Nothing booked',
                        body: 'Book a vet, groomer, trainer or boarding and it will show up here.',
                        icon: PawIconData.calendar,
                      ),
                    for (final b in needs)
                      _BookingCard(booking: b, controller: c),
                    for (final b in upcoming)
                      _BookingCard(booking: b, controller: c),
                  ] else ...[
                    if (past.isEmpty)
                      const InfoCard(
                        title: 'No past bookings',
                        body: 'Visits you have finished or cancelled show up here.',
                        icon: PawIconData.clock,
                      ),
                    for (final b in past)
                      _BookingCard(booking: b, controller: c),
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

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.c);
  final BookingController c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PawColors.dangerSoft,
            borderRadius: BorderRadius.circular(PawRadius.cardSmall),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  c.actionError!,
                  style: PawText.body14.copyWith(color: PawColors.danger),
                ),
              ),
              GestureDetector(
                onTap: c.clearActionError,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: PawIcon(
                    PawIconData.close,
                    size: 18,
                    color: PawColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.controller});
  final Booking booking;
  final BookingController controller;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final c = controller;
    final now = c.now;
    final group = groupOf(b, now);
    final busy = c.busyId == b.id;
    final l = lagos(b.startsAt);
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final title = '${b.serviceName} for ${b.petName}';
    final showReport = canReport(b, now) && group != BookingGroup.needsAction;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PawCard(
        radius: PawRadius.cardSmall,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group == BookingGroup.needsAction) ...[
              const PawBadge('Needs your action', tone: PawBadgeTone.upcoming),
              const SizedBox(height: 10),
            ] else if (b.status == BookingStatus.disputed) ...[
              const PawBadge('Under review', tone: PawBadgeTone.upcoming),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: PawColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          weekdays[l.weekday - 1],
                          style: PawText.meta12.copyWith(
                            color: PawColors.primaryText,
                          ),
                        ),
                        Text(
                          '${l.day}',
                          style: PawText.heading22.copyWith(
                            color: PawColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: PawText.body15Strong),
                      Text(
                        '${b.partnerName} · ${group == BookingGroup.upcoming ? timeLabel(b.startsAt) : dayLabel(b.startsAt)}',
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        escrowLine(b, now),
                        style: PawText.meta13.copyWith(color: PawColors.ink2),
                      ),
                      if (b.status == BookingStatus.disputed &&
                          b.disputeDueAt != null)
                        Text(
                          'OurPawPass decides by ${dayLabel(b.disputeDueAt!)}',
                          style: PawText.meta13.copyWith(
                            color: PawColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (group == BookingGroup.needsAction ||
                canCancel(b, now) ||
                showReport ||
                b.status == BookingStatus.completed ||
                b.status == BookingStatus.cancelled) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (canConfirm(b, now))
                    PawButton(
                      label: 'Confirm visit & rate',
                      expand: false,
                      onPressed: () => context.push('/review/${b.id}'),
                    ),
                  if (canCancel(b, now))
                    PawButton(
                      label: 'Cancel',
                      expand: false,
                      variant: PawButtonVariant.secondary,
                      loading: busy,
                      onPressed: busy ? null : () => _confirmCancel(context, b),
                    ),
                  if (showReport)
                    PawButton(
                      label: 'Report a problem',
                      expand: false,
                      variant: PawButtonVariant.secondary,
                      onPressed: () => context.push('/dispute/${b.id}'),
                    ),
                  if (b.status == BookingStatus.completed ||
                      b.status == BookingStatus.cancelled)
                    PawButton(
                      label: 'Book again',
                      expand: false,
                      variant: PawButtonVariant.secondary,
                      onPressed: () => context.push('/provider/${b.partnerId}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, Booking b) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          '${b.serviceName} on ${whenLabel(b.startsAt)} will be cancelled and ${nairaFromKobo(b.amountKobo)} goes back to you in full.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (yes == true) await controller.cancel(b.id);
  }
}
