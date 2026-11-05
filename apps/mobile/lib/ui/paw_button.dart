import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum PawButtonVariant {
  /// Main action.
  primary,

  /// Quiet action with an outline.
  secondary,

  /// Lost pet actions only.
  warm,

  /// Destructive or emergency actions.
  danger,
}

/// Pill button, 52 tall. Passing a null [onPressed] shows the disabled style.
class PawButton extends StatelessWidget {
  const PawButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PawButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.height = PawSize.button,
  });

  final String label;
  final VoidCallback? onPressed;
  final PawButtonVariant variant;

  /// Shows a spinner and ignores taps while work is in progress.
  final bool loading;

  /// Fill the available width (default) or hug the label.
  final bool expand;
  final double height;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, BorderSide side) = _enabled || loading
        ? switch (variant) {
            PawButtonVariant.primary => (
              PawColors.primary,
              Colors.white,
              BorderSide.none,
            ),
            PawButtonVariant.secondary => (
              PawColors.surface,
              PawColors.ink,
              const BorderSide(color: PawColors.outline, width: 1.5),
            ),
            PawButtonVariant.warm => (
              PawColors.warm,
              Colors.white,
              BorderSide.none,
            ),
            PawButtonVariant.danger => (
              PawColors.danger,
              Colors.white,
              BorderSide.none,
            ),
          }
        : (PawColors.disabled, PawColors.ink2, BorderSide.none);

    final radius = BorderRadius.circular(height / 2);
    final content = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        : Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PawText.button15.copyWith(color: fg),
          );

    final button = Semantics(
      button: true,
      enabled: _enabled,
      label: loading ? '$label, loading' : label,
      excludeSemantics: true,
      onTap: _enabled ? onPressed : null,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: radius, side: side),
        child: InkWell(
          onTap: _enabled ? onPressed : null,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: height,
              minWidth: PawSize.touch,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                heightFactor: 1,
                widthFactor: expand ? null : 1,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
