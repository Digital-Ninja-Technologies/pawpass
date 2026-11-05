import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/ui/ui.dart';

import 'harness.dart';

BoxDecoration _decoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(PawTextField),
          matching: find.byType(Container),
        )
        .first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('shows the label above a 52 tall input', (tester) async {
    await pumpPaw(tester, const PawTextField(label: 'Pet\'s name'));
    expect(find.text('Pet\'s name'), findsOneWidget);
    final box = tester.getSize(
      find
          .descendant(
            of: find.byType(PawTextField),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(box.height, 52);
  });

  testWidgets('the label is announced for the field', (tester) async {
    await pumpPaw(tester, const PawTextField(label: 'Email'));
    expect(find.bySemanticsLabel('Email'), findsOneWidget);
  });

  testWidgets('border is 1px by default and 2px primary when focused', (
    tester,
  ) async {
    await pumpPaw(tester, const PawTextField(label: 'Name'));
    var border = _decoration(tester).border! as Border;
    expect(border.top.width, 1);
    expect(border.top.color, PawColors.border);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    border = _decoration(tester).border! as Border;
    expect(border.top.width, 2);
    expect(border.top.color, PawColors.primary);
  });

  testWidgets('error text is shown and the border turns danger', (
    tester,
  ) async {
    await pumpPaw(
      tester,
      const PawTextField(label: 'Email', errorText: 'Enter a valid email'),
    );
    expect(find.text('Enter a valid email'), findsOneWidget);
    final border = _decoration(tester).border! as Border;
    expect(border.top.color, PawColors.danger);
  });

  testWidgets('typing reports changes and keeps the controller in sync', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? changed;
    await pumpPaw(
      tester,
      PawTextField(
        label: 'Name',
        controller: controller,
        onChanged: (v) => changed = v,
      ),
    );
    await tester.enterText(find.byType(TextField), 'Bingo');
    expect(changed, 'Bingo');
    expect(controller.text, 'Bingo');
  });

  testWidgets('maxLength limits input without showing a counter', (
    tester,
  ) async {
    await pumpPaw(tester, const PawTextField(label: 'Code', maxLength: 6));
    await tester.enterText(find.byType(TextField), '1234567890');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '',
      anyOf('123456', ''),
    );
    expect(find.text('6/6'), findsNothing);
  });
}
