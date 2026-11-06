import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class PawSegment<T> {
  const PawSegment(this.value, this.label);
  final T value;
  final String label;
}

/// Tab like segmented control on a subtle track. The active segment is a white pill.
class PawSegmented<T> extends StatelessWidget {
  const PawSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<PawSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PawColors.subtle,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            for (final s in segments)
              Expanded(
                child: _Segment(
                  label: s.label,
                  selected: s.value == value,
                  onTap: () => onChanged(s.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? PawColors.surface : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: PawSize.touch,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PawText.meta13.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? PawColors.ink : PawColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
