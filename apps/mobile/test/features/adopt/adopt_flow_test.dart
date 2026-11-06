import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/adopt/data/in_memory_adopt.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/booking/domain/models.dart';
import 'package:pawpass/features/community/data/in_memory_community.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/ui/ui.dart';

final _today = DateTime.utc(2026, 11, 5, 8);

class _Rig {
  _Rig() {
    profiles = InMemoryProfileRepository();
    pets = InMemoryPetRepository(profiles: profiles, now: () => _today);
    bookings = InMemoryBookingsRepository(now: () => _today);
    adopt = InMemoryAdoptRepository(
      now: () => _today,
      onPassport: (name, species, breed) {
        pets.createPassport(
          pet: PetInput(
            name: name,
            species: Species.values.firstWhere(
              (s) => s.value == species,
              orElse: () => Species.other,
            ),
            breed: breed,
            sex: PetSex.unknown,
          ),
          records: const [],
          channels: {ReminderChannel.push},
        );
      },
    );
    payments = InMemoryPaymentsRepository(bookings, others: [adopt.markPaid]);
    links = FakeLinkLauncher();
    services = AppServices(
      auth: InMemoryAuthRepository(signedInAs: 'tolu@example.com'),
      profiles: profiles,
      pets: pets,
      photos: NoPhotoPicker(),
      emailApp: NoEmailApp(),
      health: InMemoryHealthRepository(now: () => _today),
      notifications: InMemoryNotificationsRepository(),
      vets: InMemoryVetsRepository(),
      location: FakeLocationService(),
      links: links,
      bookings: bookings,
      payments: payments,
      community: InMemoryCommunityRepository(now: () => _today),
      adopt: adopt,
      now: () => _today,
    );
  }

  late final InMemoryProfileRepository profiles;
  late final InMemoryPetRepository pets;
  late final InMemoryBookingsRepository bookings;
  late final InMemoryAdoptRepository adopt;
  late final InMemoryPaymentsRepository payments;
  late final FakeLinkLauncher links;
  late final AppServices services;

  Future<void> seed() async {
    await profiles.save(firstName: 'Tolu', lastName: 'Adeyemi', area: 'Lekki');
    profiles.markOnboarded(_today);
    for (final n in ['Bingo', 'Mimi']) {
      await pets.createPassport(
        pet: PetInput(
          name: n,
          species: n == 'Bingo' ? Species.dog : Species.cat,
          breed: n == 'Bingo' ? 'Boerboel' : 'Tabby',
          sex: PetSex.male,
          dateOfBirth: DateTime(2024, 8, 14),
        ),
        records: const [],
        channels: {ReminderChannel.push},
      );
    }
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Rig rig, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  await rig.seed();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: PawPassApp(services: rig.services),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text, {bool last = false}) async {
  expect(
    find.text(text),
    findsWidgets,
    reason: 'Could not find "$text" on screen',
  );
  final f = last ? find.text(text).last : find.text(text).first;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(PawBackButton).first);
  await tester.pumpAndSettle();
}

Future<void> _toAdopt(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(PawTabBar), matching: find.text('Adopt')),
  );
  await tester.pumpAndSettle();
}

Future<void> _refresh(WidgetTester tester) async {
  await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    120,
    scrollable: find.byType(Scrollable).first,
  );
}

/// Pays the deposit on Duke through the screens and lands on the order.
Future<void> _payDeposit(WidgetTester tester) async {
  await _toAdopt(tester);
  await _tap(tester, 'Duke');
  await _tap(tester, 'Pay deposit safely');
  await _tap(tester, 'Pay ₦157,500 into escrow');
  await _tap(tester, "I've paid");
}

