import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PawColors.primary,
    primary: PawColors.primary,
    surface: PawColors.surface,
    error: PawColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PawColors.ground,
    dividerColor: PawColors.border,
  );
}
