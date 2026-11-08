import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/account/data/in_memory_account.dart';
import 'package:pawpass/features/account/domain/models.dart';
import 'package:pawpass/features/account/state/delete_account_controller.dart';
import 'package:pawpass/features/adopt/data/in_memory_adopt.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/community/data/in_memory_community.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/health/domain/models.dart' show ShareScope;
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/partner/data/in_memory_partner.dart';
import 'package:pawpass/ui/ui.dart';

final _today = DateTime.utc(2026, 11, 5, 8);

class _Rig {
  _Rig() {
    profiles = InMemoryProfileRepository();
    pets = InMemoryPetRepository(profiles: profiles, now: () => _today);
    bookings = InMemoryBookingsRepository(now: () => _today);
    adopt = InMemoryAdoptRepository(now: () => _today);
    health = InMemoryHealthRepository(now: () => _today);
    links = FakeLinkLauncher();
    account = InMemoryAccountRepository(
      now: () => _today,
      petName: (id) {
        for (final p in pets.pets) {
          if (p.id == id) return p.name;
        }
        return null;
      },
    );
    partner = InMemoryPartnerRepository(now: () => _today);
    services = AppServices(
      auth: InMemoryAuthRepository(signedInAs: 'tolu@example.com'),
      profiles: profiles,
      pets: pets,
      photos: NoPhotoPicker(),
      emailApp: NoEmailApp(),
      health: health,
      notifications: InMemoryNotificationsRepository(),
      vets: InMemoryVetsRepository(),
      location: FakeLocationService(),
      links: links,
      bookings: bookings,
      payments: InMemoryPaymentsRepository(
        bookings,
        others: [adopt.markPaid, account.markPaid],
      ),
      community: InMemoryCommunityRepository(now: () => _today),
      adopt: adopt,
      partner: partner,
      account: account,
      now: () => _today,
    );
  }

  late final InMemoryProfileRepository profiles;
  late final InMemoryPetRepository pets;
  late final InMemoryBookingsRepository bookings;
  late final InMemoryAdoptRepository adopt;
  late final InMemoryHealthRepository health;
  late final FakeLinkLauncher links;
  late final InMemoryAccountRepository account;
  late final InMemoryPartnerRepository partner;
  late final AppServices services;

  Future<void> seed() async {
    await profiles.save(firstName: 'Tolu', lastName: 'Adeyemi', area: 'Lekki');
    profiles.markOnboarded(_today);
    await pets.createPassport(
      pet: PetInput(
        name: 'Bingo',
        species: Species.dog,
        breed: 'Boerboel',
        sex: PetSex.male,
        dateOfBirth: DateTime(2024, 8, 14),
      ),
      records: const [],
      channels: {ReminderChannel.push},
    );
  }
}

Future<void> _pump(WidgetTester tester, _Rig rig) async {
  await rig.seed();
  const size = Size(390, 844);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: size),
      child: PawPassApp(services: rig.services),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> _openMe(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Your account').first);
  await tester.pumpAndSettle();
}

