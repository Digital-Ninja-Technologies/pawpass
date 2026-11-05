import 'package:flutter/material.dart';

import 'tokens.dart';

/// Type scale from CLAUDE.md. Headings are Bricolage Grotesque 700,
/// everything else is Plus Jakarta Sans. Both are bundled in assets/fonts.
abstract final class PawText {
  static const _heading = 'BricolageGrotesque';
  static const _body = 'PlusJakartaSans';

  static const display36 = TextStyle(
    fontFamily: _heading,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: PawColors.ink,
  );
  static const title30 = TextStyle(
    fontFamily: _heading,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: PawColors.ink,
  );
  static const title28 = TextStyle(
    fontFamily: _heading,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: PawColors.ink,
  );
  static const heading22 = TextStyle(
    fontFamily: _heading,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: PawColors.ink,
  );

  static const button16 = TextStyle(
    fontFamily: _body,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: PawColors.ink,
  );
  static const button15 = TextStyle(
    fontFamily: _body,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: PawColors.ink,
  );

  static const body15 = TextStyle(
    fontFamily: _body,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: PawColors.ink,
  );
  static const body15Strong = TextStyle(
    fontFamily: _body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: PawColors.ink,
  );
  static const body14 = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: PawColors.ink,
  );
  static const body14Strong = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: PawColors.ink,
  );

  static const meta13 = TextStyle(
    fontFamily: _body,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: PawColors.muted,
  );
  static const meta12 = TextStyle(
    fontFamily: _body,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: PawColors.muted,
  );

  /// 12 at 700 with 4% tracking (0.04 x 12 = 0.48).
  static const overline12 = TextStyle(
    fontFamily: _body,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.48,
    color: PawColors.warmText,
  );

  /// Tab bar labels (11, from TabBar.dc.html).
  static const tab11 = TextStyle(
    fontFamily: _body,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: PawColors.muted,
  );
}
