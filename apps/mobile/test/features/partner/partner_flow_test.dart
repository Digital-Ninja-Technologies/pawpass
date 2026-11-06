import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/adopt/data/in_memory_adopt.dart';
import 'package:pawpass/features/booking/data/in_memory_bookings.dart';
import 'package:pawpass/features/community/data/in_memory_community.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/ui/onboarding_page.dart'
    show PhotoPickerButton;
import 'package:pawpass/features/partner/data/in_memory_partner.dart';
import 'package:pawpass/features/partner/domain/models.dart';
import 'package:pawpass/features/partner/ui/partner_widgets.dart'
    show PartnerTabBar;
import 'package:pawpass/ui/ui.dart';

final _today = DateTime.utc(2026, 11, 5, 8);

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Picks a tiny pretend photo from either source.
class _Picker implements PhotoPicker {
  @override
  Future<PickedPhoto?> fromCamera() async => PickedPhoto(_png);
  @override
  Future<PickedPhoto?> fromGallery() async => PickedPhoto(_png);
}

class _Rig {
  _Rig() {
    profiles = InMemoryProfileRepository();
    pets = InMemoryPetRepository(profiles: profiles, now: () => _today);
    bookings = InMemoryBookingsRepository(now: () => _today);
    adopt = InMemoryAdoptRepository(now: () => _today);
    partner = InMemoryPartnerRepository(
      now: () => _today,
      onConfirmHandover: adopt.sellerConfirmHandover,
      onCancelOrder: adopt.sellerCancel,
    );
    services = AppServices(
      auth: InMemoryAuthRepository(signedInAs: 'tolu@example.com'),
      profiles: profiles,
      pets: pets,
      photos: _Picker(),
      emailApp: NoEmailApp(),
      health: InMemoryHealthRepository(now: () => _today),
      notifications: InMemoryNotificationsRepository(),
      vets: InMemoryVetsRepository(),
      location: FakeLocationService(),
      links: FakeLinkLauncher(),
      bookings: bookings,
      payments: InMemoryPaymentsRepository(bookings, others: [adopt.markPaid]),
      community: InMemoryCommunityRepository(now: () => _today),
      adopt: adopt,
      partner: partner,
      now: () => _today,
    );
  }

  late final InMemoryProfileRepository profiles;
  late final InMemoryPetRepository pets;
  late final InMemoryBookingsRepository bookings;
  late final InMemoryAdoptRepository adopt;
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
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
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

Future<void> _tapLabel(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(PawBackButton).first);
  await tester.pumpAndSettle();
}

Future<void> _openMe(WidgetTester tester) => _tapLabel(tester, 'Your account');

