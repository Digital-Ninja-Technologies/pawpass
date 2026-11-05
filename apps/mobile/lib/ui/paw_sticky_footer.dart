import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Action bar pinned to the bottom of a screen: white, 1px top border,
/// 14 / 20 / 26 padding (extra room for the home indicator on newer phones).
class PawStickyFooter extends StatelessWidget {
  const PawStickyFooter({
    super.key,
    required this.children,
    this.axis = Axis.vertical,
  });

  final List<Widget> children;

  /// `vertical` stacks buttons, `horizontal` puts them side by side (Expanded).
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(26.0, MediaQuery.viewPaddingOf(context).bottom);
    return Container(
      decoration: const BoxDecoration(
        color: PawColors.surface,
        border: Border(top: BorderSide(color: PawColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PawSpace.screenSide,
          14,
          PawSpace.screenSide,
          bottom,
        ),
        child: axis == Axis.vertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: PawSpace.s10),
                    children[i],
                  ],
                ],
              )
            : Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: PawSpace.s10),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
      ),
    );
  }
}
