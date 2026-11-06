import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/domain/booking_logic.dart';
import '../../booking/state/booking_controller.dart' show PayStage;
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../state/adopt_controller.dart';
import 'adopt_widgets.dart';

/// Pay deposit (design/screens/Checkout.dc.html): a third of the price plus a small protection fee, held in escrow.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.listingId});
  final String listingId;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with WidgetsBindingObserver {
  var _started = false;
  AdoptController? _c;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _c?.stage == PayStage.waiting) {
      _c?.checkPayment();
    }
  }

  void _maybeLeave() {
    final c = _c;
    if (c == null || !mounted) {
      return;
    }
    final id = c.paidOrderId;
    if (id != null && c.stage == PayStage.idle) {
      c.removeListener(_maybeLeave);
      context.pushReplacement('/orders/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c = AppScope.of(context).adopt;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        c.addListener(_maybeLeave);
        if (c.detail?.listing.id != widget.listingId) {
          c.openListing(widget.listingId);
        }
      });
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final d = c.detail;
        final waiting =
            c.stage == PayStage.waiting || c.stage == PayStage.checking;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            bottom: false,
            child: d == null
                ? Center(
                    child: c.detailError == null
                        ? const CircularProgressIndicator()
                        : LoadError(
                            message: c.detailError!,
                            onRetry: () => c.openListing(widget.listingId),
                          ),
                  )
                : Column(
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
                            const BookingHeader('Pay deposit'),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                AdoptPetMark(
                                  name: d.listing.petName,
                                  path: d.listing.photoPath,
                                  size: 56,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${d.listing.petName} · ${d.listing.breed ?? d.listing.species}',
                                        style: PawText.body15Strong,
                                      ),
                                      Text(
                                        [
                                          d.listing.partnerName,
                                          if (d.handoverBy != null)
                                            'handover by ${dayLabel(d.handoverBy!).split(' ').skip(1).join(' ')}',
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
                            PawCard(
                              radius: PawRadius.cardSmall,
                              child: Column(
                                children: [
                                  MoneyRow(
                                    'Puppy price',
                                    d.listing.priceKobo ?? 0,
                                  ),
                                  MoneyRow(
                                    'Deposit now (⅓)',
                                    d.depositKobo ?? 0,
                                  ),
                                  MoneyRow(
                                    'Escrow protection fee',
                                    d.protectionFeeKobo ?? 0,
                                  ),
                                  const Divider(color: PawColors.border),
                                  MoneyRow(
                                    'Pay today',
                                    d.dueTodayKobo ?? 0,
                                    strong: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Balance of ${nairaFromKobo(d.balanceKobo ?? 0)} is paid at handover, also held in escrow.',
                              style: PawText.meta13.copyWith(
                                color: PawColors.muted,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const SectionLabel('Pay with'),
                            const SizedBox(height: 8),
                            Text(
                              'Card, bank transfer or USSD. You choose on the next page, which is Paystack\'s secure page.',
                              style: PawText.body14.copyWith(
                                color: PawColors.ink2,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 18),
                            PawCard(
                              color: PawColors.primarySoft,
                              radius: PawRadius.cardSmall,
                              child: Text(
                                'Full refund if the seller cancels or a vet finds a health problem within 72 hours of handover.',
                                style: PawText.meta13.copyWith(
                                  color: PawColors.primaryText,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (waiting)
                        PayWaitingBar(controller: c)
                      else
                        PawStickyFooter(
                          children: [
                            if (c.payError != null)
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  c.payError!,
                                  textAlign: TextAlign.center,
                                  style: PawText.meta13.copyWith(
                                    color: PawColors.danger,
                                  ),
                                ),
                              ),
                            PawButton(
                              label:
                                  'Pay ${nairaFromKobo(d.dueTodayKobo ?? 0)} into escrow',
                              loading: c.stage == PayStage.starting,
                              onPressed: c.paying || !d.available
                                  ? null
                                  : () => c.payDeposit(widget.listingId),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
