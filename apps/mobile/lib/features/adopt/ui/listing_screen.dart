import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/domain/booking_logic.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/adopt_logic.dart';
import '../domain/models.dart';
import 'adopt_widgets.dart';

/// A pet's listing (design/screens/Listing.dc.html): who sells it, what transfers, what it costs, and how escrow protects you.
class ListingScreen extends StatefulWidget {
  const ListingScreen({super.key, required this.listingId});
  final String listingId;

  @override
  State<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends State<ListingScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = scope.adopt;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => c.openListing(widget.listingId),
      );
    }
    return ListenableBuilder(
      listenable: c,
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
                              'We could not load this listing.',
                          onRetry: () => c.openListing(widget.listingId),
                        ),
                      ),
                    ],
                  )
                : _body(context, d),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, ListingDetail d) {
    final scope = AppScope.of(context);
    final c = scope.adopt;
    final l = d.listing;
    final sale = l.kind == ListingKind.sale;
    final line = [
      if ((l.breed ?? '').isNotEmpty) l.breed!,
      if (l.sex != null)
        l.sex == 'male' ? 'Male' : (l.sex == 'female' ? 'Female' : ''),
      petAgeLabel(l.bornOn, c.now),
      if (l.partnerArea != null) l.partnerArea!,
    ].where((s) => s.isNotEmpty).join(' · ');
    final parents = [
      d.fatherName,
      d.motherName,
    ].whereType<String>().join(' × ');

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
              BookingHeader(
                sale ? 'Verified puppy listing' : 'Adoption listing',
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdoptPetMark(name: l.petName, path: l.photoPath, size: 96),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(l.petName, style: PawText.title28),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          line,
                          style: PawText.meta13.copyWith(
                            color: PawColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listingPrice(l),
                          style: PawText.heading22.copyWith(
                            color: PawColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              PawCard(
                radius: PawRadius.cardSmall,
                child: Row(
                  children: [
                    ProviderMark(l.partnerName, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.partnerName, style: PawText.body15Strong),
                          const SizedBox(height: 2),
                          Text(
                            sale
                                ? 'ID, facility and vet reference checked'
                                : 'Registered shelter. Checked by OurPawPass.',
                            style: PawText.meta13.copyWith(
                              color: PawColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (d.partnerVerified) const PawBadge.verified('Verified'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: SectionLabel("${l.petName}'s passport")),
                  Text(
                    'Transfers to you',
                    style: PawText.meta13.copyWith(
                      color: PawColors.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              PawCard(
                radius: PawRadius.cardSmall,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (parents.isNotEmpty)
                      _FactRow('Parents', '$parents (both registered)'),
                    for (final r in d.records)
                      _FactRow(
                        r.type == 'vaccine'
                            ? 'Vaccine'
                            : (r.type == 'deworming'
                                  ? 'Deworming'
                                  : 'Health check'),
                        [
                          r.name,
                          if (r.givenOn != null) dayLabel(r.givenOn!),
                          if (r.verified) '✓ vet',
                        ].join(' · '),
                      ),
                    if (parents.isEmpty && d.records.isEmpty)
                      Text(
                        'The seller has not added health records yet. Ask them before you pay.',
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (sale) ...[
                const SectionLabel('Protected by escrow'),
                const SizedBox(height: 12),
                const OrderStepper(
                  steps: [
                    OrderStep('Pay deposit', StepStatus.todo),
                    OrderStep('Meet & pick up', StepStatus.todo),
                    OrderStep('72-hr vet check', StepStatus.todo),
                    OrderStep('Seller paid', StepStatus.todo),
                  ],
                ),
                if (d.dueTodayKobo != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Deposit today ${nairaFromKobo(d.dueTodayKobo!)}, the rest at pick up.',
                    style: PawText.meta13.copyWith(color: PawColors.muted),
                  ),
                ],
              ] else ...[
                const SectionLabel('How adoption works'),
                const SizedBox(height: 10),
                Text(
                  'Apply, meet the shelter for a short home visit or video call, then collect your pet. The passport moves to you when you accept it. Adoption is free.',
                  style: PawText.meta13.copyWith(
                    color: PawColors.ink2,
                    height: 1.5,
                  ),
                ),
              ],
              if (c.actionError != null) ...[
                const SizedBox(height: 14),
                Text(
                  c.actionError!,
                  style: PawText.body14.copyWith(color: PawColors.danger),
                ),
              ],
            ],
          ),
        ),
        PawStickyFooter(children: [_footerRow(context, d)]),
      ],
    );
  }

  Widget _footerRow(BuildContext context, ListingDetail d) {
    final parts = _actions(context, d);
    if (parts.length == 1) {
      return parts.first.child;
    }
    return Row(
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(flex: parts[i].flex, child: parts[i].child),
        ],
      ],
    );
  }

  List<({int flex, Widget child})> _actions(
    BuildContext context,
    ListingDetail d,
  ) {
    final c = AppScope.of(context).adopt;
    final l = d.listing;
    final message = PawButton(
      label: 'Message',
      variant: PawButtonVariant.secondary,
      onPressed: d.isMine
          ? null
          : () async {
              final id = await c.openChat(l.id);
              if (id != null && context.mounted) {
                context.push('/chat/$id');
              }
            },
    );
    if (d.isMine) {
      return [
        (
          flex: 1,
          child: PawButton(label: 'This is your listing', onPressed: null),
        ),
      ];
    }
    if (l.kind == ListingKind.sale) {
      if (d.myOrderId != null) {
        return [
          (
            flex: 1,
            child: PawButton(
              label: 'View your order',
              onPressed: () => context.push('/orders/${d.myOrderId}'),
            ),
          ),
        ];
      }
      return [
        (flex: 1, child: message),
        (
          flex: 2,
          child: PawButton(
            label: d.available ? 'Pay deposit safely' : 'Reserved',
            onPressed: d.available
                ? () => context.push('/checkout/${l.id}')
                : null,
          ),
        ),
      ];
    }
    // adoption
    final status = d.myApplicationStatus;
    if (d.myTransferId != null) {
      return [
        (
          flex: 1,
          child: PawButton(
            label: "Accept ${l.petName}'s passport",
            onPressed: () => context.push('/transfer/${d.myTransferId}'),
          ),
        ),
      ];
    }
    if (status != null) {
      return [
        (flex: 1, child: message),
        (
          flex: 2,
          child: PawButton(label: applicationLabel(status), onPressed: null),
        ),
      ];
    }
    return [
      (flex: 1, child: message),
      (
        flex: 2,
        child: PawButton(
          label: d.available ? 'Apply to adopt' : 'Not available',
          onPressed: d.available ? () => context.push('/apply/${l.id}') : null,
        ),
      ),
    ];
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: PawText.meta13.copyWith(color: PawColors.muted),
            ),
          ),
          Expanded(child: Text(value, style: PawText.body14Strong)),
        ],
      ),
    );
  }
}
