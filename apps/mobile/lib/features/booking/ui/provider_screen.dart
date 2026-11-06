import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/booking_logic.dart';
import '../domain/models.dart';
import '../state/booking_controller.dart';
import 'booking_widgets.dart';

/// Provider (design/screens/Provider.dc.html): pick a service, a day and a time, then pay into escrow.
class ProviderScreen extends StatefulWidget {
  const ProviderScreen({super.key, required this.providerId});
  final String providerId;

  @override
  State<ProviderScreen> createState() => _ProviderScreenState();
}

class _ProviderScreenState extends State<ProviderScreen>
    with WidgetsBindingObserver {
  var _started = false;
  DateTime? _day;
  BookingController? _c;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c?.removeListener(_maybeLeave);
    super.dispose();
  }

  /// Coming back from the Paystack page: check whether the money arrived.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _c?.stage == PayStage.waiting) {
      _c?.checkPayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = _c = scope.booking;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        c.choosePet(scope.health.selected?.id);
        c.addListener(_maybeLeave);
        c.openProvider(widget.providerId);
      });
    }
    return ListenableBuilder(
      listenable: Listenable.merge([c, scope.health]),
      builder: (context, _) {
        final d = c.detail;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            bottom: false,
            child: c.loadingDetail && d == null
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
                              c.detailError ??
                              'We could not load this provider.',
                          onRetry: () => c.openProvider(widget.providerId),
                        ),
                      ),
                    ],
                  )
                : _body(context, scope, c, d),
          ),
        );
      },
    );
  }

  void _maybeLeave() {
    final c = _c;
    if (c == null || !mounted) return;
    if (c.booked != null && c.stage == PayStage.idle) {
      c.removeListener(_maybeLeave);
      context.go('/booked');
    }
  }

  Widget _body(
    BuildContext context,
    AppScope scope,
    BookingController c,
    ProviderDetail d,
  ) {
    final days = groupSlots(c.slots, c.now);
    final selectedDay = _day != null && days.any((x) => x.day == _day)
        ? _day
        : (c.slot != null
              ? lagosDay(c.slot!.startsAt)
              : (days.isEmpty ? null : days.first.day));
    final times = selectedDay == null
        ? const <Slot>[]
        : days.firstWhere((x) => x.day == selectedDay).slots;
    final p = d.summary;
    final pets = scope.health.pets;
    Pet? pet;
    for (final x in pets) {
      if (x.id == c.petId) pet = x;
    }
    pet ??= scope.health.selected;
    final svc = c.service;
    final sl = c.slot;
    final payLabel = svc != null && sl != null
        ? 'Pay ${nairaFromKobo(svc.priceKobo)} & book · ${dayLabel(sl.startsAt).split(' ').first} ${timeLabel(sl.startsAt)}'
        : 'Choose a service and time';
    final busy = c.stage == PayStage.starting || c.stage == PayStage.checking;

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
              BookingHeader('Book ${p.name}'),
              const SizedBox(height: 16),
              PawCard(
                radius: PawRadius.cardSmall,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProviderMark(p.name, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: PawText.body15Strong),
                          const SizedBox(height: 3),
                          Text(
                            [
                              ratingLabel(p.ratingAvg, p.ratingCount),
                              if (p.address != null) p.address!,
                              if (p.distanceM != null)
                                distanceLabel(p.distanceM),
                            ].join(' · '),
                            style: PawText.meta13.copyWith(
                              color: PawColors.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (d.verified)
                                const PawBadge.verified('Verified'),
                              if (d.type != null) PawBadge(d.type!),
                              if (p.homeVisits) const PawBadge('Home visits'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionLabel('Choose a service'),
              const SizedBox(height: 10),
              for (final s in d.services)
                ChoiceRow(
                  title: s.name,
                  subtitle: '${s.durationMin} min',
                  trailing: nairaFromKobo(s.priceKobo),
                  selected: c.serviceId == s.id,
                  onTap: () => c.chooseService(s.id),
                ),
              const SizedBox(height: 12),
              const SectionLabel('Date'),
              const SizedBox(height: 10),
              if (days.isEmpty)
                const InfoCard(
                  title: 'No times available',
                  body: 'This provider has nothing open in the next two weeks. Check back soon.',
                  icon: PawIconData.calendar,
                )
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final day in days) ...[
                        _DayTile(
                          day: day,
                          selected: day.day == selectedDay,
                          onTap: () => setState(() => _day = day.day),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionLabel('Time'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in times)
                      if (t.isFree)
                        PawChip(
                          label: chipTime(t.startsAt),
                          selected: c.slot?.startsAt == t.startsAt,
                          onTap: () => c.chooseSlot(t),
                        )
                      else
                        Semantics(
                          label: '${timeLabel(t.startsAt)}, taken',
                          excludeSemantics: true,
                          child: PawChip(
                            label: chipTime(t.startsAt),
                            selected: false,
                            onTap: null,
                          ),
                        ),
                  ],
                ),
              ],
              if (pets.length > 1) ...[
                const SizedBox(height: 22),
                const SectionLabel('Who is it for'),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final x in pets) ...[
                        PawChip(
                          label: x.name,
                          selected: x.id == pet?.id,
                          onTap: () => c.choosePet(x.id),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
              if (c.reviews.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionLabel('Reviews (${p.ratingCount})'),
                const SizedBox(height: 10),
                for (final r in c.reviews.take(3)) _ReviewTile(review: r),
              ],
            ],
          ),
        ),
        _PayBar(controller: c, petName: pet?.name, label: payLabel, busy: busy),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.selected,
    required this.onTap,
  });
  final SlotDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = dayLabel(day.day.subtract(const Duration(hours: 1)));
    final parts = label.split(' ');
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 62,
          height: 78,
          decoration: BoxDecoration(
            color: selected ? PawColors.primary : PawColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? PawColors.primary : PawColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                parts.first,
                style: PawText.meta13.copyWith(
                  color: selected ? Colors.white : PawColors.muted,
                ),
              ),
              Text(
                parts[1],
                style: PawText.heading22.copyWith(
                  color: selected ? Colors.white : PawColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final ReviewItem review;

  @override
  Widget build(BuildContext context) {
    final who = review.reviewer ?? 'A pet owner';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PawCard(
        radius: PawRadius.cardSmall,
        semanticLabel: '$who rated ${review.rating} of 5. ${review.body ?? ''}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '★' * review.rating,
                  style: const TextStyle(color: PawColors.dot, fontSize: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    who,
                    style: PawText.body14Strong,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (review.body != null) ...[
              const SizedBox(height: 6),
              Text(
                review.body!,
                style: PawText.body14.copyWith(color: PawColors.ink2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The footer: the reassurance line and Pay button, or, while Paystack is open, "waiting for payment".
class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.controller,
    required this.petName,
    required this.label,
    required this.busy,
  });
  final BookingController controller;
  final String? petName;
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.stage == PayStage.waiting || c.stage == PayStage.checking) {
      return PawStickyFooter(
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              c.payNotice ?? 'Finish paying on the Paystack page, then come back here. We will check automatically.',
              style: PawText.meta13.copyWith(
                color: PawColors.ink2,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (c.payError != null)
            Text(
              c.payError!,
              textAlign: TextAlign.center,
              style: PawText.meta13.copyWith(color: PawColors.danger),
            ),
          PawButton(
            label: "I've paid",
            loading: c.stage == PayStage.checking,
            onPressed: c.stage == PayStage.checking ? null : c.checkPayment,
          ),
          PawButton(
            label: 'Cancel this booking',
            variant: PawButtonVariant.secondary,
            onPressed: c.stage == PayStage.checking ? null : c.abandonPayment,
          ),
        ],
      );
    }
    return PawStickyFooter(
      children: [
        if (c.payError != null)
          Semantics(
            liveRegion: true,
            child: Text(
              c.payError!,
              textAlign: TextAlign.center,
              style: PawText.meta13.copyWith(color: PawColors.danger),
            ),
          ),
        Text(
          petName == null
              ? 'Payment is held safely until your visit is done.'
              : "Payment held safely until your visit is done. $petName's passport is shared with the provider.",
          style: PawText.meta13.copyWith(color: PawColors.muted, height: 1.45),
          textAlign: TextAlign.center,
        ),
        PawButton(
          label: label,
          loading: busy,
          onPressed: c.canPay ? c.pay : null,
        ),
      ],
    );
  }
}
