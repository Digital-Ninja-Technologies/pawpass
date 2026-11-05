import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/ui/ui.dart';

import 'harness.dart';

void main() {
  group('PawBackButton', () {
    testWidgets('is a labelled 44 point button', (tester) async {
      var taps = 0;
      await pumpPaw(tester, PawBackButton(onPressed: () => taps++));
      expect(tester.getSize(find.byType(PawBackButton)), const Size(44, 44));
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      await tester.tap(find.byType(PawBackButton));
      expect(taps, 1);
    });
  });

  group('PawStepProgress', () {
    testWidgets('announces the step and fills the right fraction', (
      tester,
    ) async {
      await pumpPaw(tester, const PawStepProgress(step: 5, total: 6));
      expect(find.bySemanticsLabel('Step 5 of 6'), findsOneWidget);
      final fill = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fill.widthFactor, closeTo(5 / 6, 0.001));
      expect(tester.getSize(find.byType(PawStepProgress)).height, 6);
    });

    test('rejects a step outside the range', () {
      expect(() => PawStepProgress(step: 0, total: 6), throwsAssertionError);
      expect(() => PawStepProgress(step: 7, total: 6), throwsAssertionError);
    });
  });

  group('PawTabBar', () {
    testWidgets('has the five owner tabs in order and 80 points of content', (
      tester,
    ) async {
      await pumpPaw(tester, PawTabBar(active: PawTab.home, onSelected: (_) {}));
      for (final label in ['Home', 'Passport', 'Book', 'Community', 'Adopt']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.getSize(find.byType(PawTabBar)).height, 80);
    });

    testWidgets('marks only the active tab selected', (tester) async {
      await pumpPaw(
        tester,
        PawTabBar(active: PawTab.passport, onSelected: (_) {}),
      );
      bool selected(String label) =>
          tester
              .getSemantics(find.bySemanticsLabel(label))
              .flagsCollection
              .isSelected ==
          Tristate.isTrue;
      expect(selected('Passport'), isTrue);
      expect(selected('Home'), isFalse);
      expect(selected('Adopt'), isFalse);
    });

    testWidgets('reports the tapped tab', (tester) async {
      PawTab? tapped;
      await pumpPaw(
        tester,
        PawTabBar(active: PawTab.home, onSelected: (t) => tapped = t),
      );
      await tester.tap(find.text('Community'));
      expect(tapped, PawTab.community);
    });

    testWidgets('every tab is at least 44 by 44', (tester) async {
      await pumpPaw(tester, PawTabBar(active: PawTab.home, onSelected: (_) {}));
      for (final label in ['Home', 'Passport', 'Book', 'Community', 'Adopt']) {
        final size = tester.getSize(
          find
              .ancestor(of: find.text(label), matching: find.byType(InkWell))
              .first,
        );
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });
  });

  group('PawStickyFooter', () {
    testWidgets(
      'stacks buttons with a 10 point gap and pads 26 at the bottom',
      (tester) async {
        await pumpPaw(
          tester,
          PawStickyFooter(
            children: [
              PawButton(label: 'Pay', onPressed: () {}),
              PawButton(
                label: 'Cancel',
                variant: PawButtonVariant.secondary,
                onPressed: () {},
              ),
            ],
          ),
        );
        // 14 top + 52 + 10 + 52 + 26 bottom + 1 border
        expect(
          tester.getSize(find.byType(PawStickyFooter)).height,
          14 + 52 + 10 + 52 + 26 + 1,
        );
      },
    );
  });

  group('PawListRow and PawCard', () {
    testWidgets('list row is at least 52 tall and taps', (tester) async {
      var taps = 0;
      await pumpPaw(
        tester,
        PawListRow(title: 'My bookings', onTap: () => taps++),
      );
      expect(
        tester.getSize(find.byType(PawListRow)).height,
        greaterThanOrEqualTo(52),
      );
      await tester.tap(find.text('My bookings'));
      expect(taps, 1);
    });

    testWidgets('card with onTap is a button', (tester) async {
      await pumpPaw(
        tester,
        PawCard(
          onTap: () {},
          semanticLabel: 'Bingo',
          child: const Text('Bingo'),
        ),
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Bingo').first)
            .flagsCollection
            .isButton,
        isTrue,
      );
    });
  });
}
