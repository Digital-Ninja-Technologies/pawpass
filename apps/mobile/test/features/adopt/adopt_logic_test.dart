import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/adopt/domain/adopt_logic.dart';
import 'package:pawpass/features/adopt/domain/models.dart';

final _now = DateTime.utc(2026, 11, 5, 8);

OrderDetail _o({
  OrderStatus status = OrderStatus.depositPaid,
  bool isBuyer = true,
  bool depositPaid = true,
  bool balancePaid = false,
  DateTime? ends,
  String? transferId,
  bool transferCompleted = false,
}) => OrderDetail(
  id: 'o',
  status: status,
  petId: 'p',
  petName: 'Duke',
  species: 'dog',
  partnerName: 'Royal Paws Kennels',
  priceKobo: 45000000,
  depositKobo: 15000000,
  protectionFeeKobo: 750000,
  balanceKobo: 30000000,
  isBuyer: isBuyer,
  depositPaid: depositPaid,
  balancePaid: balancePaid,
  vetCheckEndsAt: ends,
  handedOverAt: ends?.subtract(const Duration(hours: 72)),
  transferId: transferId,
  transferCompleted: transferCompleted,
);

List<StepStatus> _states(OrderDetail o) => [
  for (final s in orderSteps(o)) s.state,
];

void main() {
  test('ages read like the designs', () {
    expect(petAgeLabel(null, _now), '');
    expect(
      petAgeLabel(_now.subtract(const Duration(days: 3)), _now),
      'newborn',
    );
    expect(petAgeLabel(_now.subtract(const Duration(days: 63)), _now), '9 wks');
    expect(
      petAgeLabel(_now.subtract(const Duration(days: 150)), _now),
      '4 months',
    );
    expect(petAgeLabel(_now.subtract(const Duration(days: 370)), _now), '1 yr');
    expect(
      petAgeLabel(_now.subtract(const Duration(days: 800)), _now),
      '2 yrs',
    );
    expect(petAgeLabel(_now.add(const Duration(days: 2)), _now), '');
  });

  test('the list line and price', () {
    final duke = AdoptListing(
      id: 'l',
      kind: ListingKind.sale,
      priceKobo: 45000000,
      petId: 'p',
      petName: 'Duke',
      species: 'dog',
      breed: 'Boerboel',
      sex: 'male',
      bornOn: _now.subtract(const Duration(days: 63)),
      partnerId: 'x',
      partnerName: 'Royal Paws Kennels',
    );
    expect(listingLine(duke, _now), 'Boerboel · 9 wks · M');
    expect(listingPrice(duke), '₦450,000');
    const ada = AdoptListing(
      id: 'l',
      kind: ListingKind.adoption,
      petId: 'p',
      petName: 'Ada',
      species: 'dog',
      partnerId: 'x',
      partnerName: 'Lagos Paws Rescue',
    );
    expect(listingPrice(ada), 'Adopt · free');
    expect(listingLine(ada, _now), '');
  });

  group('the four steps', () {
    test('nothing paid: the first step is next', () {
      expect(
        _states(_o(status: OrderStatus.pendingDeposit, depositPaid: false)),
        [StepStatus.current, StepStatus.todo, StepStatus.todo, StepStatus.todo],
      );
    });

    test('deposit paid or balance paid: pick up is next', () {
      for (final s in [OrderStatus.depositPaid, OrderStatus.balancePaid]) {
        expect(_states(_o(status: s)), [
          StepStatus.done,
          StepStatus.current,
          StepStatus.todo,
          StepStatus.todo,
        ]);
      }
    });

    test('handed over or disputed: the vet check is running', () {
      for (final s in [OrderStatus.handedOver, OrderStatus.disputed]) {
        expect(
          _states(_o(status: s, ends: _now.add(const Duration(hours: 10)))),
          [
            StepStatus.done,
            StepStatus.done,
            StepStatus.current,
            StepStatus.todo,
          ],
        );
      }
    });

    test('complete: all four are done', () {
      expect(
        _states(_o(status: OrderStatus.completed)),
        List.filled(4, StepStatus.done),
      );
    });

    test('cancelled: nothing is current', () {
      expect(
        _states(_o(status: OrderStatus.cancelled)).contains(StepStatus.current),
        isFalse,
      );
      expect(
        _states(_o(status: OrderStatus.cancelled, depositPaid: false)),
        List.filled(4, StepStatus.todo),
      );
    });
  });

  test('hours left count up and stop at zero', () {
    expect(hoursLeft(null, _now), 0);
    expect(
      hoursLeft(_now.add(const Duration(hours: 71, minutes: 30)), _now),
      72,
    );
    expect(hoursLeft(_now.add(const Duration(minutes: 1)), _now), 1);
    expect(hoursLeft(_now.subtract(const Duration(hours: 1)), _now), 0);
  });

  group('what the buyer can do', () {
    test('after the deposit: pay the balance', () {
      expect(buyerActions(_o(), _now), [BuyerAction.payBalance]);
    });

    test('nothing while waiting for the seller to hand over', () {
      expect(
        buyerActions(
          _o(status: OrderStatus.balancePaid, balancePaid: true),
          _now,
        ),
        isEmpty,
      );
    });

    test('after the handover: accept the passport and report a problem, inside the window', () {
      final o = _o(
        status: OrderStatus.handedOver,
        balancePaid: true,
        ends: _now.add(const Duration(hours: 50)),
        transferId: 't',
      );
      expect(buyerActions(o, _now), [
        BuyerAction.acceptPassport,
        BuyerAction.reportProblem,
      ]);
    });

    test(
      'once accepted only the report remains, and after the window nothing',
      () {
        final accepted = _o(
          status: OrderStatus.handedOver,
          ends: _now.add(const Duration(hours: 50)),
          transferId: 't',
          transferCompleted: true,
        );
        expect(buyerActions(accepted, _now), [BuyerAction.reportProblem]);
        final late = _o(
          status: OrderStatus.handedOver,
          ends: _now.subtract(const Duration(hours: 1)),
          transferId: 't',
          transferCompleted: true,
        );
        expect(buyerActions(late, _now), isEmpty);
      },
    );

    test('sellers and finished orders get no buyer actions', () {
      expect(buyerActions(_o(isBuyer: false), _now), isEmpty);
      expect(buyerActions(_o(status: OrderStatus.completed), _now), isEmpty);
      expect(
        buyerActions(
          _o(
            status: OrderStatus.disputed,
            ends: _now.add(const Duration(hours: 5)),
          ),
          _now,
        ),
        isEmpty,
      );
    });
  });

  test('plain sentences for where an order stands', () {
    expect(
      orderHeadline(
        _o(status: OrderStatus.pendingDeposit, depositPaid: false),
        _now,
      ),
      'Waiting for your deposit',
    );
    expect(orderHeadline(_o(), _now), 'Deposit paid. Arrange the pick up.');
    expect(
      orderHeadline(_o(isBuyer: false), _now),
      'Deposit paid. Arrange the handover.',
    );
    expect(
      orderHeadline(
        _o(
          status: OrderStatus.handedOver,
          ends: _now.add(const Duration(hours: 71, minutes: 1)),
        ),
        _now,
      ),
      'Vet check window: 72 hours left',
    );
    expect(
      orderHeadline(
        _o(
          status: OrderStatus.handedOver,
          ends: _now.subtract(const Duration(hours: 1)),
        ),
        _now,
      ),
      'The vet check window has ended',
    );
    expect(
      orderHeadline(_o(status: OrderStatus.disputed), _now),
      'Problem reported. The payment is on hold.',
    );
    expect(
      orderHeadline(_o(status: OrderStatus.completed), _now),
      'Complete. Duke is home.',
    );
    expect(
      orderHeadline(_o(status: OrderStatus.cancelled), _now),
      'Cancelled. You are refunded in full.',
    );
  });

  test('application labels', () {
    expect(applicationLabel('submitted'), 'Application sent');
    expect(applicationLabel('home_visit'), 'Home visit planned');
    expect(applicationLabel('approved'), 'Approved');
    expect(applicationLabel('declined'), 'Not this time');
  });

  test('the adoption form sends clean answers', () {
    const a = AdoptionAnswers(
      homeType: HomeType.house,
      why: '  Calm home  ',
      agreeVisit: true,
      daytime: ' I work from home ',
    );
    expect(a.toJson(), {
      'home_type': 'house',
      'other_pets': '',
      'daytime': 'I work from home',
      'why': 'Calm home',
      'agree_visit': true,
    });
  });
}
