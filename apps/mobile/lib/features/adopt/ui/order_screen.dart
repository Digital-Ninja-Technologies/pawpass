import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/domain/booking_logic.dart';
import '../../booking/state/booking_controller.dart' show PayStage;
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/adopt_logic.dart';
import '../domain/models.dart';
import '../state/adopt_controller.dart';
import 'adopt_widgets.dart';

/// Passport transfer and escrow (design/screens/Transfer.dc.html): where the order stands and what to do next.
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> with WidgetsBindingObserver {
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
    _c?.removeListener(_onChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _c?.stage == PayStage.waiting) {
      _c?.checkPayment();
    }
  }

  /// A balance payment just went through: show the new state.
  void _onChange() {
    final c = _c;
    if (c == null || !mounted) {
      return;
    }
    if (c.paidOrderId == widget.orderId && c.stage == PayStage.idle) {
      c.paidOrderId = null;
      c.reloadOrder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = _c = scope.adopt;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        c.addListener(_onChange);
        c.openOrder(widget.orderId);
      });
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final o = c.order;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            bottom: false,
            child: c.loadingOrder && o == null
                ? const Center(child: CircularProgressIndicator())
                : o == null
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
                              c.orderError ?? 'We could not load this order.',
                          onRetry: () => c.openOrder(widget.orderId),
                        ),
                      ),
                    ],
                  )
                : _body(context, scope, c, o),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppScope scope,
    AdoptController c,
    OrderDetail o,
  ) {
    final now = c.now;
    final actions = buyerActions(o, now);
    final waiting = c.stage == PayStage.waiting || c.stage == PayStage.checking;
    final home = o.status == OrderStatus.completed || o.transferCompleted;
    final title = home
        ? '${o.petName} is home'
        : (o.status == OrderStatus.handedOver
              ? '${o.petName} is coming home'
              : o.petName);
    final hours = hoursLeft(o.vetCheckEndsAt, now);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: c.reloadOrder,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                PawSpace.screenSide,
                12,
                PawSpace.screenSide,
                24,
              ),
              children: [
                const BookingHeader('Passport transfer and escrow'),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text(title, style: PawText.title28),
                ),
                const SizedBox(height: 4),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    orderHeadline(o, now),
                    style: PawText.body15.copyWith(color: PawColors.muted),
                  ),
                ),
                const SizedBox(height: 18),
                OrderStepper(steps: orderSteps(o)),
                const SizedBox(height: 20),
                PawCard(
                  radius: PawRadius.cardSmall,
                  child: Row(
                    children: [
                      ProviderMark(o.partnerName, size: 44),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          o.partnerName,
                          style: PawText.body14Strong,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const PawIcon(
                        PawIconData.chevronRight,
                        size: 18,
                        color: PawColors.muted,
                      ),
                      const SizedBox(width: 10),
                      ProviderMark(
                        o.isBuyer ? 'You' : (o.buyerName ?? 'Buyer'),
                        size: 44,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          o.isBuyer ? 'You' : (o.buyerName ?? 'The buyer'),
                          style: PawText.body14Strong,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionLabel('What you receive'),
                const SizedBox(height: 8),
                for (final line in const [
                  'Full health record, vet verified entries marked',
                  "Origin and parents' records",
                  'QR tag ID and reminder schedule',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: PawIcon(
                            PawIconData.check,
                            size: 16,
                            color: PawColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(line, style: PawText.body14)),
                      ],
                    ),
                  ),
                Text(
                  '${o.partnerName} keeps a read-only record of the transfer.',
                  style: PawText.meta13.copyWith(color: PawColors.muted),
                ),
                const SizedBox(height: 20),
                const SectionLabel('Escrow status'),
                const SizedBox(height: 10),
                _StatusLine(
                  done: o.depositPaid,
                  title: o.depositPaid
                      ? 'Deposit paid · ${nairaFromKobo(o.depositKobo + o.protectionFeeKobo)}'
                      : 'Deposit of ${nairaFromKobo(o.depositKobo + o.protectionFeeKobo)}',
                  sub:
                      'Includes a ${nairaFromKobo(o.protectionFeeKobo)} protection fee',
                ),
                _StatusLine(
                  done: o.balancePaid,
                  title: o.balancePaid
                      ? 'Balance paid · ${nairaFromKobo(o.balanceKobo)}'
                      : 'Balance of ${nairaFromKobo(o.balanceKobo)} at pick up',
                  sub: o.balancePaid
                      ? 'Held in escrow'
                      : 'Pay in the app when you collect ${o.petName}',
                ),
                _StatusLine(
                  done: o.handedOverAt != null,
                  title: o.handedOverAt != null
                      ? 'Handover confirmed'
                      : 'Handover',
                  sub: o.handedOverAt != null
                      ? whenLabel(o.handedOverAt!)
                      : (o.handoverBy != null
                            ? 'Planned by ${shortDay(o.handoverBy!)}'
                            : 'The seller confirms it in the app'),
                ),
                _StatusLine(
                  done: o.status == OrderStatus.completed,
                  title: o.handedOverAt == null
                      ? 'Vet check window'
                      : (hours > 0 || o.status == OrderStatus.disputed
                            ? 'Vet check window'
                            : 'Vet check window ended'),
                  sub: o.handedOverAt == null
                      ? '72 hours after handover'
                      : (o.status == OrderStatus.disputed
                            ? 'Paused while OurPawPass reviews your report'
                            : (hours > 0
                                  ? '$hours hours left · book a vet visit'
                                  : 'No problem was reported')),
                ),
                _StatusLine(
                  done: o.status == OrderStatus.completed,
                  title: o.status == OrderStatus.completed
                      ? 'Payment released to the seller'
                      : 'Payment released to the seller',
                  sub: o.status == OrderStatus.completed
                      ? 'It goes out in the next payout run'
                      : 'After the vet check window, if all is well',
                  last: true,
                ),
                if (o.status == OrderStatus.disputed &&
                    o.disputeDueAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'OurPawPass decides by ${dayLabel(o.disputeDueAt!)}.',
                    style: PawText.meta13.copyWith(color: PawColors.muted),
                  ),
                ],
                if (!o.isBuyer && scope.partner.sellerError != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      scope.partner.sellerError!,
                      style: PawText.body14.copyWith(color: PawColors.danger),
                    ),
                  ),
                ],
                if (c.acceptError != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      c.acceptError!,
                      style: PawText.body14.copyWith(color: PawColors.danger),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (waiting)
          PayWaitingBar(controller: c)
        else if (sellerActions(o).isNotEmpty)
          PawStickyFooter(
            children: [
              for (final a in sellerActions(o))
                switch (a) {
                  SellerAction.confirmHandover => PawButton(
                    label: 'Confirm handover',
                    loading: scope.partner.sellerBusy,
                    onPressed: scope.partner.sellerBusy
                        ? null
                        : () => _confirmHandover(context, scope, c, o),
                  ),
                  SellerAction.cancelOrder => PawButton(
                    label: 'Cancel order',
                    variant: PawButtonVariant.secondary,
                    onPressed: scope.partner.sellerBusy
                        ? null
                        : () => _cancelOrder(context, scope, c, o),
                  ),
                },
            ],
          )
        else if (actions.isNotEmpty)
          PawStickyFooter(
            children: [
              if (c.payError != null)
                Text(
                  c.payError!,
                  textAlign: TextAlign.center,
                  style: PawText.meta13.copyWith(color: PawColors.danger),
                ),
              for (final a in actions)
                switch (a) {
                  BuyerAction.payBalance => PawButton(
                    label: 'Pay balance ${nairaFromKobo(o.balanceKobo)}',
                    loading: c.stage == PayStage.starting,
                    onPressed: c.paying ? null : () => c.payBalance(o.id),
                  ),
                  BuyerAction.acceptPassport => PawButton(
                    label: 'Accept passport',
                    loading: c.accepting,
                    onPressed: c.accepting
                        ? null
                        : () => _accept(context, scope, c, o),
                  ),
                  BuyerAction.reportProblem => PawButton(
                    label: 'Report a problem',
                    variant: PawButtonVariant.secondary,
                    onPressed: () => context.push('/orders/${o.id}/problem'),
                  ),
                  BuyerAction.none => const SizedBox.shrink(),
                },
            ],
          ),
      ],
    );
  }

  Future<void> _confirmHandover(
    BuildContext context,
    AppScope scope,
    AdoptController c,
    OrderDetail o,
  ) async {
    final ok = await scope.partner.confirmHandover(o.id);
    if (!context.mounted) {
      return;
    }
    if (ok) {
      await c.reloadOrder();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Handover confirmed. ${o.buyerName ?? 'The buyer'} can now accept ${o.petName}\'s passport.'
                  : scope.partner.sellerError ?? 'That did not work.',
            ),
          ),
        );
    }
  }

  Future<void> _cancelOrder(
    BuildContext context,
    AppScope scope,
    AdoptController c,
    OrderDetail o,
  ) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'Everything ${o.buyerName ?? 'the buyer'} paid is refunded in full, and ${o.petName} goes back on sale.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep the order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) {
      return;
    }
    final ok = await scope.partner.cancelOrder(o.id);
    if (!context.mounted) {
      return;
    }
    if (ok) {
      await c.reloadOrder();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Order cancelled. The buyer is refunded in full.'
                  : scope.partner.sellerError ?? 'That did not work.',
            ),
          ),
        );
    }
  }

  Future<void> _accept(
    BuildContext context,
    AppScope scope,
    AdoptController c,
    OrderDetail o,
  ) async {
    final ok = await c.acceptPassport(o.transferId!);
    if (ok && context.mounted) {
      scope.health.load();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("${o.petName}'s passport is yours.")),
        );
    }
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.done,
    required this.title,
    required this.sub,
    this.last = false,
  });
  final bool done;
  final String title;
  final String sub;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${done ? 'Done' : 'Not yet'}: $title. $sub',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? PawColors.primary : PawColors.surface,
                border: Border.all(
                  color: done ? PawColors.primary : PawColors.outline,
                  width: 1.5,
                ),
              ),
              child: done
                  ? const PawIcon(
                      PawIconData.check,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PawText.body14Strong.copyWith(
                      color: done ? PawColors.ink : PawColors.ink2,
                    ),
                  ),
                  Text(
                    sub,
                    style: PawText.meta13.copyWith(color: PawColors.muted),
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
