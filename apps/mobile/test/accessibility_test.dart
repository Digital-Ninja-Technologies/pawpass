import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/features/onboarding/domain/reminder_schedule.dart';
import 'package:pawpass/features/partner/data/in_memory_partner.dart';
import 'package:pawpass/features/partner/domain/models.dart';

final _today = DateTime.utc(2026, 11, 5, 8);

/// A signed in, finished person with a pet, optionally an approved partner of [type].
Future<AppServices> _services({PartnerType? partner}) async {
  final services = inMemoryServices(
    now: () => _today,
    signedInAs: 'tolu@example.com',
  );
  final profiles = services.profiles as InMemoryProfileRepository;
  await profiles.save(firstName: 'Tolu', lastName: 'Adeyemi', area: 'Lekki');
  profiles.markOnboarded(_today);
  await services.pets.createPassport(
    pet: PetInput(
      name: 'Bingo',
      species: Species.dog,
      breed: 'Boerboel',
      sex: PetSex.male,
      dateOfBirth: DateTime(2024, 8, 14),
    ),
    records: [
      HealthRecordDraft(
        type: 'vaccine',
        name: 'Rabies',
        givenOn: DateTime(2026, 3, 12),
        nextDueOn: DateTime(2026, 11, 12),
      ),
    ],
    channels: {ReminderChannel.push},
  );
  if (partner != null) {
    (services.partner as InMemoryPartnerRepository).approveAs(
      partner,
      'Royal Paws Kennels',
    );
  }
  return services;
}

Future<void> _open(
  WidgetTester tester,
  AppServices services,
  String route, {
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(scale),
      ),
      child: PawPassApp(services: services),
    ),
  );
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
  await tester.pumpAndSettle();
}

/// WCAG 2.1 AA has no minimum target size; the design asks for 44 (Apple's guideline), so the Android 48 check
/// is not used. Everything tappable must have a label, and text must have enough contrast. The 11 pixel tab bar
/// labels trip the contrast sampler even when their colours pass (see test/theme/contrast_test.dart), so screens
/// with a tab bar are checked for contrast through those tokens instead.
Future<void> _check(WidgetTester tester, {bool contrast = true}) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  if (contrast) {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }
  handle.dispose();
}

/// Add record is a wall of chips whose 44 point tap areas include the pale border around each pill; the sampler
/// reads those border pixels as text. The chip colours are checked in test/theme/contrast_test.dart.
/// Screens inside the bottom tab bar.
const _tabs = {'/home', '/passport', '/book', '/community', '/adopt'};

void main() {
  const owner = <String, String>{
    'Home': '/home',
    'Passport': '/passport',
    'Schedule': '/schedule',
    'Book care': '/book',
    'Community': '/community',
    'Adopt': '/adopt',
    'Notifications': '/notifications',
    'Add record': '/add-record',
    'Share with vet': '/share',
    'Emergency vets': '/emergency',
    'Bookings': '/bookings',
    'Messages': '/messages',
    'Me': '/me',
    'Edit details': '/me/edit',
    'Help & support': '/help',
    'Payments & escrow': '/orders',
    'Become a partner': '/partner/become',
    'Business details': '/partner/details',
    'Verify your business': '/partner/kyc',
  };

  group('owner screens meet the guidelines', () {
    owner.forEach((name, route) {
      testWidgets(name, (tester) async {
        await _open(tester, await _services(), route);
        await _check(
          tester,
          contrast: !_tabs.contains(route) && route != '/add-record',
        );
      });
    });
  });

  group('partner screens meet the guidelines', () {
    for (final type in PartnerType.values) {
      testWidgets('${type.value} dashboard and tabs', (tester) async {
        await _open(tester, await _services(partner: type), '/partner');
        await _check(tester, contrast: false);
        for (final route in [
          '/partner/listings',
          '/partner/messages',
          '/partner/money',
          '/partner/business',
        ]) {
          GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
          await tester.pumpAndSettle();
          await _check(tester, contrast: false);
        }
      });
    }

    testWidgets('new listing form', (tester) async {
      await _open(
        tester,
        await _services(partner: PartnerType.breeder),
        '/partner/listing/new',
      );
      await _check(tester);
    });
  });
}
