import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/ui/ui.dart';

import 'harness.dart';

void main() {
  testWidgets('is 52 tall and fills the width', (tester) async {
    await pumpPaw(tester, PawButton(label: 'Continue', onPressed: () {}));
    final size = tester.getSize(find.byType(PawButton));
    expect(size.height, 52);
    expect(size.width, 350); // 390 minus 20 padding each side
  });

  testWidgets('calls onPressed when tapped', (tester) async {
    var taps = 0;
    await pumpPaw(
      tester,
      PawButton(label: 'Continue', onPressed: () => taps++),
    );
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
  });

  testWidgets('null onPressed is disabled and does not fire', (tester) async {
    await pumpPaw(tester, const PawButton(label: 'Continue', onPressed: null));
    await tester.tap(find.text('Continue'), warnIfMissed: false);
    final semantics = tester.getSemantics(find.bySemanticsLabel('Continue'));
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('loading ignores taps and says so to screen readers', (
    tester,
  ) async {
    var taps = 0;
    await pumpPaw(
      tester,
      PawButton(label: 'Save', loading: true, onPressed: () => taps++),
      settle: false, // the spinner animates forever
    );
    await tester.tap(find.byType(PawButton), warnIfMissed: false);
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Save, loading'), findsOneWidget);
  });

  testWidgets('exposes the label as a button', (tester) async {
    await pumpPaw(tester, PawButton(label: 'Continue', onPressed: () {}));
    expect(find.bySemanticsLabel('Continue'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Continue'))
          .flagsCollection
          .isButton,
      isTrue,
    );
  });

  testWidgets('variants use the design colours', (tester) async {
    Color fillOf(WidgetTester t) => t
        .widget<Material>(
          find
              .descendant(
                of: find.byType(PawButton),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;

    await pumpPaw(tester, PawButton(label: 'x', onPressed: () {}));
    expect(fillOf(tester), PawColors.primary);
    await pumpPaw(
      tester,
      PawButton(label: 'x', variant: PawButtonVariant.warm, onPressed: () {}),
    );
    expect(fillOf(tester), PawColors.warm);
    await pumpPaw(
      tester,
      PawButton(label: 'x', variant: PawButtonVariant.danger, onPressed: () {}),
    );
    expect(fillOf(tester), PawColors.danger);
    await pumpPaw(
      tester,
      PawButton(
        label: 'x',
        variant: PawButtonVariant.secondary,
        onPressed: () {},
      ),
    );
    expect(fillOf(tester), PawColors.surface);
    await pumpPaw(tester, const PawButton(label: 'x', onPressed: null));
    expect(fillOf(tester), PawColors.disabled);
  });
}
