import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/core/offline_cache.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';
import 'package:pawpass/features/onboarding/data/repositories.dart';
import 'package:pawpass/features/onboarding/domain/models.dart';
import 'package:pawpass/ui/ui.dart';

final _today = DateTime(2026, 11, 5, 9);

Future<(AppServices, OfflineCache)> _rig(WidgetTester tester) async {
  final cache = OfflineCache(MemoryKeyValueStore(), now: () => _today);
  final services = inMemoryServices(
    now: () => _today,
    signedInAs: 'tolu@example.com',
    cache: cache,
  );
  final profiles = services.profiles as InMemoryProfileRepository;
  await profiles.save(firstName: 'Tolu');
  profiles.markOnboarded(_today);
  await services.pets.createPassport(
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
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(PawPassApp(services: services));
  await tester.pumpAndSettle();
  return (services, cache);
}

Future<void> _goOffline(WidgetTester tester, OfflineCache cache) async {
  // A read that fell back to the copy saved at 9am.
  await cache.fetch(key: 'k', load: () async => [1], parse: (j) => j);
  await cache.fetch(
    key: 'k',
    load: () async => throw const SocketException('no route'),
    parse: (j) => j,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no banner while the data is fresh', (tester) async {
    await _rig(tester);
    expect(find.textContaining("You're offline"), findsNothing);
  });

  testWidgets('Home, Passport and Schedule say when the saved copy is from', (
    tester,
  ) async {
    final (_, cache) = await _rig(tester);
    await _goOffline(tester, cache);
    expect(
      find.text("You're offline. Showing what was saved today at 9:00am."),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(PawTabBar),
        matching: find.text('Passport'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("You're offline"), findsOneWidget);
  });

  testWidgets(
    'Retry is offered, and the banner goes when the connection is back',
    (tester) async {
      final (_, cache) = await _rig(tester);
      await _goOffline(tester, cache);
      expect(find.text('Retry'), findsOneWidget);
      await cache.fetch(key: 'k', load: () async => [2], parse: (j) => j);
      await tester.pumpAndSettle();
      expect(find.textContaining("You're offline"), findsNothing);
    },
  );
}
