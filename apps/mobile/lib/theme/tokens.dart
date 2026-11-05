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
