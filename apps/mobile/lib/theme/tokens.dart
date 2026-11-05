import 'package:flutter/material.dart';

/// Design tokens from CLAUDE.md. Mirrors packages/shared/src/tokens.ts.
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

  /// Unread dots, stars and decoration only.
  static const dot = Color(0xFFE0662A);

  static const petTints = [
    Color(0xFFF3D9C4),
    Color(0xFFDCE7F7),
    Color(0xFFF1E8FB),
    Color(0xFFCFE6E1),
  ];
}