void main() {
  group('QR tag order', () {
    testWidgets('asks for an address, pays on Paystack, then confirms', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'QR tags');
      expect(find.text('Order a QR tag'), findsOneWidget);
      expect(find.text('Pay ₦4,500 with Paystack'), findsOneWidget);

      // Nothing is ordered until the address is filled in.
      await _tap(tester, 'Pay ₦4,500 with Paystack');
      expect(find.text('Enter the street address.'), findsOneWidget);
      expect(rig.account.orders, isEmpty);

      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(PawTextField, 'Street address'),
          matching: find.byType(TextField),
        ),
        '14 Admiralty Way',
      );
      await tester.pump();
      await _tap(tester, 'Pay ₦4,500 with Paystack');
      expect(rig.account.orders.single.status, TagOrderStatus.pendingPayment);
      expect(rig.links.opened.single.toString(), contains('pt_'));
      expect(find.text('I have paid, check now'), findsOneWidget);

      await _tap(tester, 'I have paid, check now');
      expect(find.text('Tag ordered'), findsOneWidget);
      expect(rig.account.orders.single.status, TagOrderStatus.paid);
    });

    testWidgets('the price comes from settings', (tester) async {
      final rig = _Rig();
      rig.account.prices = const TagPrices(
        priceKobo: 500000,
        deliveryKobo: 150000,
      );
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'QR tags');
      expect(find.text('Pay ₦6,500 with Paystack'), findsOneWidget);
    });

    testWidgets('a price that cannot load says so and can be retried', (
      tester,
    ) async {
      final rig = _Rig();
      rig.account.failNext = const AppFailure('No connection.');
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'QR tags');
      expect(find.text('We could not load the price'), findsOneWidget);
      await _tap(tester, 'Try again');
      expect(find.text('Pay ₦4,500 with Paystack'), findsOneWidget);
    });
  });

  group('Privacy & sharing', () {
    testWidgets('shows what is shared and stopping it ends the share', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      final pet = (await rig.pets.myPets()).single;
      final link = await rig.health.createShare(
        petId: pet.id,
        scopes: {ShareScope.health},
        hours: 2,
      );
      rig.account.shares = [
        ActiveShare(
          id: link.id,
          petId: pet.id,
          petName: 'Bingo',
          scopes: {ShareScope.health},
          expiresAt: link.expiresAt,
        ),
      ];
      await _openMe(tester);
      await _tap(tester, 'Privacy & sharing');
      expect(find.text('Link or QR code'), findsOneWidget);
      expect(find.textContaining('read only'), findsOneWidget);
      await _tap(tester, 'Stop sharing');
      expect(find.text('Link or QR code'), findsNothing);
      expect(rig.health.shares.single.revoked, isTrue);
    });

    testWidgets('nothing shared and nothing blocked show calm empty text', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'Privacy & sharing');
      expect(find.textContaining('You are not sharing anything'), findsOneWidget);
      expect(find.textContaining('You have not blocked anyone'), findsOneWidget);
    });

    testWidgets('a blocked account can be unblocked', (tester) async {
      final rig = _Rig();
      rig.account.blocked = const [BlockedAccount(id: 'b1', name: 'Femi')];
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'Privacy & sharing');
      expect(find.text('Femi'), findsOneWidget);
      await _tap(tester, 'Unblock');
      expect(find.text('Femi'), findsNothing);
      expect(rig.account.blocked, isEmpty);
    });

    testWidgets('deleting the account needs the word DELETE, then erases and signs out', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'Privacy & sharing');
      await _tap(tester, 'Delete my account');
      expect(find.text('This cannot be undone. You will be signed out and can never sign in to this account again.'), findsOneWidget);
      expect(find.text('WHAT IS DELETED'), findsOneWidget);
      expect(find.text('WHAT WE HAVE TO KEEP'), findsOneWidget);
      final button = find.widgetWithText(PawButton, 'Delete my account');
      expect(tester.widget<PawButton>(button).onPressed, isNull, reason: 'needs the word first');

      await tester.enterText(find.byType(TextField).last, 'delete me');
      await tester.pump();
      expect(tester.widget<PawButton>(button).onPressed, isNull, reason: 'the whole word, nothing else');
      await tester.enterText(find.byType(TextField).last, 'delete');
      await tester.pump();
      expect(tester.widget<PawButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(rig.account.deleted, isTrue);
      expect(find.text('Get started'), findsOneWidget, reason: 'signed out, back at Welcome');
    });

    testWidgets('anything in the way is listed first, and there is no delete button', (
      tester,
    ) async {
      final rig = _Rig();
      rig.account.deletionBlockerList = [
        'You have a booking that is not finished. Confirm the visit or cancel it first.',
        'A pet passport transfer is still waiting to be finished.',
      ];
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'Privacy & sharing');
      await _tap(tester, 'Delete my account');
      expect(find.text('Finish these first'), findsOneWidget);
      expect(find.textContaining('booking that is not finished'), findsOneWidget);
      expect(find.textContaining('transfer is still waiting'), findsOneWidget);
      expect(find.widgetWithText(PawButton, 'Delete my account'), findsNothing);
      expect(find.text('Check again'), findsOneWidget);

      // Settled: Check again brings back the confirmation.
      rig.account.deletionBlockerList = [];
      await _tap(tester, 'Check again');
      expect(find.text('Finish these first'), findsNothing);
      expect(find.widgetWithText(PawButton, 'Delete my account'), findsOneWidget);
      expect(rig.account.deleted, isFalse);
    });

    testWidgets('a failure keeps the person signed in and says why', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'Privacy & sharing');
      await _tap(tester, 'Delete my account');
      rig.account.failNext = const AppFailure('No connection. Check your internet and try again.');
      await tester.enterText(find.byType(TextField).last, 'DELETE');
      await tester.pump();
      await tester.tap(find.widgetWithText(PawButton, 'Delete my account'));
      await tester.pumpAndSettle();
      expect(find.text('No connection. Check your internet and try again.'), findsOneWidget);
      expect(rig.account.deleted, isFalse);
      expect(find.text('Get started'), findsNothing);
    });

    test('the confirmation word', () {
      expect(isDeleteConfirmed('DELETE'), isTrue);
      expect(isDeleteConfirmed(' delete '), isTrue);
      expect(isDeleteConfirmed('del'), isFalse);
      expect(isDeleteConfirmed(''), isFalse);
    });
  });

  group('Help articles', () {
    testWidgets('browse, search, read and rate an article', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'Help & support');
      await _tap(tester, 'Browse all');
      expect(find.text('Help articles'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('We found nothing for that'), findsOneWidget);
      await _tap(tester, 'Clear search');

      await tester.enterText(find.byType(TextField).first, 'escrow');
      await tester.pumpAndSettle();
      await _tap(tester, 'How escrow protects you');
      expect(find.text('Was this helpful?'), findsOneWidget);
      await _tap(tester, 'Not really');
      expect(find.text('Contact the team'), findsOneWidget);
    });
  });
}
