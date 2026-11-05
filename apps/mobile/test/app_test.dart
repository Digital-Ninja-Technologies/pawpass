import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/app.dart';
import 'package:pawpass/features/onboarding/data/in_memory.dart';

void main() {
  testWidgets('a signed out visitor lands on the welcome screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(PawPassApp(services: inMemoryServices()));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });

  test('the welcome illustration photo is bundled with the app', () async {
    final data = await rootBundle.load('assets/images/welcome_pet.jpg');
    expect(data.lengthInBytes, greaterThan(1000));
  });
}
