import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'paw_icon.dart';

/// 44 circle with a chevron. Pops the current route unless [onPressed] is given.
class PawBackButton extends StatelessWidget {
  const PawBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      onTap: onPressed ?? () => Navigator.maybePop(context),
      child: Material(
        color: PawColors.surface,
        shape: const CircleBorder(side: BorderSide(color: PawColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () => Navigator.maybePop(context),
          child: const SizedBox(
            width: PawSize.touch,
            height: PawSize.touch,
            child: Center(
              child: PawIcon(PawIconData.chevronLeft, size: 20, strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}