Future<void> _enter(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(PawTextField, label);
  expect(field, findsWidgets, reason: 'No field labelled "$label"');
  final input = find.descendant(
    of: field.first,
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(input);
  await tester.enterText(input, text);
  await tester.pump();
}

Future<void> _enterAt(WidgetTester tester, int index, String text) async {
  final f = find.byType(TextField).at(index);
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

/// Uploads a document through the photo sheet on a document step.
Future<void> _upload(WidgetTester tester) async {
  await tester.tap(find.byType(PhotoPickerButton).first);
  await tester.pumpAndSettle();
  await _tap(tester, 'Choose from your photos');
  await _tap(tester, 'Upload');
}

/// A partner with every kind of fixture, for the dashboards.
void _approve(_Rig rig, PartnerType type, String name) {
  rig.partner.approveAs(type, name);
}

void main() {
  group('Me', () {
    testWidgets(
      'shows who you are, your pets, the links and the partner card',
      (tester) async {
        await _pump(tester, _Rig());
        await _openMe(tester);
        expect(find.text('Me'), findsOneWidget);
        expect(find.text('Tolu Adeyemi'), findsOneWidget);
        expect(find.textContaining('tolu@example.com'), findsOneWidget);
        expect(find.text('Bingo'), findsWidgets);
        expect(find.text('Add pet'), findsOneWidget);
        for (final t in [
          'My bookings',
          'Payments & escrow',
          'QR tags',
          'Notifications & reminders',
          'Privacy & sharing',
          'Help & support',
        ]) {
          expect(find.text(t), findsOneWidget, reason: t);
        }
        expect(find.text('Become a partner'), findsOneWidget);
        expect(find.text('Log out'), findsOneWidget);
      },
    );

    testWidgets('editing your details updates the screen', (tester) async {
      await _pump(tester, _Rig());
      await _openMe(tester);
      await _tap(tester, 'Edit');
      await _enter(tester, 'Area', 'Victoria Island');
      await _tap(tester, 'Save');
      expect(find.text('Me'), findsOneWidget);
      expect(find.textContaining('Victoria Island'), findsOneWidget);
    });

    testWidgets('a first name is required when editing', (tester) async {
      await _pump(tester, _Rig());
      await _openMe(tester);
      await _tap(tester, 'Edit');
      await _enter(tester, 'First name', '');
      await _tap(tester, 'Save');
      expect(find.text('Enter your first name'), findsOneWidget);
    });

    testWidgets('screens that are not designed yet say so', (tester) async {
      await _pump(tester, _Rig());
      await _openMe(tester);
      await _tap(tester, 'QR tags');
      expect(find.text('This part is coming soon'), findsOneWidget);
      await _back(tester);
      await _tap(tester, 'Privacy & sharing');
      expect(find.text('This part is coming soon'), findsOneWidget);
    });

    testWidgets('payments & escrow is empty before any order', (tester) async {
      await _pump(tester, _Rig());
      await _openMe(tester);
      await _tap(tester, 'Payments & escrow');
      expect(find.textContaining('No puppy orders yet'), findsOneWidget);
    });
  });

  group('Becoming a partner', () {
    testWidgets('pick a kind, verify the business, send it, and wait', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'Become a partner');
      expect(
        find.text('What kind of partner are you?'.toUpperCase()),
        findsOneWidget,
      );
      for (final t in PartnerType.values) {
        expect(find.text(t.label), findsOneWidget);
      }
      await _tap(tester, 'Breeder');
      await _tap(tester, 'Continue to verification');

      // Business details.
      expect(find.text('Business details'), findsWidgets);
      await _tap(tester, 'Save and continue');
      expect(find.text('Enter your business name'), findsOneWidget);
      await _enter(tester, 'Business name', 'Tolu Kennels');
      await _tap(tester, 'Save and continue');

      // The checklist: four steps for a breeder, one done.
      expect(find.text('Verify your business'), findsOneWidget);
      expect(find.text('1 of 4 done'), findsOneWidget);
      expect(find.text('Licence'), findsNothing);
      expect(find.text('Vet practising licence'), findsNothing);
      final submit = find.widgetWithText(PawButton, 'Submit for review');
      expect(tester.widget<PawButton>(submit).onPressed, isNull);

      await _tap(tester, 'Owner ID');
      await _upload(tester);
      expect(find.text('2 of 4 done'), findsOneWidget);
      await _tap(tester, 'CAC registration');
      await _upload(tester);
      expect(find.text('3 of 4 done'), findsOneWidget);

      // Photos and payout.
      await _tap(tester, 'Facility photos & payout account');
      expect(find.text('0 of 3 added. You can add up to 6.'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await _tap(tester, 'Add a photo');
        await _tap(tester, 'Choose from your photos');
      }
      expect(find.text('3 of 3 added. You can add up to 6.'), findsOneWidget);
      await _tap(tester, 'Choose your bank');
      await _tap(tester, 'Guaranty Trust Bank');
      await _enter(tester, 'Account number', '12345');
      await _enter(tester, 'Name on the account', 'Tolu Adeyemi');
      await _tap(tester, 'Save account');
      expect(find.text('An account number has 10 digits'), findsOneWidget);
      await _enter(tester, 'Account number', '0123456789');
      await _tap(tester, 'Save account');
      expect(find.text('Guaranty Trust Bank ending 6789'), findsOneWidget);
      await _tap(tester, 'Done');

      expect(find.text('4 of 4 done'), findsOneWidget);
      expect(tester.widget<PawButton>(submit).onPressed, isNotNull);
      await _tap(tester, 'Submit for review');

      // Waiting for the team.
      expect(find.text('Verification status'), findsOneWidget);
      expect(find.text('Tolu Kennels'), findsOneWidget);
      expect(find.text('In review'), findsOneWidget);
      expect(find.textContaining('Decision within 48 hours'), findsOneWidget);
      expect(
        find.textContaining('keep using PawPass as an owner'),
        findsOneWidget,
      );

      // Me shows the application is in review, and the checklist is locked.
      await _tap(tester, 'Back to home');
      await _openMe(tester);
      expect(find.text('Verification in review'), findsOneWidget);
    });

    testWidgets('a vet is asked for a practising licence', (tester) async {
      await _pump(tester, _Rig());
      await _openMe(tester);
      await _tap(tester, 'Become a partner');
      await _tap(tester, 'Continue to verification');
      await _enter(tester, 'Business name', 'Paws & Claws');
      await _tap(tester, 'Save and continue');
      expect(find.text('1 of 5 done'), findsOneWidget);
      expect(find.text('Vet practising licence'), findsOneWidget);
      expect(find.text('Required for vet clinics'), findsOneWidget);
    });

    testWidgets(
      'the team asks for more: the note, the fix, and sending it again',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        // A finished application, submitted.
        await rig.partner.start(
          type: PartnerType.breeder,
          businessName: 'Tolu Kennels',
          area: 'Lekki',
        );
        final photo = PickedPhoto(_png);
        for (final k in [
          DocumentKind.ownerId,
          DocumentKind.cac,
          DocumentKind.facilityPhoto,
          DocumentKind.facilityPhoto,
          DocumentKind.facilityPhoto,
        ]) {
          await rig.partner.addDocument('p1', k, photo);
        }
        await rig.partner.savePayout(
          'p1',
          bankCode: '058',
          bankName: 'GTBank',
          accountNumber: '0123456789',
          accountName: 'Tolu',
        );
        await rig.partner.submit('p1');
        rig.partner.review(
          PartnerStatus.needsInfo,
          note: 'Your CAC certificate photo is blurry',
        );

        await _openMe(tester);
        expect(find.text('One thing needed'), findsOneWidget);
        await _tap(tester, 'One thing needed');
        expect(find.text('ONE THING NEEDED'), findsOneWidget);
        expect(
          find.text('Your CAC certificate photo is blurry'),
          findsOneWidget,
        );
        expect(find.text('In review · waiting on you'), findsOneWidget);

        await _tap(tester, 'Fix it and resubmit');
        await _tap(tester, 'CAC registration');
        expect(find.text('Already uploaded'), findsOneWidget);
        await _upload(tester);
        await _tap(tester, 'Submit for review');
        expect(find.text('In review'), findsOneWidget);
        expect(find.text('ONE THING NEEDED'), findsNothing);
      },
    );

    testWidgets('a rejected application can start again', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await rig.partner.start(
        type: PartnerType.service,
        businessName: 'Glam Paws',
        area: 'Yaba',
      );
      rig.partner.review(
        PartnerStatus.rejected,
        note: 'We could not verify the business',
      );
      await _openMe(tester);
      await _tap(tester, 'Application not approved');
      expect(find.text('NOT APPROVED'), findsOneWidget);
      expect(find.text('We could not verify the business'), findsOneWidget);
      await _tap(tester, 'Start again');
      expect(find.text('Become a partner'), findsWidgets);
    });

    testWidgets(
      'approval unlocks the partner bar on Home and the dashboard from Me',
      (tester) async {
        final rig = _Rig();
        await _pump(tester, rig);
        _approve(rig, PartnerType.vet, 'Paws & Claws Vet Clinic');
        await _openMe(tester);
        expect(find.text('Paws & Claws Vet Clinic'), findsOneWidget);
        expect(find.text('Open your partner dashboard'), findsOneWidget);
        expect(find.text('Verified'), findsOneWidget);
        await _back(tester);
        expect(find.text('PARTNER MODE'), findsOneWidget);
        await _tapLabel(
          tester,
          'Partner mode. Paws & Claws Vet Clinic. Open your dashboard',
        );
        expect(find.text("Today's schedule"), findsOneWidget);
      },
    );
  });

  group('Vet and service dashboard', () {
    testWidgets('today, the week, the rating, the next payout and the tabs', (
      tester,
    ) async {
      final rig = _Rig();
      _approve(rig, PartnerType.vet, 'Paws & Claws Vet Clinic');
      rig.partner
        ..rating = 4.8
        ..weekKobo = 18450000
        ..nextPayoutKobo = 14200000
        ..visits = [
          VisitItem(
            bookingId: 'b1',
            startsAt: DateTime.utc(2026, 11, 5, 13),
            service: 'Consultation',
            petName: 'Rex',
            petId: 'pr',
            ownerName: 'Chidi',
            breed: 'German Shepherd',
            status: 'completed',
            passportShared: false,
          ),
          VisitItem(
            bookingId: 'b2',
            startsAt: DateTime.utc(2026, 11, 5, 15, 30),
            service: 'Rabies vaccine',
            petName: 'Bingo',
            petId: 'pb',
            ownerName: 'Tolu',
            breed: 'Boerboel',
            status: 'confirmed',
            passportShared: true,
          ),
        ];
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Paws & Claws Vet Clinic. Open your dashboard',
      );

      expect(find.text('PARTNER MODE'), findsOneWidget);
      expect(find.text('Paws & Claws Vet Clinic'), findsOneWidget);
      expect(find.text('2 visits'), findsOneWidget);
      expect(find.text('₦184.5k'), findsOneWidget);
      expect(find.text('★ 4.8'), findsOneWidget);
      expect(find.text('Thu 5 Nov'), findsOneWidget);
      expect(find.text('Consultation · Rex'), findsOneWidget);
      expect(find.text('Chidi · German Shepherd'), findsOneWidget);
      expect(find.text('2:00'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Rabies vaccine · Bingo'), findsOneWidget);
      expect(find.text('Tolu · Boerboel · passport shared'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('₦142,000'), findsOneWidget);

      // The bar: Today, Calendar, Messages, Earnings, Business.
      for (final t in [
        'Today',
        'Calendar',
        'Messages',
        'Earnings',
        'Business',
      ]) {
        expect(
          find.descendant(
            of: find.byType(PartnerTabBar),
            matching: find.text(t),
          ),
          findsOneWidget,
          reason: t,
        );
      }
    });

    testWidgets('owner mode goes back to the owner Home', (tester) async {
      final rig = _Rig();
      _approve(rig, PartnerType.service, 'Glam Paws Grooming');
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Glam Paws Grooming. Open your dashboard',
      );
      expect(
        find.text('No visits today. New bookings show up here.'),
        findsOneWidget,
      );
      await _tap(tester, 'Owner mode');
      expect(find.byType(PawTabBar), findsOneWidget);
      expect(
        find.text('PARTNER MODE'),
        findsOneWidget,
        reason: 'the bar to go back is on Home',
      );
    });

    testWidgets('Earnings shows the payout, what is held and what was paid', (
      tester,
    ) async {
      final rig = _Rig();
      _approve(rig, PartnerType.vet, 'Paws & Claws Vet Clinic');
      rig.partner.earningsData = Earnings(
        nextPayoutOn: DateTime(2026, 11, 9),
        nextPayoutKobo: 14200000,
        heldKobo: 4250000,
        paidMonthKobo: 31000000,
        bankName: 'GTBank',
        accountLast4: '2291',
        recent: [
          EarningItem(
            title: 'Rabies vaccine · Bingo',
            state: EarningState.held,
            amountKobo: 1320000,
            at: DateTime.utc(2026, 11, 5, 8),
            payout: false,
          ),
          EarningItem(
            title: 'Consultation · Rex',
            state: EarningState.ready,
            amountKobo: 880000,
            at: DateTime.utc(2026, 11, 5, 8),
            payout: false,
          ),
          EarningItem(
            title: 'Weekly payout',
            state: EarningState.sent,
            amountKobo: 9640000,
            at: DateTime.utc(2026, 11, 2, 8),
            payout: true,
          ),
        ],
      );
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Paws & Claws Vet Clinic. Open your dashboard',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(PartnerTabBar),
          matching: find.text('Earnings'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Earnings'), findsWidgets);
      expect(find.text('NEXT PAYOUT · 9 NOV'), findsOneWidget);
      expect(find.text('₦142,000'), findsOneWidget);
      expect(find.text('To your bank account ending 2291'), findsOneWidget);
      expect(find.text('Held until owners confirm'), findsOneWidget);
      expect(find.text('₦42,500'), findsOneWidget);
      expect(find.text('Paid out in November'), findsOneWidget);
      expect(find.text('₦310,000'), findsOneWidget);
      expect(find.text('Rabies vaccine · Bingo'), findsOneWidget);
      expect(
        find.textContaining('held until the owner confirms'),
        findsOneWidget,
      );
      expect(find.textContaining('ready · in the next payout'), findsOneWidget);
      expect(find.text('Weekly payout'), findsOneWidget);
      expect(
        find.textContaining('Amounts are after the PawPass fee'),
        findsOneWidget,
      );
    });

    testWidgets('the Business tab shows the verified checklist', (
      tester,
    ) async {
      final rig = _Rig();
      _approve(rig, PartnerType.vet, 'Paws & Claws Vet Clinic');
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Paws & Claws Vet Clinic. Open your dashboard',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(PartnerTabBar),
          matching: find.text('Business'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('is verified'), findsOneWidget);
      expect(find.text('5 of 5 done'), findsOneWidget);
    });
  });

  group('Breeder dashboard', () {
    PartnerListing duke() => PartnerListing(
      listingId: 'l1',
      petId: 'p1',
      petName: 'Duke',
      status: 'reserved',
      sale: true,
      priceKobo: 45000000,
      handoverBy: DateTime.utc(2026, 11, 12, 12),
      orderId: 'o1',
      orderStatus: 'deposit_paid',
      buyerName: 'Tolu',
    );

    testWidgets('listings, enquiries and what is in escrow', (tester) async {
      final rig = _Rig();
      _approve(rig, PartnerType.breeder, 'Royal Paws Kennels');
      rig.partner
        ..inEscrowKobo = 15000000
        ..listings = [
          duke(),
          const PartnerListing(
            listingId: 'l2',
            petId: 'p2',
            petName: "Bella's litter",
            status: 'live',
            sale: true,
            priceKobo: 30000000,
            enquiries: 4,
          ),
        ]
        ..enquiries = [
          const Enquiry(
            conversationId: 'c1',
            listingId: 'l2',
            petName: "Bella's litter",
            otherName: 'Emeka',
            lastBody: 'Can I visit on Saturday to meet them?',
            unread: 1,
          ),
          const Enquiry(
            conversationId: 'c2',
            listingId: 'l2',
            petName: "Bella's litter",
            otherName: 'Funmi',
            lastBody: "Are the parents' hip scores in the passport?",
            unread: 0,
          ),
        ];
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Royal Paws Kennels. Open your dashboard',
      );
      expect(find.text('PARTNER MODE · BREEDER'), findsOneWidget);
      expect(find.text('Live listings'), findsOneWidget);
      expect(find.text('New enquiries'), findsOneWidget);
      expect(find.text('₦150k'), findsOneWidget);
      expect(find.text('Duke · ₦450,000'), findsOneWidget);
      expect(
        find.text('Deposit paid by Tolu · handover by 12 Nov'),
        findsOneWidget,
      );
      expect(find.text('Reserved'), findsOneWidget);
      expect(find.text("Bella's litter · ₦300,000"), findsOneWidget);
      expect(find.text('4 enquiries'), findsOneWidget);
      expect(find.text('Emeka · Bella\'s litter'), findsOneWidget);
      expect(
        find.text('"Can I visit on Saturday to meet them?"'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Unread',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a new listing: validation, then it is live on the dashboard', (
      tester,
    ) async {
      final rig = _Rig();
      _approve(rig, PartnerType.breeder, 'Royal Paws Kennels');
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Royal Paws Kennels. Open your dashboard',
      );
      await _tap(tester, '+ New listing');
      expect(find.text('New listing'), findsOneWidget);
      expect(find.text('✓ Verified'), findsNothing);
      expect(find.text('Single puppy'), findsOneWidget);
      expect(find.text('Whole litter'), findsOneWidget);

      await _tap(tester, 'Publish listing');
      expect(find.text('Give the pet a name'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Enter a price in naira'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Enter a price in naira'), findsOneWidget);

      await _enter(tester, 'Name', 'Duke');
      await _enter(tester, 'Breed', 'Boerboel');
      await _enter(tester, 'Price (₦)', '999');
      await _tap(tester, 'Publish listing');
      expect(find.text('The price must be at least ₦1,000'), findsOneWidget);
      await _enter(tester, 'Price (₦)', '450,000');
      await _tap(tester, 'Publish listing');

      expect(find.text('Duke is live.'), findsOneWidget);
      expect(find.text('Duke · ₦450,000'), findsOneWidget);
      expect(rig.partner.calls, contains('listing'));
    });

    testWidgets('a whole litter is numbered', (tester) async {
      final rig = _Rig();
      _approve(rig, PartnerType.breeder, 'Royal Paws Kennels');
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Royal Paws Kennels. Open your dashboard',
      );
      await _tap(tester, '+ New listing');
      await _tap(tester, 'Whole litter');
      expect(find.text('3'), findsOneWidget);
      await _tapLabel(tester, 'More puppies');
      expect(find.text('4'), findsOneWidget);
      await _enter(tester, 'Litter name', 'Bella');
      await _enter(tester, 'Price each (₦)', '300000');
      await _tap(tester, 'Publish listing');
      expect(find.text('Your litter is live.'), findsOneWidget);
      expect(find.text('Bella 1 · ₦300,000'), findsOneWidget);
      expect(rig.partner.listings.length, 4);
    });

    testWidgets('the Listings tab takes a listing down', (tester) async {
      final rig = _Rig();
      _approve(rig, PartnerType.breeder, 'Royal Paws Kennels');
      rig.partner.listings = [
        const PartnerListing(
          listingId: 'l2',
          petId: 'p2',
          petName: 'Zeus',
          status: 'live',
          sale: true,
          priceKobo: 30000000,
        ),
      ];
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Royal Paws Kennels. Open your dashboard',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(PartnerTabBar),
          matching: find.text('Listings'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Zeus · ₦300,000'), findsOneWidget);
      await _tap(tester, 'Take down');
      expect(find.text('Nothing listed yet.'), findsOneWidget);
    });
  });

  group('Shelter dashboard', () {
    ShelterApplication app(
      String id,
      String who,
      String pet,
      ApplicationState s, {
      bool vaccinated = false,
    }) => ShelterApplication(
      id: id,
      listingId: 'l$id',
      petName: pet,
      applicantName: who,
      state: s,
      createdAt: _today,
      homeType: 'house',
      otherPets: '1 dog, 1 cat',
      daytime: 'home 3 days a week',
      why: 'We have room and time for a rescue.',
      petsTotal: 2,
      petsVaccinated: vaccinated ? 2 : 0,
    );

    testWidgets('applications, with the vaccination note and decisions', (
      tester,
    ) async {
      final rig = _Rig();
      _approve(rig, PartnerType.shelter, 'Lagos Paws Rescue');
      rig.partner
        ..adoptedMonth = 7
        ..applications = [
          app(
            'a1',
            'Tolu',
            'Ada',
            ApplicationState.submitted,
            vaccinated: true,
          ),
          app('a2', 'Seun', 'Kofi', ApplicationState.submitted),
        ];
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Lagos Paws Rescue. Open your dashboard',
      );
      expect(find.text('PARTNER MODE · SHELTER'), findsOneWidget);
      expect(find.text('Pets listed'), findsOneWidget);
      expect(find.text('New applications'), findsOneWidget);
      expect(find.text('Adopted · Nov'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Tolu wants to adopt Ada'), findsOneWidget);
      expect(
        find.text('House · has 1 dog, 1 cat · home 3 days a week'),
        findsNWidgets(2),
      );
      expect(
        find.text('Current pets are vaccinated, per their passports'),
        findsOneWidget,
      );

      await _tap(tester, 'Approve');
      expect(find.text('Tolu is approved for Ada.'), findsOneWidget);
      expect(find.text('Hand over Ada'), findsOneWidget);
      await _tap(tester, 'Decline politely');
      expect(find.text('We let Seun know, kindly.'), findsOneWidget);
      expect(find.text('Kofi'), findsNothing);
    });

    testWidgets('a home visit opens the chat and marks the application', (
      tester,
    ) async {
      final rig = _Rig();
      _approve(rig, PartnerType.shelter, 'Lagos Paws Rescue');
      rig.partner.applications = [
        app('a1', 'Tolu', 'Ada', ApplicationState.submitted),
      ];
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Lagos Paws Rescue. Open your dashboard',
      );
      await _tap(tester, 'Book home visit');
      expect(
        rig.partner.calls,
        containsAll(['chat:a1', 'decide:a1:home_visit']),
      );
    });

    testWidgets('handing over an approved pet', (tester) async {
      final rig = _Rig();
      _approve(rig, PartnerType.shelter, 'Lagos Paws Rescue');
      rig.partner.applications = [
        app('a1', 'Tolu', 'Ada', ApplicationState.approved),
      ];
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Lagos Paws Rescue. Open your dashboard',
      );
      await _tap(tester, 'Hand over Ada');
      expect(find.textContaining('Ada is handed over'), findsOneWidget);
      expect(rig.partner.calls, contains('handover:a1'));
    });

    testWidgets('the Applications tab and the empty state', (tester) async {
      final rig = _Rig();
      _approve(rig, PartnerType.shelter, 'Lagos Paws Rescue');
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Lagos Paws Rescue. Open your dashboard',
      );
      expect(find.textContaining('No applications to review'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(PartnerTabBar),
          matching: find.text('Applications'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Applications'), findsWidgets);
      expect(find.textContaining('No applications to review'), findsOneWidget);
    });

    testWidgets('adding a pet is free: no price field', (tester) async {
      final rig = _Rig();
      _approve(rig, PartnerType.shelter, 'Lagos Paws Rescue');
      await _pump(tester, rig);
      await _tapLabel(
        tester,
        'Partner mode. Lagos Paws Rescue. Open your dashboard',
      );
      await _tap(tester, '+ Add pet');
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Price (₦)'), findsNothing);
      expect(find.text('Whole litter'), findsNothing);
      await _enter(tester, 'Name', 'Kofi');
      await _tap(tester, 'Publish for adoption');
      expect(find.text('Kofi is live.'), findsOneWidget);
      expect(rig.partner.listings.single.sale, isFalse);
    });
  });

  group('Help & support', () {
    testWidgets('articles open, search filters, and a request is sent', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'Help & support');
      expect(find.text('Popular topics'.toUpperCase()), findsOneWidget);
      expect(find.text('How escrow protects you'), findsOneWidget);
      await _tap(tester, 'How escrow protects you');
      expect(find.textContaining('goes to PawPass'), findsOneWidget);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      await _enterAt(tester, 0, 'refund');
      expect(find.text('Refunds & cancellations'), findsOneWidget);
      expect(find.text('Lost pet alerts & QR tags'), findsNothing);
      await _enterAt(tester, 0, 'zzzz');
      expect(find.textContaining('Nothing matches that'), findsOneWidget);
      await _enterAt(tester, 0, '');

      expect(find.text('You have not written to us yet.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Send · we reply within a day'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      final send = find.widgetWithText(
        PawButton,
        'Send · we reply within a day',
      );
      expect(tester.widget<PawButton>(send).onPressed, isNull);
      await _enterAt(tester, 1, 'My refund has not arrived yet');
      await tester.pump();
      await _tap(tester, 'Send · we reply within a day');
      expect(find.text('Sent. We will reply within a day.'), findsOneWidget);
      expect(find.text('My refund has not arrived yet'), findsOneWidget);
      expect(find.textContaining('#S-2201'), findsOneWidget);
    });

    testWidgets('the topic can be changed', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await _openMe(tester);
      await _tap(tester, 'Help & support');
      await _tap(tester, 'Payments & refunds');
      await _tap(tester, 'Bookings', last: true);
      await _enterAt(tester, 1, 'My booking time is wrong');
      await tester.pump();
      await _tap(tester, 'Send · we reply within a day');
      expect(rig.partner.calls, contains('ticket:bookings'));
    });
  });

  group('The seller on an order', () {
    testWidgets('can cancel before handover, which refunds the buyer', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(
        find.descendant(
          of: find.byType(PawTabBar),
          matching: find.text('Adopt'),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Duke');
      await _tap(tester, 'Pay deposit safely');
      await _tap(tester, 'Pay ₦157,500 into escrow');
      await _tap(tester, "I've paid");
      expect(
        find.text('Cancel order'),
        findsNothing,
        reason: 'the buyer does not see seller tools',
      );

      rig.adopt.viewAsSeller = true;
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Cancel order'), findsOneWidget);
      expect(
        find.text('Confirm handover'),
        findsNothing,
        reason: 'the balance is not paid yet',
      );
      await _tap(tester, 'Cancel order');
      expect(find.text('Cancel this order?'), findsOneWidget);
      await _tap(tester, 'Keep the order');
      expect(find.text('Cancel order'), findsOneWidget);
      await _tap(tester, 'Cancel order');
      await _tap(tester, 'Cancel order', last: true);
      expect(
        find.text('Order cancelled. The buyer is refunded in full.'),
        findsOneWidget,
      );
      expect(
        rig.partner.calls.where((c) => c.startsWith('cancel:')),
        hasLength(1),
      );
    });

    testWidgets('can confirm the handover once the balance is paid', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(
        find.descendant(
          of: find.byType(PawTabBar),
          matching: find.text('Adopt'),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Duke');
      await _tap(tester, 'Pay deposit safely');
      await _tap(tester, 'Pay ₦157,500 into escrow');
      await _tap(tester, "I've paid");
      await _tap(tester, 'Pay balance ₦300,000');
      await _tap(tester, "I've paid");
      rig.adopt.viewAsSeller = true;
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Confirm handover');
      expect(find.textContaining('Handover confirmed. Tolu'), findsOneWidget);
      expect(
        rig.partner.calls.where((c) => c.startsWith('confirm:')),
        hasLength(1),
      );
      expect(find.text('Confirm handover'), findsNothing);
    });
  });

  group('small phone, large text', () {
    for (final t in [
      PartnerType.vet,
      PartnerType.breeder,
      PartnerType.shelter,
    ]) {
      testWidgets('${t.value} dashboard and screens fit', (tester) async {
        final rig = _Rig();
        _approve(rig, t, 'Royal Paws Kennels And Rescue Home');
        rig.partner
          ..visits = [
            VisitItem(
              bookingId: 'b1',
              startsAt: DateTime.utc(2026, 11, 5, 15, 30),
              service: 'Full check-up and vaccination',
              petName: 'Bingo',
              petId: 'p',
              ownerName: 'Tolu',
              breed: 'Boerboel',
              status: 'confirmed',
              passportShared: true,
            ),
          ]
          ..listings = [
            const PartnerListing(
              listingId: 'l',
              petId: 'p',
              petName: 'Duke the very good boy',
              status: 'live',
              sale: true,
              priceKobo: 45000000,
              enquiries: 3,
            ),
          ]
          ..applications = [
            ShelterApplication(
              id: 'a',
              listingId: 'l',
              petName: 'Ada',
              applicantName: 'Tolu',
              state: ApplicationState.submitted,
              createdAt: _today,
              homeType: 'house',
              otherPets: '1 dog, 1 cat',
              daytime: 'home 3 days a week',
              why: 'We have room and time for a rescue.',
              petsTotal: 1,
              petsVaccinated: 1,
            ),
          ];
        await _pump(tester, rig, size: const Size(320, 568), scale: 1.3);
        await _tapLabel(
          tester,
          'Partner mode. Royal Paws Kennels And Rescue Home. Open your dashboard',
        );
        expect(tester.takeException(), isNull);
        for (final tab in ['Messages', 'Business', 'Today']) {
          await tester.tap(
            find.descendant(
              of: find.byType(PartnerTabBar),
              matching: find.text(tab),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: tab);
        }
      });
    }

    testWidgets('the listing form, help and the earnings tab fit', (
      tester,
    ) async {
      final rig = _Rig();
      _approve(rig, PartnerType.breeder, 'Royal Paws Kennels And Rescue Home');
      await _pump(tester, rig, size: const Size(320, 568), scale: 1.3);
      await _tapLabel(
        tester,
        'Partner mode. Royal Paws Kennels And Rescue Home. Open your dashboard',
      );
      await _tap(tester, '+ New listing');
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Whole litter');
      await tester.scrollUntilVisible(
        find.text('Publish listing'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 3000),
        3000,
      );
      await tester.pumpAndSettle();
      await _back(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PartnerTabBar),
          matching: find.text('Earnings'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Me, the application screens, the listing form and help fit', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig, size: const Size(320, 568), scale: 1.3);
      await _openMe(tester);
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Become a partner');
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Continue to verification');
      await _enter(tester, 'Business name', 'Paws & Claws Vet Clinic');
      await _tap(tester, 'Save and continue');
      expect(tester.takeException(), isNull);
      await _tap(tester, 'Facility photos & payout account');
      expect(tester.takeException(), isNull);
    });
  });
}
