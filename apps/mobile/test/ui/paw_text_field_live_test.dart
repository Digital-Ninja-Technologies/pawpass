import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/ui/ui.dart';

void main() {
  Widget host(TextEditingController c) => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          PawTextField(
            label: 'Email',
            controller: c,
            validator: (t) => t.contains('@') ? null : 'Needs an at sign.',
          ),
          const TextField(key: Key('other')),
        ],
      ),
    ),
  );

  testWidgets('the message waits for a pause, then follows every key press', (
    tester,
  ) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));
    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.pump();
    expect(find.text('Needs an at sign.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Needs an at sign.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'abc@');
    await tester.pump();
    expect(find.text('Needs an at sign.'), findsNothing);
  });

  testWidgets('leaving the field shows the message straight away', (
    tester,
  ) async {
    final c = TextEditingController();
    await tester.pumpWidget(host(c));
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    expect(find.text('Needs an at sign.'), findsOneWidget);
  });
}
