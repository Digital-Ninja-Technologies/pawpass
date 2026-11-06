import '../../booking/domain/booking_logic.dart';
import 'models.dart';

/// "9 wks", "5 months", "1 yr" from a birth date. Empty if unknown.
String petAgeLabel(DateTime? bornOn, DateTime now) {
  if (bornOn == null) {
    return '';
  }
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(bornOn.year, bornOn.month, bornOn.day)).inDays;
  if (days < 0) {
    return '';
  }
  if (days < 7) {
    return 'newborn';
  }
  if (days < 100) {
    return '${days ~/ 7} wks';
  }
  final months = (days / 30.4).floor();
  if (months < 24) {
    return months == 12 ? '1 yr' : '$months months';
  }
  return '${months ~/ 12} yrs';
}

/// "M" or "F" for the list.
String sexInitial(String? sex) => switch (sex) {
  'male' => 'M',
  'female' => 'F',
  _ => '',
};

/// "Boerboel · 9 wks · M"
String listingLine(AdoptListing l, DateTime now) => [
  if ((l.breed ?? '').isNotEmpty) l.breed!,
  petAgeLabel(l.bornOn, now),
  sexInitial(l.sex),
].where((s) => s.isNotEmpty).join(' · ');

/// "₦450,000" or "Adopt · free".
String listingPrice(AdoptListing l) => l.kind == ListingKind.adoption
    ? 'Adopt · free'
    : (l.priceKobo == null ? '' : nairaFromKobo(l.priceKobo!));

/// The four steps under "Protected by escrow".
enum StepStatus { done, current, todo }

class OrderStep {
  const OrderStep(this.label, this.state);
  final String label;
  final StepStatus state;
}

List<OrderStep> orderSteps(OrderDetail o) {
  final cancelled = o.status == OrderStatus.cancelled;
  // How far along: 0 nothing paid, 1 deposit in, 2 handed over, 3 window finished (seller paid).
  final stage = switch (o.status) {
    OrderStatus.pendingDeposit => 0,
    OrderStatus.depositPaid || OrderStatus.balancePaid => 1,
    OrderStatus.handedOver || OrderStatus.disputed => 2,
    OrderStatus.completed => 4,
    OrderStatus.cancelled => o.depositPaid ? 1 : 0,
  };
  StepStatus at(int i) => cancelled
      ? (i < stage ? StepStatus.done : StepStatus.todo)
      : (i < stage
            ? StepStatus.done
            : (i == stage ? StepStatus.current : StepStatus.todo));
  return [
    OrderStep('Pay deposit', at(0)),
    OrderStep('Meet & pick up', at(1)),
    OrderStep('72-hr vet check', at(2)),
    OrderStep('Seller paid', at(3)),
  ];
}

/// Whole hours left, rounded up, never below zero.
int hoursLeft(DateTime? ends, DateTime now) {
  if (ends == null) {
    return 0;
  }
  final d = ends.toUtc().difference(now.toUtc());
  if (d.isNegative) {
    return 0;
  }
  return (d.inMinutes / 60).ceil();
}

/// What the buyer can do next on an order.
enum BuyerAction { none, payBalance, acceptPassport, reportProblem }

List<BuyerAction> buyerActions(OrderDetail o, DateTime now) {
  if (!o.isBuyer) {
    return const [];
  }
  switch (o.status) {
    case OrderStatus.depositPaid:
      return o.balanceKobo > 0 ? const [BuyerAction.payBalance] : const [];
    case OrderStatus.handedOver:
      final open = hoursLeft(o.vetCheckEndsAt, now) > 0;
      return [
        if (!o.transferCompleted && o.transferId != null)
          BuyerAction.acceptPassport,
        if (open) BuyerAction.reportProblem,
      ];
    default:
      return const [];
  }
}

/// A plain sentence for where the order stands.
String orderHeadline(OrderDetail o, DateTime now) {
  switch (o.status) {
    case OrderStatus.pendingDeposit:
      return 'Waiting for your deposit';
    case OrderStatus.depositPaid:
      return o.isBuyer
          ? 'Deposit paid. Arrange the pick up.'
          : 'Deposit paid. Arrange the handover.';
    case OrderStatus.balancePaid:
      return o.isBuyer
          ? 'Balance paid. Waiting for the handover.'
          : 'Balance paid. Confirm the handover.';
    case OrderStatus.handedOver:
      final h = hoursLeft(o.vetCheckEndsAt, now);
      return h > 0
          ? 'Vet check window: $h hours left'
          : 'The vet check window has ended';
    case OrderStatus.disputed:
      return 'Problem reported. The payment is on hold.';
    case OrderStatus.completed:
      return 'Complete. ${o.petName} is home.';
    case OrderStatus.cancelled:
      return o.depositPaid
          ? 'Cancelled. You are refunded in full.'
          : 'Cancelled';
  }
}

String orderStatusBadge(OrderStatus s) => switch (s) {
  OrderStatus.pendingDeposit => 'Unpaid',
  OrderStatus.depositPaid => 'Deposit paid',
  OrderStatus.balancePaid => 'Balance paid',
  OrderStatus.handedOver => 'Vet check',
  OrderStatus.disputed => 'Under review',
  OrderStatus.completed => 'Complete',
  OrderStatus.cancelled => 'Cancelled',
};

String applicationLabel(String status) => switch (status) {
  'submitted' => 'Application sent',
  'home_visit' => 'Home visit planned',
  'approved' => 'Approved',
  'declined' => 'Not this time',
  _ => status,
};

/// "12 Nov", for "handover by".
String shortDay(DateTime t) => dayLabel(t).split(' ').skip(1).join(' ');
