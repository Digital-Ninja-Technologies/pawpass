import 'package:flutter/material.dart';

/// Design tokens from CLAUDE.md and design/screens/Specs.dc.html.
/// Mirrors packages/shared/src/tokens.ts: keep the two in step.
abstract final class PawColors {
  static const ground = Color(0xFFFFF8F1);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1F1A17);
  static const ink2 = Color(0xFF4A433E);
  static const muted = Color(0xFF6B625B);
  static const border = Color(0xFFEDE3D9);
  static const subtle = Color(0xFFF3EBE2);
  static const primary = Color(0xFF0E6B63);
  static const primarySoft = Color(0xFFE3F1EE);
  static const primaryText = Color(0xFF0B5650);
  static const warm = Color(0xFFB4501C);
  static const warmSoft = Color(0xFFFFEBD9);
  static const warmText = Color(0xFF9A3F0F);
  static const danger = Color(0xFFA3261B);
  static const dangerSoft = Color(0xFFFDEAE7);

  /// Unread dots, stars and decoration only. Never use for text.
  static const dot = Color(0xFFE0662A);

  /// Secondary button outline and dashed photo picker (from Specs).
  static const outline = Color(0xFFCFC3B7);

  /// Disabled button fill (from Specs). Text on it is [ink2].
  static const disabled = Color(0xFFDCD2C8);

  /// Photo and avatar fallbacks.
  static const petTints = [
    Color(0xFFF3D9C4),
    Color(0xFFDCE7F7),
    Color(0xFFF1E8FB),
    Color(0xFFCFE6E1),
  ];
}

/// Spacing scale from Specs: 4, 8, 10, 12, 14, 16, 18, 22.
abstract final class PawSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s22 = 22;

  /// Screen side padding. Onboarding uses [onboardingSide].
  static const double screenSide = 20;
  static const double onboardingSide = 24;
}

abstract final class PawRadius {
  static const double input = 16;
  static const double cardSmall = 18;
  static const double card = 24;
  static const double badge = 10;
}

abstract final class PawSize {
  /// Minimum touch target.
  static const double touch = 44;

  /// Primary buttons are 52 to 54 tall.
  static const double button = 52;
  static const double input = 52;
  static const double chip = 40;
  static const double chipLarge = 48;
  static const double tabBar = 80;
}

/// Course colours: one fun pair per course. [soft] is the card background, [strong] is for decoration only (stripes,
/// progress, confetti) and [text] is the dark ink for words on [soft] (it passes WCAG AA).
/// Mirrors `courseColors` in packages/shared/src/tokens.ts: keep the two in step.
class PawCourseColor {
  const PawCourseColor({
    required this.key,
    required this.label,
    required this.soft,
    required this.strong,
    required this.text,
  });

  final String key;
  final String label;
  final Color soft;
  final Color strong;
  final Color text;
}

abstract final class PawCourseColors {
  static const sunny = PawCourseColor(
    key: 'sunny',
    label: 'Sunny yellow',
    soft: Color(0xFFFFE08A),
    strong: Color(0xFFF5B300),
    text: Color(0xFF5C3D00),
  );
  static const coral = PawCourseColor(
    key: 'coral',
    label: 'Coral',
    soft: Color(0xFFFFD0C4),
    strong: Color(0xFFF26B4F),
    text: Color(0xFF8A2A14),
  );
  static const tangerine = PawCourseColor(
    key: 'tangerine',
    label: 'Tangerine',
    soft: Color(0xFFFFD9B0),
    strong: Color(0xFFF28C28),
    text: Color(0xFF7A3E05),
  );
  static const mint = PawCourseColor(
    key: 'mint',
    label: 'Mint',
    soft: Color(0xFFCFEFE0),
    strong: Color(0xFF2FB48A),
    text: Color(0xFF0B5040),
  );
  static const sky = PawCourseColor(
    key: 'sky',
    label: 'Sky blue',
    soft: Color(0xFFCFE4FF),
    strong: Color(0xFF3E86F5),
    text: Color(0xFF123F86),
  );
  static const grape = PawCourseColor(
    key: 'grape',
    label: 'Grape',
    soft: Color(0xFFE4D8FF),
    strong: Color(0xFF8B5CF6),
    text: Color(0xFF45228F),
  );
  static const lime = PawCourseColor(
    key: 'lime',
    label: 'Lime',
    soft: Color(0xFFE1F2B0),
    strong: Color(0xFF8DB81F),
    text: Color(0xFF3A5208),
  );
  static const rose = PawCourseColor(
    key: 'rose',
    label: 'Bubblegum',
    soft: Color(0xFFFFD1E3),
    strong: Color(0xFFE8508C),
    text: Color(0xFF8A1646),
  );

  static const all = [sunny, coral, tangerine, mint, sky, grape, lime, rose];

  /// Looks a colour up by its key (unknown keys fall back to [sunny], so an old app never breaks on a new colour).
  static PawCourseColor byKey(String key) =>
      all.firstWhere((c) => c.key == key, orElse: () => sunny);
}