void main() {
  group('Find a pet', () {
    testWidgets('lists breeders first, with age, price and who sells', (
      tester,
    ) async {
      await _pump(tester, _Rig());
      await _toAdopt(tester);
      expect(find.text('Find a pet'), findsWidgets);
      expect(
        find.text(
          'Every pet here comes with a verified passport, and payments are held in escrow.',
        ),
        findsOneWidget,
      );
      expect(find.text('Duke'), findsOneWidget);
      expect(find.text('Boerboel · 9 wks · M'), findsOneWidget);
      expect(find.text('₦450,000'), findsOneWidget);
      expect(find.text('✓ Royal Paws Kennels'), findsOneWidget);
      expect(find.text('Nala'), findsOneWidget);
      expect(find.text('Ada'), findsNothing);
    });

    testWidgets('shelters list adoptions, free', (tester) async {
      await _pump(tester, _Rig());
      await _toAdopt(tester);
      await _tap(tester, 'Shelters & rescue');
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Adopt · free'), findsWidgets);
      expect(find.text('Duke'), findsNothing);
      await _tap(tester, 'Cats');
      expect(find.text('Mia'), findsOneWidget);
      expect(find.text('Ada'), findsNothing);
    });

    testWidgets('a load failure offers to try again', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      rig.adopt.failNextLoad = const AppFailure(
        'No connection. Check your internet and try again.',
      );
      await _toAdopt(tester);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      await _tap(tester, 'Try again');
      expect(find.text('Duke'), findsOneWidget);
    });
  });

  group('A listing', () {
    testWidgets(
      'shows the seller, what transfers and how escrow protects you',
      (tester) async {
        await _pump(tester, _Rig());
        await _toAdopt(tester);
        await _tap(tester, 'Duke');
        expect(find.text('Verified puppy listing'), findsOneWidget);
        expect(find.text('Royal Paws Kennels'), findsOneWidget);
        expect(
          find.text('ID, facility and vet reference checked'),
          findsOneWidget,
        );
        expect(find.text("DUKE'S PASSPORT"), findsOneWidget);
        expect(find.text('Max × Bella (both registered)'), findsOneWidget);
        expect(find.textContaining('DHPP'), findsOneWidget);
        expect(find.textContaining('✓ vet'), findsWidgets);
        await _reveal(tester, 'PROTECTED BY ESCROW');
        expect(find.text('Pay deposit'), findsOneWidget);
        expect(find.text('Meet & pick up'), findsOneWidget);
        expect(find.text('72-hr vet check'), findsOneWidget);
        expect(find.text('Seller paid'), findsOneWidget);
        expect(find.text('Message'), findsOneWidget);
        expect(find.text('Pay deposit safely'), findsOneWidget);
      },
    );

    testWidgets('Message opens a chat with the seller', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toAdopt(tester);
      await _tap(tester, 'Duke');
      await _tap(tester, 'Message');
      expect(rig.adopt.chats, ['l-duke']);
    });
  });

  group('Pay deposit', () {
    testWidgets(
      'shows the sums: a third, a small protection fee, and the balance later',
      (tester) async {
        await _pump(tester, _Rig());
        await _toAdopt(tester);
        await _tap(tester, 'Duke');
        await _tap(tester, 'Pay deposit safely');
        expect(find.text('Pay deposit'), findsWidgets);
        expect(find.text('Puppy price'), findsOneWidget);
        expect(find.text('₦450,000'), findsOneWidget);
        expect(find.text('Deposit now (⅓)'), findsOneWidget);
        expect(find.text('₦150,000'), findsOneWidget);
        expect(find.text('Escrow protection fee'), findsOneWidget);
        expect(find.text('₦7,500'), findsOneWidget);
        expect(find.text('Pay today'), findsOneWidget);
        expect(find.text('₦157,500'), findsOneWidget);
        expect(
          find.text(
            'Balance of ₦300,000 is paid at handover, also held in escrow.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Full refund if the seller cancels'),
          findsOneWidget,
        );
        expect(find.text('Pay ₦157,500 into escrow'), findsOneWidget);
      },
    );

    testWidgets('pay, come back, land on the order with the deposit in', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toAdopt(tester);
      await _tap(tester, 'Duke');
      await _tap(tester, 'Pay deposit safely');
      await _tap(tester, 'Pay ₦157,500 into escrow');
      expect(rig.links.opened.single.host, 'checkout.paystack.com');
      expect(
        find.textContaining('Finish paying on the Paystack page'),
        findsOneWidget,
      );
      await _tap(tester, "I've paid");
      expect(find.text('Passport transfer and escrow'), findsOneWidget);
      expect(find.text('Deposit paid. Arrange the pick up.'), findsOneWidget);
      expect(find.text('Deposit paid · ₦157,500'), findsOneWidget);
      expect(find.text('Pay balance ₦300,000'), findsOneWidget);
    });

    testWidgets(
      'cancelling the payment returns to the form, and a pending payment keeps waiting',
      (tester) async {
        final rig = _Rig()..payments.outcome = PaymentOutcome.pending;
        await _pump(tester, rig);
        await _toAdopt(tester);
        await _tap(tester, 'Duke');
        await _tap(tester, 'Pay deposit safely');
        await _tap(tester, 'Pay ₦157,500 into escrow');
        await _tap(tester, "I've paid");
        expect(
          find.textContaining('not received your payment yet'),
          findsOneWidget,
        );
        await _tap(tester, 'Cancel this order');
        expect(find.text('Pay ₦157,500 into escrow'), findsOneWidget);
      },
    );

    testWidgets(
      'after paying, the listing offers your order instead of another payment',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        await _payDeposit(tester);
        await _back(tester);
        expect(find.text('Verified puppy listing'), findsOneWidget);
        expect(find.text('Pay deposit safely'), findsNothing);
        await _tap(tester, 'View your order');
        expect(find.text('Passport transfer and escrow'), findsOneWidget);
      },
    );
  });

  group('The order', () {
    testWidgets(
      'balance, handover, accept the passport: the pet becomes yours',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        await _payDeposit(tester);
        await _tap(tester, 'Pay balance ₦300,000');
        await _tap(tester, "I've paid");
        expect(
          find.text('Balance paid. Waiting for the handover.'),
          findsOneWidget,
        );
        expect(find.text('Accept passport'), findsNothing);

        final id = (await rig.adopt.orders()).single.id;
        rig.adopt.sellerConfirmHandover(id);
        await _refresh(tester);
        expect(find.text('Duke is coming home'), findsOneWidget);
        expect(find.text('Vet check window: 72 hours left'), findsOneWidget);
        expect(find.text('Accept passport'), findsOneWidget);
        expect(find.text('Report a problem'), findsOneWidget);

        await _tap(tester, 'Accept passport');
        expect(find.text("Duke's passport is yours."), findsOneWidget);
        expect(find.text('Duke is home'), findsOneWidget);
        expect((await rig.pets.myPets()).map((p) => p.name), contains('Duke'));
      },
    );

    testWidgets('reporting a problem inside the window holds the payment', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _payDeposit(tester);
      await _tap(tester, 'Pay balance ₦300,000');
      await _tap(tester, "I've paid");
      rig.adopt.sellerConfirmHandover((await rig.adopt.orders()).single.id);
      await _refresh(tester);
      await _tap(tester, 'Report a problem');
      PawButton send() => tester.widget<PawButton>(
        find.widgetWithText(PawButton, 'Send to PawPass'),
      );
      expect(send().onPressed, isNull);
      await _tap(tester, 'A vet found a health problem');
      await tester.enterText(find.byType(TextField), 'The vet found parvo.');
      await _tap(tester, 'Send to PawPass');
      expect(
        find.text('Problem reported. The payment is on hold.'),
        findsOneWidget,
      );
      expect(find.text('Accept passport'), findsNothing);
      expect(rig.adopt.problems.single.details, 'The vet found parvo.');
    });

    testWidgets('the seller cancelling shows a full refund', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _payDeposit(tester);
      rig.adopt.sellerCancel((await rig.adopt.orders()).single.id);
      await _refresh(tester);
      expect(find.text('Cancelled. You are refunded in full.'), findsOneWidget);
      expect(find.text('Pay balance ₦300,000'), findsNothing);
    });

    testWidgets('the Adopt tab shows your pet on the way', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _payDeposit(tester);
      await _back(tester);
      await _back(tester);
      await _toAdopt(tester);
      expect(find.text('YOUR PETS ON THE WAY'), findsOneWidget);
      expect(find.text('Deposit paid · Royal Paws Kennels'), findsOneWidget);
      await _tap(tester, 'Deposit paid · Royal Paws Kennels');
      expect(find.text('Passport transfer and escrow'), findsOneWidget);
    });
  });

  group('Adoption', () {
    testWidgets('apply, then wait for the shelter, then accept the passport', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toAdopt(tester);
      await _tap(tester, 'Shelters & rescue');
      await _tap(tester, 'Ada');
      expect(find.text('Adoption listing'), findsOneWidget);
      expect(find.text('How adoption works'.toUpperCase()), findsOneWidget);
      await _tap(tester, 'Apply to adopt');
      expect(find.text('Apply to adopt Ada'), findsOneWidget);
      expect(
        find.text('Bingo and Mimi, shared from their passports'),
        findsOneWidget,
      );
      PawButton send() => tester.widget<PawButton>(
        find.widgetWithText(PawButton, 'Send application'),
      );
      expect(send().onPressed, isNull);
      await _tap(tester, 'House with compound');
      await tester.enterText(find.byType(TextField).at(0), 'I work from home');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Bingo needs a calm companion and Ada looks perfect.',
      );
      await tester.pump();
      expect(send().onPressed, isNull, reason: 'the home visit must be agreed');
      await _tap(
        tester,
        'I agree to a short home visit or video call with the shelter',
      );
      expect(send().onPressed, isNotNull);
      await _tap(tester, 'Send application');
      expect(
        find.text('Application sent. The shelter will be in touch.'),
        findsOneWidget,
      );
      expect(find.text('Application sent'), findsOneWidget);

      final app = (await rig.adopt.applications()).single;
      rig.adopt.shelterHandOver(app.id);
      await _back(tester);
      await _toAdopt(tester);
      await _refresh(tester);
      expect(find.text('Approved · Lagos Paws Rescue'), findsOneWidget);
      await _tap(tester, 'Approved · Lagos Paws Rescue');
      expect(find.text('Ada is coming home'), findsOneWidget);
      expect(
        find.text(
          'Lagos Paws Rescue keeps a read-only record of the transfer.',
        ),
        findsOneWidget,
      );
      await _tap(tester, 'Accept passport');
      expect(find.text('Ada is home'), findsOneWidget);
      expect((await rig.pets.myPets()).map((p) => p.name), contains('Ada'));
    });

    testWidgets('a rule the server enforces is explained', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _toAdopt(tester);
      await _tap(tester, 'Shelters & rescue');
      await _tap(tester, 'Ada');
      await _tap(tester, 'Apply to adopt');
      await _tap(tester, 'Flat or apartment');
      await tester.enterText(
        find.byType(TextField).at(1),
        'A quiet flat and plenty of time.',
      );
      await _tap(
        tester,
        'I agree to a short home visit or video call with the shelter',
      );
      rig.adopt.failNextApply = const AppFailure(
        'No connection. Check your internet and try again.',
      );
      await _tap(tester, 'Send application');
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      await _tap(tester, 'Send application');
      expect(
        find.text('Application sent. The shelter will be in touch.'),
        findsOneWidget,
      );
    });
  });

  group('every screen fits a small phone with large text', () {
    testWidgets(
      'Find a pet, Listing, Pay deposit, waiting, Order, Report, Apply, Transfer',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig, size: const Size(320, 568), scale: 1.3);
        await _toAdopt(tester);
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Duke');
        expect(tester.takeException(), isNull);
        await _reveal(tester, 'PROTECTED BY ESCROW');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Pay deposit safely');
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Pay ₦157,500 into escrow');
        expect(tester.takeException(), isNull);
        await _tap(tester, "I've paid");
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Pay balance ₦300,000');
        expect(tester.takeException(), isNull);
        await _tap(tester, "I've paid");
        rig.adopt.sellerConfirmHandover((await rig.adopt.orders()).single.id);
        await _refresh(tester);
        expect(tester.takeException(), isNull);
        await _tap(tester, 'Report a problem');
        await _tap(tester, 'Something else');
        expect(tester.takeException(), isNull);
        // Back to the Adopt tab, however many screens deep (scrolling each screen to its top first).
        for (var i = 0; i < 6; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 900),
          );
          await tester.pumpAndSettle();
          if (find.byType(PawBackButton).evaluate().isEmpty) {
            break;
          }
          await _back(tester);
        }
        await _reveal(tester, 'Shelters & rescue');
        await _tap(tester, 'Shelters & rescue');
        await _tap(tester, 'Ada');
        await _tap(tester, 'Apply to adopt');
        expect(tester.takeException(), isNull);
        await _reveal(tester, 'Send application');
        expect(tester.takeException(), isNull);
      },
    );
  });
}
