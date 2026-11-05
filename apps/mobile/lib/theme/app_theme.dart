import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: PawColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: PawColors.primary,
        onPrimary: Colors.white,
        surface: PawColors.surface,
        onSurface: PawColors.ink,
        error: PawColors.danger,
        outline: PawColors.border,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: PawColors.ground,
    dividerColor: PawColors.border,
    textTheme: Typography.blackMountainView.apply(
      fontFamily: 'PlusJakartaSans',
      bodyColor: PawColors.ink,
      displayColor: PawColors.ink,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: PawColors.primary,
      selectionColor: PawColors.primary.withValues(alpha: 0.25),
      selectionHandleColor: PawColors.primary,
    ),
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: PawColors.ground,
      foregroundColor: PawColors.ink,
      elevation: 0,
      titleTextStyle: PawText.heading22,
    ),
  );
}
