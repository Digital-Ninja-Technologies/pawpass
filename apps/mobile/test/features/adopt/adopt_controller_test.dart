import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/adopt/data/in_memory_adopt.dart';
import 'package:pawpass/features/adopt/domain/models.dart';
import 'package:pawpass/features/adopt/state/adopt_controller.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/booking/domain/models.dart';
import 'package:pawpass/features/booking/state/booking_controller.dart'
    show PayStage;
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/state/session_controller.dart';

final _today = DateTime.utc(2026, 11, 5, 8);

class _Rig {
  _Rig() {
    services = inMemoryServices(
      now: () => _today,
      signedInAs: 'tolu@example.com',
    );
    repo = services.adopt as InMemoryAdoptRepository;
    payments = services.payments as InMemoryPaymentsRepository;
    session = SessionController(services);
    c = AdoptController(services, session);
  }

  late final AppServices services;
  late final InMemoryAdoptRepository repo;
  late final InMemoryPaymentsRepository payments;
  late final SessionController session;
  late final AdoptController c;

  /// Pays the deposit for Duke and comes back: returns the order id.
  Future<String> deposit() async {
    await c.payDeposit('l-duke');
    await c.checkPayment();
    return c.paidOrderId!;
  }

  Future<String> balance(String order) async {
    await c.payBalance(order);
    await c.checkPayment();
    return order;
  }
}

