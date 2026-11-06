import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum PawChipSize { regular, large }

/// Selectable pill. `regular` is 40 tall (filters), `large` is 48 (species picker).
class PawChip extends StatelessWidget {
  const PawChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.size = PawChipSize.regular,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final PawChipSize size;

  /// Fill the available width, for evenly spaced rows.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final large = size == PawChipSize.large;
    final height = large ? PawSize.chipLarge : PawSize.chip;
    final radius = BorderRadius.circular(height / 2);
    final style = (large ? PawText.body14 : PawText.meta13).copyWith(
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      color: selected ? Colors.white : PawColors.ink,
    );

    final pill = Material(
      color: selected ? PawColors.primary : PawColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: selected
            ? BorderSide.none
            : const BorderSide(color: PawColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: radius),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: expand ? null : 1,
              child: Text(label, style: style),
            ),
          ),
        ),
      ),
    );

    // The pill is 40 tall; the tap area, and what a screen reader focuses, is padded out to the 44 minimum.
    final chip = Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PawSize.touch),
          child: Center(
            heightFactor: 1,
            widthFactor: expand ? null : 1,
            child: pill,
          ),
        ),
      ),
    );

    return expand ? Expanded(child: chip) : chip;
  }
}
