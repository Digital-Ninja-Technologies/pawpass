import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'paw_icon.dart';

/// A settings style row: at least 52 tall, subtle divider underneath, chevron by default.
class PawListRow extends StatelessWidget {
  const PawListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Replaces the default chevron (shown for tappable, non destructive rows).
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  /// Danger coloured title, for sign out or delete.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: PawColors.subtle))
            : null,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: PawText.body15Strong.copyWith(
                    color: destructive ? PawColors.danger : PawColors.ink,
                  ),
                ),
                if (subtitle != null) Text(subtitle!, style: PawText.meta13),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null && !destructive)
            const PawIcon(
              PawIconData.chevronRight,
              size: 20,
              color: PawColors.muted,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