void main() {
  group('browsing', () {
    test('breeders and shelters are separate lists, with species and search filters', () async {
      final r = _Rig();
      await r.c.load();
      expect(r.c.listings.map((l) => l.petName), ['Duke', 'Nala']);
      await r.c.setKind(ListingKind.adoption);
      expect(r.c.listings.map((l) => l.petName), ['Ada', 'Mia']);
      await r.c.setSpecies('cat');
      expect(r.c.listings.map((l) => l.petName), ['Mia']);
      await r.c.setSpecies(null);
      await r.c.search('lagos');
      expect(r.c.listings.length, 2, reason: 'seller names are searched');
      await r.c.search('zzz');
      expect(r.c.listings, isEmpty);
    });

    test('a load failure is kept and can be retried', () async {
      final r = _Rig();
      r.repo.failNextLoad = const AppFailure('No connection.');
      await r.c.load();
      expect(r.c.error, 'No connection.');
      await r.c.load();
      expect(r.c.error, isNull);
      expect(r.c.listings, isNotEmpty);
    });

    test('the listing shows the money, the parents and the records', () async {
      final r = _Rig();
      await r.c.openListing('l-duke');
      final d = r.c.detail!;
      expect(d.depositKobo, 15000000);
      expect(d.protectionFeeKobo, 750000);
      expect(d.dueTodayKobo, 15750000);
      expect(d.balanceKobo, 30000000);
      expect(d.motherName, 'Bella');
      expect(d.fatherName, 'Max');
      expect(d.records.where((x) => x.verified).length, 2);
      expect(d.available, isTrue);
    });
  });

  group('paying the deposit', () {
    test(
      'opens Paystack with the deposit plus protection fee and waits',
      () async {
        final r = _Rig();
        await r.c.payDeposit('l-duke');
        expect(r.c.stage, PayStage.waiting);
        expect(r.c.payment!.amountKobo, 15750000);
        expect(r.payments.started.single, startsWith('pd_'));
        expect(
          (r.services.links as FakeLinkLauncher).opened.single.host,
          'checkout.paystack.com',
        );
      },
    );

    test('confirmed: the order exists, the pet is reserved for you, others cannot order it', () async {
      final r = _Rig();
      final id = await r.deposit();
      expect(r.c.stage, PayStage.idle);
      expect(r.c.activeOrders.single.id, id);
      expect(r.c.activeOrders.single.status, OrderStatus.depositPaid);
      await r.c.load();
      expect(
        r.c.listings.firstWhere((l) => l.petName == 'Duke').reserved,
        isTrue,
      );
      await r.c.payDeposit('l-duke');
      expect(r.c.payError, 'This pet is no longer available');
    });

    test(
      'not paid yet keeps waiting, a failed payment says nothing was charged',
      () async {
        final r = _Rig();
        r.payments.outcome = PaymentOutcome.pending;
        await r.c.payDeposit('l-duke');
        await r.c.checkPayment();
        expect(r.c.payNotice, contains('not received your payment yet'));
        expect(r.c.stage, PayStage.waiting);
        r.payments.outcome = PaymentOutcome.failed;
        await r.c.checkPayment();
        expect(r.c.stage, PayStage.idle);
        expect(r.c.payError, contains('not been charged'));
      },
    );

    test(
      'giving up drops the unpaid order, so another try starts fresh',
      () async {
        final r = _Rig();
        await r.c.payDeposit('l-duke');
        final first = r.c.payment!.reference;
        await r.c.abandonPayment();
        expect(r.c.stage, PayStage.idle);
        await r.c.payDeposit('l-duke');
        expect(r.c.payment!.reference, isNot(first));
      },
    );

    test('a payment page that fails to open can be retried', () async {
      final r = _Rig();
      r.payments.failNextStart = const AppFailure('Paystack is down.');
      await r.c.payDeposit('l-duke');
      expect(r.c.payError, 'Paystack is down.');
      await r.c.payDeposit('l-duke');
      expect(r.c.stage, PayStage.waiting);
    });

    test('an adoption cannot be bought', () async {
      final r = _Rig();
      await r.c.payDeposit('l-ada');
      expect(r.c.payError, 'This pet is not for sale');
    });
  });

  group('the order', () {
    test(
      'balance, handover, then accepting the passport makes the pet yours',
      () async {
        final r = _Rig();
        final id = await r.deposit();
        await r.c.openOrder(id);
        expect(r.c.order!.status, OrderStatus.depositPaid);
        await r.balance(id);
        await r.c.openOrder(id);
        expect(r.c.order!.status, OrderStatus.balancePaid);
        r.repo.sellerConfirmHandover(id);
        await r.c.openOrder(id);
        final o = r.c.order!;
        expect(o.status, OrderStatus.handedOver);
        expect(o.transferId, isNotNull);

        expect(await r.c.acceptPassport(o.transferId!), isTrue);
        expect(r.c.order!.transferCompleted, isTrue);
        expect(
          (await r.services.pets.myPets()).map((p) => p.name),
          contains('Duke'),
        );
        expect(await r.c.acceptPassport(o.transferId!), isFalse);
        expect(r.c.acceptError, 'This passport has already been accepted');
      },
    );

    test('the balance can only be paid after the deposit', () async {
      final r = _Rig();
      await r.c.payDeposit('l-duke');
      final orderId = r.c.payment!.orderId;
      await r.c.abandonPayment();
      await r.c.payBalance(orderId);
      expect(
        r.c.payError,
        contains('balance can be paid once the deposit is in'),
      );
    });

    test('a problem in the window holds the money; after the window it cannot be reported', () async {
      final r = _Rig();
      final id = await r.balance(await r.deposit());
      r.repo.sellerConfirmHandover(id);
      expect(
        await r.c.reportProblem(
          id,
          OrderProblem.healthProblem,
          details: 'The vet found parvo.',
        ),
        isTrue,
      );
      expect(r.c.order!.status, OrderStatus.disputed);
      expect(r.repo.problems.single.reason, OrderProblem.healthProblem);
      expect(await r.c.acceptPassport(r.c.order!.transferId!), isFalse);
      expect(r.c.acceptError, 'A problem report is open for this order');
    });

    test('a problem before the handover is refused with the reason', () async {
      final r = _Rig();
      final id = await r.deposit();
      expect(await r.c.reportProblem(id, OrderProblem.other), isFalse);
      expect(r.c.problemError, contains('after the handover'));
    });

    test(
      'the seller cancelling refunds and puts the pet back on the market',
      () async {
        final r = _Rig();
        final id = await r.deposit();
        r.repo.sellerCancel(id);
        await r.c.openOrder(id);
        expect(r.c.order!.status, OrderStatus.cancelled);
        await r.c.load();
        expect(
          r.c.listings.firstWhere((l) => l.petName == 'Duke').reserved,
          isFalse,
        );
      },
    );

    test('when the window ends with no problem the order completes', () async {
      final r = _Rig();
      final id = await r.balance(await r.deposit());
      r.repo.sellerConfirmHandover(id);
      r.repo.endVetWindow(id);
      await r.c.openOrder(id);
      expect(r.c.order!.status, OrderStatus.completed);
      expect(
        (await r.services.pets.myPets()).map((p) => p.name),
        contains('Duke'),
      );
    });
  });

  group('adoption', () {
    AdoptionAnswers good() => const AdoptionAnswers(
      homeType: HomeType.house,
      why: 'Bingo needs a calm companion and Ada looks perfect.',
      agreeVisit: true,
      daytime: 'I work from home',
    );

    test('applying shows the status on the listing and in the list', () async {
      final r = _Rig();
      expect(await r.c.apply('l-ada', good()), isTrue);
      expect(r.c.detail!.myApplicationStatus, 'submitted');
      expect(r.c.activeApplications.single.petName, 'Ada');
    });

    test('rules are explained', () async {
      final r = _Rig();
      expect(
        await r.c.apply(
          'l-ada',
          const AdoptionAnswers(
            homeType: HomeType.flat,
            why: 'short',
            agreeVisit: true,
          ),
        ),
        isFalse,
      );
      expect(r.c.applyError, contains('at least 10 characters'));
      expect(
        await r.c.apply(
          'l-ada',
          const AdoptionAnswers(
            homeType: HomeType.flat,
            why: 'A long enough reason to adopt',
            agreeVisit: false,
          ),
        ),
        isFalse,
      );
      expect(r.c.applyError, contains('home visit or video call'));
      await r.c.apply('l-ada', good());
      expect(await r.c.apply('l-ada', good()), isFalse);
      expect(r.c.applyError, 'You have already applied for this pet');
    });

    test('a sale listing takes no application', () async {
      final r = _Rig();
      expect(await r.c.apply('l-duke', good()), isFalse);
      expect(r.c.applyError, 'This pet is no longer open for adoption');
    });

    test(
      'once the shelter hands over, the adopter accepts the passport',
      () async {
        final r = _Rig();
        await r.c.apply('l-ada', good());
        final app = r.c.applications.firstWhere((a) => a.petName == 'Ada');
        r.repo.shelterHandOver(app.id);
        await r.c.load();
        final withTransfer = r.c.applications.firstWhere(
          (a) => a.petName == 'Ada',
        );
        expect(withTransfer.transferId, isNotNull);
        await r.c.openTransfer(withTransfer.transferId!);
        expect(r.c.transfer!.kind, ListingKind.adoption);
        expect(r.c.transfer!.completedAt, isNull);
        expect(await r.c.acceptPassport(withTransfer.transferId!), isTrue);
        expect(r.c.transfer!.completedAt, isNotNull);
        expect(
          (await r.services.pets.myPets()).map((p) => p.name),
          contains('Ada'),
        );
      },
    );
  });

  test('chat with the seller', () async {
    final r = _Rig();
    expect(await r.c.openChat('l-duke'), 'conv-l-duke');
    expect(r.repo.chats, ['l-duke']);
  });

  test('signing out forgets everything', () async {
    final r = _Rig();
    await r.deposit();
    r.c.reset();
    expect(r.c.listings, isEmpty);
    expect(r.c.orders, isEmpty);
    expect(r.c.loaded, isFalse);
  });
}
