import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/ui/ui.dart';

import 'harness.dart';

void main() {
  group('PawChip', () {
    testWidgets('reports selection to screen readers and taps', (tester) async {
      var taps = 0;
      await pumpPaw(
        tester,
        PawChip(label: 'Dog', selected: true, onTap: () => taps++),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('Dog'));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      await tester.tap(find.text('Dog'));
      expect(taps, 1);
    });

    testWidgets('keeps a 44 point tap area even though the pill is 40', (
      tester,
    ) async {
      await pumpPaw(
        tester,
        PawChip(label: 'Default', selected: false, onTap: () {}),
      );
      expect(
        tester.getSize(find.byType(PawChip)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('large chips are 48 tall', (tester) async {
      await pumpPaw(
        tester,
        PawChip(
          label: 'Cat',
          selected: false,
          size: PawChipSize.large,
          onTap: () {},
        ),
      );
      expect(
        tester.getSize(find.byType(PawChip)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('PawBadge', () {
    testWidgets('verified shows a tick and the words, not just colour', (
      tester,
    ) async {
      await pumpPaw(tester, const PawBadge.verified('Vet verified'));
      expect(find.text('Vet verified'), findsOneWidget);
      expect(find.byType(PawIcon), findsOneWidget);
      expect(find.bySemanticsLabel('Vet verified'), findsOneWidget);
    });
  });

  group('PawSegmented', () {
    testWidgets('selects a segment and marks it selected', (tester) async {
      String value = 'Health';
      await pumpPaw(
        tester,
        StatefulBuilder(
          builder: (context, setState) => PawSegmented<String>(
            segments: const [
              PawSegment('Health', 'Health'),
              PawSegment('Origin', 'Origin'),
            ],
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      await tester.tap(find.text('Origin'));
      await tester.pumpAndSettle();
      expect(value, 'Origin');
      final origin = tester.getSemantics(find.bySemanticsLabel('Origin'));
      expect(origin.flagsCollection.isSelected, Tristate.isTrue);
    });

    testWidgets('segments are 40 tall inside a 4 point track', (tester) async {
      await pumpPaw(
        tester,
        PawSegmented<int>(
          segments: const [PawSegment(1, 'A'), PawSegment(2, 'B')],
          value: 1,
          onChanged: (_) {},
        ),
      );
      expect(tester.getSize(find.byType(PawSegmented<int>)).height, 48);
    });
  });

  group('PawToggleRow', () {
    testWidgets('tapping anywhere on the row toggles', (tester) async {
      bool value = false;
      await pumpPaw(
        tester,
        StatefulBuilder(
          builder: (context, setState) => PawToggleRow(
            label: 'Push notifications',
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      await tester.tap(find.text('Push notifications'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    testWidgets('exposes checked state and label', (tester) async {
      await pumpPaw(
        tester,
        PawToggleRow(label: 'WhatsApp', value: true, onChanged: (_) {}),
      );
      final node = tester.getSemantics(find.byType(PawToggleRow));
      expect(node.flagsCollection.isChecked, CheckedState.isTrue);
      expect(node.label, 'WhatsApp');
    });

    testWidgets('is at least 52 tall', (tester) async {
      await pumpPaw(
        tester,
        PawToggleRow(label: 'x', value: false, onChanged: (_) {}),
      );
      expect(
        tester.getSize(find.byType(PawToggleRow)).height,
        greaterThanOrEqualTo(52),
      );
    });
  });
}
