import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Line icons copied from the designs: 24px grid, 1.8 stroke, round caps.
enum PawIconData {
  home(
    '<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>',
  ),
  passport(
    '<rect x="5" y="3" width="14" height="18" rx="2"/>'
    '<path d="M12 16s-3.5-2.2-3.5-4.5a1.9 1.9 0 0 1 3.5-1.2 1.9 1.9 0 0 1 3.5 1.2C15.5 13.8 12 16 12 16z"/>',
  ),
  calendar(
    '<rect x="3" y="5" width="18" height="16" rx="2"/>'
    '<path d="M3 10h18M8 3v4M16 3v4"/>',
  ),
  community(
    '<circle cx="9" cy="8" r="3.5"/>'
    '<path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 7M18 14a6 6 0 0 1 3.5 6"/>',
  ),
  paw(
    '<circle cx="7" cy="10" r="2"/><circle cx="17" cy="10" r="2"/>'
    '<circle cx="10" cy="6" r="2"/><circle cx="14" cy="6" r="2"/>'
    '<path d="M12 12c-3 0-5 3.5-5 5.5S9 20 12 20s5-.5 5-2.5S15 12 12 12z"/>',
  ),
  camera(
    '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
  ),
  chevronLeft('<path d="m15 6-6 6 6 6"/>'),
  chevronRight('<path d="m9 6 6 6-6 6"/>'),
  chevronDown('<path d="m6 9 6 6 6-6"/>'),
  check('<path d="m5 12.5 4.5 4.5L19 7.5"/>');

  const PawIconData(this.body);
  final String body;
}

class PawIcon extends StatelessWidget {
  const PawIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color = const Color(0xFF1F1A17),
    this.strokeWidth = 1.8,
    this.semanticLabel,
  });

  final PawIconData icon;
  final double size;
  final Color color;
  final double strokeWidth;

  /// Icons are decorative unless a label is given. Icon only buttons must label
  /// the button itself instead.
  final String? semanticLabel;

  String _svg() {
    final hex = (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="#$hex" stroke-width="$strokeWidth" stroke-linecap="round" '
        'stroke-linejoin="round">${icon.body}</svg>';
  }

  @override
  Widget build(BuildContext context) {
    final picture = SvgPicture.string(_svg(), width: size, height: size);
    if (semanticLabel == null) {
      return ExcludeSemantics(child: picture);
    }
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(child: picture),
    );
  }
}
