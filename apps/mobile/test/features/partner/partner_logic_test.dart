import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/partner/domain/models.dart';
import 'package:pawpass/features/partner/domain/partner_logic.dart';

PartnerApplication _app({
  PartnerType type = PartnerType.vet,
  List<VerifyStep>? steps,
  PartnerStatus status = PartnerStatus.draft,
}) => PartnerApplication(
  partnerId: 'p1',
  type: type,
  status: status,
  businessName: 'Paws',
  area: 'Lekki',
  steps:
      steps ??
      const [
        VerifyStep(key: StepKey.business, done: true),
        VerifyStep(key: StepKey.ownerId, done: true),
        VerifyStep(key: StepKey.cac, done: false),
        VerifyStep(key: StepKey.licence, done: false),
        VerifyStep(key: StepKey.facilityPayout, done: false, photos: 1),
      ],
);

void main() {
  group('validation', () {
    test('business name and area', () {
      expect(validateBusinessName(' '), isNotNull);
      expect(validateBusinessName('A'), isNotNull);
      expect(validateBusinessName('Paws & Claws'), isNull);
      expect(validateBusinessName('x' * 61), isNotNull);
      expect(validateArea(''), isNotNull);
      expect(validateArea('Lekki'), isNull);
    });

    test('an account number has exactly ten digits', () {
      expect(validateAccountNumber('0123456789'), isNull);
      expect(validateAccountNumber(' 0123456789 '), isNull);
      expect(validateAccountNumber('012345678'), isNotNull);
      expect(validateAccountNumber('01234567890'), isNotNull);
      expect(validateAccountNumber('01234a6789'), isNotNull);
      expect(validateAccountName(' '), isNotNull);
      expect(validateAccountName('Tolu Adeyemi'), isNull);
    });

    test('listing name and price', () {
      expect(validateListingName(''), isNotNull);
      expect(validateListingName('Duke'), isNull);
      expect(validateListingName('x' * 41), isNotNull);
      expect(validatePrice('450,000'), isNull);
      expect(validatePrice('999'), isNotNull);
      expect(validatePrice('abc'), isNotNull);
      expect(validatePrice(''), isNotNull);
    });

    test('support message length', () {
      expect(validateSupportMessage('hi'), isNotNull);
      expect(validateSupportMessage('My refund is late'), isNull);
      expect(validateSupportMessage('x' * 2001), isNotNull);
    });
  });

  group('money', () {
    test('a typed price becomes kobo', () {
      expect(parsePriceKobo('450,000'), 45000000);
      expect(parsePriceKobo('₦ 1 500'), 150000);
      expect(parsePriceKobo('12.5'), isNull);
      expect(parsePriceKobo(''), isNull);
      expect(parsePriceKobo('99999999999'), isNull);
    });

    test('big numbers are shortened the way the design does', () {
      expect(compactNaira(18450000), '₦184.5k');
      expect(compactNaira(14200000), '₦142k');
      expect(compactNaira(1500000), '₦15k');
      expect(compactNaira(950000), '₦9,500');
      expect(compactNaira(0), '₦0');
      expect(compactNaira(250000000), '₦2.5m');
    });
  });

  group('steps', () {
    test('counts and what is left', () {
      final a = _app();
      expect(a.stepsTotal, 5);
      expect(a.stepsDone, 2);
      expect(a.canSubmit, isFalse);
      expect(
        stepTitle(StepKey.facilityPayout),
        'Facility photos & payout account',
      );
    });

    test('only a finished, editable application can be submitted', () {
      final done = [
        for (final k in StepKey.values.where((k) => k != StepKey.licence))
          VerifyStep(key: k, done: true, photos: 3, hasPayout: true),
      ];
      expect(_app(type: PartnerType.breeder, steps: done).canSubmit, isTrue);
      expect(
        _app(
          type: PartnerType.breeder,
          steps: done,
          status: PartnerStatus.submitted,
        ).canSubmit,
        isFalse,
      );
      expect(
        _app(
          type: PartnerType.breeder,
          steps: done,
          status: PartnerStatus.needsInfo,
        ).canSubmit,
        isTrue,
      );
    });

    test('the detail line says what is missing', () {
      final a = _app();
      expect(stepDetail(a, a.step(StepKey.business)!), 'Vet · Lekki');
      expect(
        stepDetail(a, a.step(StepKey.cac)!),
        'Your CAC registration certificate',
      );
      expect(
        stepDetail(a, a.step(StepKey.facilityPayout)!),
        '2 more photos and your bank account',
      );
    });
  });

  group('tabs and times', () {
    test('tab names depend on the kind of partner', () {
      expect(tabsFor(PartnerType.vet).second, 'Calendar');
      expect(tabsFor(PartnerType.service).fourth, 'Earnings');
      expect(tabsFor(PartnerType.breeder).second, 'Listings');
      expect(tabsFor(PartnerType.shelter).second, 'Pets');
      expect(tabsFor(PartnerType.shelter).fourth, 'Applications');
    });

    test('visit times are read in Lagos', () {
      final t = DateTime.utc(2026, 11, 5, 15, 30); // 4:30pm in Lagos
      expect(visitTime(t), '4:30');
      expect(visitMeridiem(t), 'pm');
      expect(visitTime(DateTime.utc(2026, 11, 5, 11, 0)), '12:00');
      expect(visitMeridiem(DateTime.utc(2026, 11, 5, 11, 0)), 'pm');
    });

    test('the partner type helpers', () {
      expect(PartnerType.vet.takesBookings, isTrue);
      expect(PartnerType.breeder.listsPets, isTrue);
      expect(PartnerType.parse('shelter'), PartnerType.shelter);
      expect(PartnerType.parse('x'), isNull);
      expect(PartnerStatus.parse('needs_info'), PartnerStatus.needsInfo);
      expect(PartnerStatus.needsInfo.editable, isTrue);
      expect(PartnerStatus.submitted.editable, isFalse);
    });

    test('a ticket number is the one people quote', () {
      final t = SupportTicket(
        id: 'x',
        number: 1,
        topic: 'payments',
        subject: 's',
        state: TicketState.open,
        createdAt: DateTime(2026),
      );
      expect(t.label, '#S-2201');
    });

    test('the bank list has unique codes', () {
      expect({for (final b in banks) b.code}.length, banks.length);
      expect(banks.every((b) => RegExp(r'^\d{3,6}$').hasMatch(b.code)), isTrue);
    });

    test('initial of a profile', () {
      expect(initialOf(null), '?');
      expect(initialOf(const Profile(firstName: 'tolu')), 'T');
    });
  });
}
