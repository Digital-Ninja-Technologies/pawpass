import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// White surface with a 1px border. Radius is 18 to 24 depending on the card size.
class PawCard extends StatelessWidget {
  const PawCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PawSpace.s16),
    this.radius = PawRadius.card,
    this.color = PawColors.surface,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;

  /// Makes the whole card a button.
  final VoidCallback? onTap;

  /// Read by screen readers for tappable cards. Defaults to the card's own text.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: PawColors.border),
    );
    final body = Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
    if (onTap == null) return body;
    // With an explicit label, read only that label (not the label plus the child text).
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: body,
    );
  }
}
