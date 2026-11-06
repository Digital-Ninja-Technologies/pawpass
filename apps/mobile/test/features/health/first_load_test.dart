import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/health/data/in_memory_health.dart';
import 'package:pawpass/features/health/domain/health_logic.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/ui/ui.dart';

final _today = DateTime(2026, 11, 5, 9);

Future<InMemoryHealthRepository> _start(
  WidgetTester tester, {
  required bool failFirstLoad,
}) async {
  final services = inMemoryServices(
    now: () => _today,
    signedInAs: 'tolu@example.com',
  );
  final profiles = services.profiles as InMemoryProfileRepository;
  await profiles.save(firstName: 'Tolu');
  profiles.markOnboarded(_today);
  await services.pets.createPassport(
    pet: const PetInput(name: 'Bingo', species: Species.dog, sex: PetSex.male),
    records: const [],
    channels: {ReminderChannel.push},
  );
  final health = services.health as InMemoryHealthRepository;
  if (failFirstLoad) {
    health.failNext = const AppFailure('We could not load the schedule.');
  }
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(PawPassApp(services: services));
  await tester.pumpAndSettle();
  return health;
}

void _go(WidgetTester tester, String route) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);

void main() {
  group('before the first load finishes, nothing claims the list is empty', () {
    testWidgets(
      'Passport explains the failure instead of saying "No pet yet", and recovers',
      (tester) async {
        await _start(tester, failFirstLoad: true);
        await tester.tap(
          find.descendant(
            of: find.byType(PawTabBar),
            matching: find.text('Passport'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('No pet yet'), findsNothing);
        expect(find.text('We could not load the schedule.'), findsOneWidget);
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('We could not load the schedule.'), findsNothing);
        expect(find.text('Bingo'), findsWidgets);
      },
    );

    testWidgets('Schedule does the same', (tester) async {
      await _start(tester, failFirstLoad: true);
      _go(tester, '/schedule');
      await tester.pumpAndSettle();
      expect(find.text('Nothing scheduled'), findsNothing);
      expect(find.text('We could not load the schedule.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing scheduled'), findsOneWidget);
    });

    testWidgets('Notifications does the same', (tester) async {
      await _start(tester, failFirstLoad: true);
      _go(tester, '/notifications');
      await tester.pumpAndSettle();
      expect(find.text("You're all caught up"), findsNothing);
      expect(find.text('We could not load the schedule.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("You're all caught up"), findsOneWidget);
    });

    testWidgets('once loaded, an empty list is said plainly', (tester) async {
      await _start(tester, failFirstLoad: false);
      _go(tester, '/schedule');
      await tester.pumpAndSettle();
      expect(find.text('Nothing scheduled'), findsOneWidget);
    });
  });

  group('where a notification takes you', () {
    test('tab roots replace the screen', () {
      expect(notificationRoute('/passport'), (route: '/passport', root: true));
      expect(notificationRoute('/partner'), (route: '/partner', root: true));
      expect(notificationRoute('/partner/money'), (
        route: '/partner/money',
        root: true,
      ));
    });

    test('a shelter application opens the Applications tab', () {
      expect(notificationRoute('/applications/abc'), (
        route: '/partner/money',
        root: true,
      ));
    });

    test('orders, bookings, lost pets, transfers and listings open on top', () {
      for (final l in [
        '/schedule',
        '/bookings',
        '/orders',
        '/orders/123',
        '/lost/9',
        '/transfer/4',
        '/listing/2',
        '/partner/review',
      ]) {
        expect(notificationRoute(l), (route: l, root: false), reason: l);
      }
    });

    test('links this version does not know are ignored, not guessed', () {
      expect(notificationRoute(null), isNull);
      expect(notificationRoute(''), isNull);
      expect(notificationRoute('https://evil.example'), isNull);
      expect(notificationRoute('/schedulefoo'), isNull);
      expect(notificationRoute('/admin'), isNull);
      expect(notificationRoute('/orders-x'), isNull);
    });
  });
}
