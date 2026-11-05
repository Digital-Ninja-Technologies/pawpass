import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Onboarding progress bar, 6 tall. `step` is 1 based ("Step 5 of 6").
class PawStepProgress extends StatelessWidget {
  const PawStepProgress({super.key, required this.step, required this.total})
    : assert(total > 0),
      assert(step >= 1 && step <= total);

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $step of $total',
      value: '${(step / total * 100).round()}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            color: PawColors.border,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: step / total),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              builder: (context, f, _) => FractionallySizedBox(
                widthFactor: f,
                child: const SizedBox(
                  height: 6,
                  child: ColoredBox(color: PawColors.primary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
