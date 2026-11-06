import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/domain/booking_logic.dart';
import '../../booking/state/booking_controller.dart' show PayStage;
import '../../onboarding/state/app_scope.dart';
import '../domain/adopt_logic.dart';
import '../domain/models.dart';
import '../state/adopt_controller.dart';

/// A pet picture (or its first letter on a soft colour while the photo loads or if there is none).
class AdoptPetMark extends StatelessWidget {
  const AdoptPetMark({
    super.key,
    required this.name,
    this.path,
    this.size = 72,
    this.radius,
  });
  final String name;
  final String? path;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final url = AppScope.of(context).adopt.urlFor(path);
    final tint =
        PawColors.petTints[name.codeUnits.fold<int>(0, (a, b) => a + b) %
            PawColors.petTints.length];
    final fallback = ColoredBox(
      color: tint,
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: PawText.heading22.copyWith(
            fontSize: size * 0.42,
            color: PawColors.warmText,
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? size / 4),
        child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback,
                ),
        ),
      ),
    );
  }
}

/// A pet in the Adopt list.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.now});
  final AdoptListing listing;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final line = listingLine(l, now);
    final price = listingPrice(l);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PawCard(
        radius: PawRadius.cardSmall,
        onTap: () => context.push('/listing/${l.id}'),
        semanticLabel:
            '${l.petName}. $line. $price. ${l.partnerName}${l.reserved ? '. Reserved' : ''}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdoptPetMark(name: l.petName, path: l.photoPath, size: 72),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          l.petName,
                          style: PawText.body15Strong,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (l.reserved) ...[
                        const SizedBox(width: 8),
                        const PawBadge('Reserved', tone: PawBadgeTone.upcoming),
                      ],
                    ],
                  ),
                  if (line.isNotEmpty)
                    Text(
                      line,
                      style: PawText.meta13.copyWith(color: PawColors.muted),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    style: PawText.body15Strong.copyWith(
                      color: PawColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '✓ ${l.partnerName}',
                    style: PawText.meta13.copyWith(color: PawColors.ink2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four steps of an order, as the design draws them: a number or tick, and a label.
class OrderStepper extends StatelessWidget {
  const OrderStepper({super.key, required this.steps});
  final List<OrderStep> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Semantics(
              label:
                  '${steps[i].label}, ${switch (steps[i].state) {
                    StepStatus.done => 'done',
                    StepStatus.current => 'now',
                    StepStatus.todo => 'later',
                  }}',
              excludeSemantics: true,
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch (steps[i].state) {
                        StepStatus.done => PawColors.primary,
                        StepStatus.current => PawColors.primarySoft,
                        StepStatus.todo => PawColors.subtle,
                      },
                      border: steps[i].state == StepStatus.current
                          ? Border.all(color: PawColors.primary, width: 2)
                          : null,
                    ),
                    child: steps[i].state == StepStatus.done
                        ? const PawIcon(
                            PawIconData.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : Text(
                            '${i + 1}',
                            style: PawText.meta13.copyWith(
                              color: PawColors.ink2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i].label,
                    textAlign: TextAlign.center,
                    style: PawText.meta12.copyWith(
                      color: steps[i].state == StepStatus.todo
                          ? PawColors.muted
                          : PawColors.ink,
                      fontWeight: steps[i].state == StepStatus.current
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A label on the left and an amount on the right.
class MoneyRow extends StatelessWidget {
  const MoneyRow(
    this.label,
    this.kobo, {
    super.key,
    this.strong = false,
    this.note,
  });
  final String label;
  final int kobo;
  final bool strong;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final style = strong ? PawText.body15Strong : PawText.body15;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                if (note != null)
                  Text(
                    note!,
                    style: PawText.meta12.copyWith(color: PawColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(nairaFromKobo(kobo), style: style),
        ],
      ),
    );
  }
}

/// The footer while a payment is under way: "finish on Paystack, then come back".
class PayWaitingBar extends StatelessWidget {
  const PayWaitingBar({super.key, required this.controller});
  final AdoptController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return PawStickyFooter(
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            c.payNotice ?? 'Finish paying on the Paystack page, then come back here. We will check automatically.',
            style: PawText.meta13.copyWith(color: PawColors.ink2, height: 1.45),
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
          label: c.payingBalance ? 'Not now' : 'Cancel this order',
          variant: PawButtonVariant.secondary,
          onPressed: c.stage == PayStage.checking ? null : c.abandonPayment,
        ),
      ],
    );
  }
}
