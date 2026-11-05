import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A bordered row with a label and a checkbox, the whole row is the tap target.
class PawToggleRow extends StatelessWidget {
  const PawToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(PawRadius.input);
    final enabled = onChanged != null;
    return Semantics(
      container: true,
      checked: value,
      enabled: enabled,
      label: subtitle == null ? label : '$label, $subtitle',
      excludeSemantics: true,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Material(
        color: PawColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: PawColors.border),
        ),
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PawSize.input),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: PawText.body14Strong),
                        if (subtitle != null)
                          Text(subtitle!, style: PawText.meta12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: ExcludeSemantics(
                      child: Checkbox(
                        value: value,
                        onChanged: enabled
                            ? (v) => onChanged!(v ?? false)
                            : null,
                        activeColor: PawColors.primary,
                        checkColor: Colors.white,
                        side: const BorderSide(
                          color: PawColors.outline,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
