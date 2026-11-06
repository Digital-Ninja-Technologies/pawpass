import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/domain/booking_logic.dart' show nairaFromKobo;
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../../partner/ui/partner_widgets.dart' show EmptyNote;
import '../domain/models.dart';
import '../state/tag_order_controller.dart';

/// Order a QR collar tag (design/screens/QrTagOrder.dc.html).
class QrTagOrderScreen extends StatefulWidget {
  const QrTagOrderScreen({super.key});

  @override
  State<QrTagOrderScreen> createState() => _QrTagOrderScreenState();
}

class _QrTagOrderScreenState extends State<QrTagOrderScreen>
    with WidgetsBindingObserver {
  TagOrderController? _c;
  final _address = TextEditingController();
  final _area = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _address.dispose();
    _area.dispose();
    _c?.dispose();
    super.dispose();
  }

  /// Coming back from the Paystack page: check whether the money arrived.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _c?.stage == TagStage.waiting) {
      _c?.checkPayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    var c = _c;
    if (c == null) {
      final made = c = _c = TagOrderController(scope.services);
      made.choosePet(scope.health.selected?.id);
      made.setArea(scope.session.profile?.area ?? '');
      _area.text = made.area;
      // Load the price and past orders after the first frame, so the screen never rebuilds inside a build.
      WidgetsBinding.instance.addPostFrameCallback((_) => made.load());
    }
    final ctl = c;
    return ListenableBuilder(
      listenable: Listenable.merge([ctl, scope.health]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: ctl.paid != null
                ? _Ordered(order: ctl.paid!)
                : ctl.loading && ctl.prices == null
                ? const Center(child: CircularProgressIndicator())
                : ctl.prices == null
                ? Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(PawSpace.screenSide),
                        child: BookingHeader('Order a QR tag'),
                      ),
                      Expanded(
                        child: PawErrorState(
                          title: 'We could not load the price',
                          message:
                              ctl.loadError ??
                              'Something went wrong on our side. Please try again.',
                          onAction: ctl.load,
                        ),
                      ),
                    ],
                  )
                : _Form(
                    c: ctl,
                    pets: scope.health.pets,
                    address: _address,
                    area: _area,
                  ),
          ),
        );
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.c,
    required this.pets,
    required this.address,
    required this.area,
  });

  final TagOrderController c;
  final List<Pet> pets;
  final TextEditingController address;
  final TextEditingController area;

  @override
  Widget build(BuildContext context) {
    final prices = c.prices!;
    final waiting = c.stage == TagStage.waiting || c.stage == TagStage.checking;
    final petName = [
      for (final p in pets)
        if (p.id == c.petId) p.name,
    ].firstOrNull;
    final shown = c.orders.take(5).toList();
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
              const BookingHeader('Order a QR tag'),
              const SizedBox(height: 12),
              Text(
                'A tough collar tag with a QR code. Anyone who scans it can message you, and your number stays hidden.',
                style: PawText.body14.copyWith(color: PawColors.ink2),
              ),
              const SizedBox(height: 18),
              const SectionLabel('Which pet?'),
              const SizedBox(height: 8),
              if (pets.isEmpty)
                const EmptyNote('Add a pet first, then order their tag.')
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final p in pets)
                      PawChip(
                        label: p.name,
                        selected: p.id == c.petId,
                        onTap: waiting ? () {} : () => c.choosePet(p.id),
                      ),
                  ],
                ),
              const SizedBox(height: 18),
              const SectionLabel('Tag colour'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final t in TagColour.values) ...[
                    Expanded(
                      child: _Swatch(
                        colour: t,
                        selected: c.colour == t,
                        onTap: waiting ? null : () => c.chooseColour(t),
                      ),
                    ),
                    if (t != TagColour.values.last) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              const SectionLabel('Deliver to'),
              const SizedBox(height: 8),
              PawTextField(
                label: 'Street address',
                controller: address,
                enabled: !waiting,
                errorText: c.addressError,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                autofillHints: const [AutofillHints.streetAddressLine1],
                onChanged: c.setAddress,
              ),
              const SizedBox(height: 12),
              PawTextField(
                label: 'Area',
                controller: area,
                enabled: !waiting,
                errorText: c.areaError,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                maxLength: 80,
                onChanged: c.setArea,
              ),
              const SizedBox(height: 6),
              Text(
                'The courier gets a phone number from us to call you. We never show it to anyone else.',
                style: PawText.meta12.copyWith(color: PawColors.muted),
              ),
              const SizedBox(height: 16),
              PawCard(
                radius: PawRadius.cardSmall,
                semanticLabel:
                    'Total ${nairaFromKobo(prices.totalKobo)}, tag ${nairaFromKobo(prices.priceKobo)} and delivery ${nairaFromKobo(prices.deliveryKobo)}',
                child: Column(
                  children: [
                    _Line(
                      'QR tag${petName == null ? '' : ' for $petName'}',
                      nairaFromKobo(prices.priceKobo),
                    ),
                    const SizedBox(height: 8),
                    _Line(
                      'Delivery in Lagos · 2 to 4 days',
                      nairaFromKobo(prices.deliveryKobo),
                    ),
                    const Divider(height: 24, color: PawColors.subtle),
                    _Line(
                      'Total',
                      nairaFromKobo(prices.totalKobo),
                      strong: true,
                    ),
                  ],
                ),
              ),
              if (shown.isNotEmpty) ...[
                const SizedBox(height: 22),
                const SectionLabel('Your tag orders'),
                const SizedBox(height: 4),
                for (final o in shown)
                  PawListRow(
                    title: '${o.petName} · ${o.colour.label}',
                    subtitle:
                        '${nairaFromKobo(o.totalKobo)} · ${o.status.label}',
                    showDivider: o != shown.last,
                  ),
              ],
              if (c.payError != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    c.payError!,
                    style: PawText.body14.copyWith(color: PawColors.danger),
                  ),
                ),
              ],
              if (c.payNotice != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    c.payNotice!,
                    style: PawText.body14.copyWith(color: PawColors.ink2),
                  ),
                ),
              ],
            ],
          ),
        ),
        PawStickyFooter(
          children: waiting
              ? [
                  Text(
                    'Finish paying on the Paystack page, then come back here. We will check automatically.',
                    textAlign: TextAlign.center,
                    style: PawText.meta12.copyWith(color: PawColors.muted),
                  ),
                  PawButton(
                    label: 'I have paid, check now',
                    loading: c.stage == TagStage.checking,
                    onPressed: c.checkPayment,
                  ),
                  PawButton(
                    label: 'Change my details',
                    variant: PawButtonVariant.secondary,
                    height: 44,
                    onPressed: c.stage == TagStage.checking
                        ? null
                        : c.cancelWaiting,
                  ),
                ]
              : [
                  PawButton(
                    label:
                        'Pay ${nairaFromKobo(prices.totalKobo)} with Paystack',
                    loading: c.stage == TagStage.starting,
                    onPressed: c.canPay ? c.pay : null,
                  ),
                  Text(
                    "Card, bank transfer or USSD, on Paystack's secure page.",
                    textAlign: TextAlign.center,
                    style: PawText.meta12.copyWith(color: PawColors.muted),
                  ),
                ],
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong ? PawText.body15Strong : PawText.body14;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: style)),
        const SizedBox(width: 12),
        Text(
          value,
          style: PawText.body14Strong.copyWith(fontSize: strong ? 16 : 14),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.colour,
    required this.selected,
    required this.onTap,
  });
  final TagColour colour;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${colour.label} tag',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          decoration: BoxDecoration(
            color: PawColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? PawColors.primary : PawColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colour.colour,
                  shape: BoxShape.circle,
                  border: Border.all(color: colour.ring, width: 3),
                ),
              ),
              const SizedBox(height: 8),
              Text(colour.label, style: PawText.body14Strong),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown once the payment is confirmed.
class _Ordered extends StatelessWidget {
  const _Ordered({required this.order});
  final TagOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PawEmptyState(
            icon: PawIconData.check,
            title: 'Tag ordered',
            message:
                "${order.petName}'s ${order.colour.label.toLowerCase()} tag is paid for. We will ship it and tell you when it is on its way. Delivery in Lagos takes 2 to 4 days.",
          ),
        ),
        PawStickyFooter(
          children: [
            PawButton(
              label: 'Done',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/me'),
            ),
          ],
        ),
      ],
    );
  }
}
