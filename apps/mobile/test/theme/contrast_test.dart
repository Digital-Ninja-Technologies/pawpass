import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/theme/contrast.dart';
import 'package:pawpass/theme/tokens.dart';

void main() {
  group('contrastRatio', () {
    test('black on white is 21', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    });
    test('is symmetric', () {
      expect(
        contrastRatio(PawColors.ink, PawColors.ground),
        contrastRatio(PawColors.ground, PawColors.ink),
      );
    });
  });

  // Every text and background pair the design system uses must meet WCAG AA (4.5:1).
  final pairs = <String, (Color, Color)>{
    'ink on ground': (PawColors.ink, PawColors.ground),
    'ink on surface': (PawColors.ink, PawColors.surface),
    'ink2 on ground': (PawColors.ink2, PawColors.ground),
    'muted on ground': (PawColors.muted, PawColors.ground),
    'muted on surface': (PawColors.muted, PawColors.surface),
    'muted on subtle (segmented)': (PawColors.muted, PawColors.subtle),
    'ink on subtle': (PawColors.ink, PawColors.subtle),
    'white on primary (button, chip)': (Colors.white, PawColors.primary),
    'white on warm (lost button, badge)': (Colors.white, PawColors.warm),
    'white on danger (button)': (Colors.white, PawColors.danger),
    'primary on surface (active tab)': (PawColors.primary, PawColors.surface),
    'primaryText on primarySoft (verified)': (
      PawColors.primaryText,
      PawColors.primarySoft,
    ),
    'warmText on warmSoft (upcoming)': (PawColors.warmText, PawColors.warmSoft),
    'warmText on ground (overline)': (PawColors.warmText, PawColors.ground),
    'danger on dangerSoft': (PawColors.danger, PawColors.dangerSoft),
    'danger on surface (error text)': (PawColors.danger, PawColors.surface),
    'ink2 on disabled (disabled button)': (PawColors.ink2, PawColors.disabled),
    'ink2 on subtle (neutral badge)': (PawColors.ink2, PawColors.subtle),
  };

  for (final entry in pairs.entries) {
    test('${entry.key} meets WCAG AA', () {
      final (fg, bg) = entry.value;
      expect(contrastRatio(fg, bg), greaterThanOrEqualTo(wcagAaNormalText));
    });
  }
}
