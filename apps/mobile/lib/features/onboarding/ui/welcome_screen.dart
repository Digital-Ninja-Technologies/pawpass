import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';

/// Welcome: green screen, a little passport illustration, and two ways in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawColors.primary,
      body: LayoutBuilder(
        builder: (context, c) {
          // The illustration shrinks on short phones; the rest scrolls if text is made larger.
          final illustrationHeight = (c.maxHeight * 0.47).clamp(170.0, 400.0);
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        height: illustrationHeight,
                        width: double.infinity,
                        child: const FittedBox(child: _Illustration()),
                      ),
                    ),
                    Expanded(
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'PawPass',
                                style: PawText.heading22.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 18,
                                  letterSpacing: 0.36,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Semantics(
                                header: true,
                                child: Text(
                                  "Every pet's life,\nin one place.",
                                  style: PawText.display36.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Health records and reminders, trusted vets and groomers, '
                                'a community nearby, and verified breeders.',
                                style: PawText.body15.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const ExcludeSemantics(child: _Dots()),
                              const SizedBox(height: 24),
                              const Spacer(),
                              _WelcomeButton(
                                label: 'Get started',
                                filled: true,
                                onPressed: () => context.push('/sign-in'),
                              ),
                              const SizedBox(height: 10),
                              _WelcomeButton(
                                label: 'I already have an account',
                                filled: false,
                                onPressed: () => context.push('/sign-in'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WelcomeButton extends StatelessWidget {
  const _WelcomeButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(27);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: filled ? Colors.white : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: filled
              ? BorderSide.none
              : BorderSide(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1.5,
                ),
        ),
        child: InkWell(
          onTap: onPressed,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: SizedBox(
            height: 54,
            child: Center(
              child: Text(
                label,
                style: (filled ? PawText.button16 : PawText.button15).copyWith(
                  color: filled ? PawColors.ink : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    Widget dot(bool on) => Container(
      width: on ? 22 : 6,
      height: 6,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: on ? Colors.white : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Row(children: [dot(true), dot(false), dot(false)]);
  }
}

/// The tilted passport card with Bingo on it, drawn from the design's measurements (390 x 400).
class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: 390,
        height: 400,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _circle(left: -40, top: 60, size: 220, alpha: 0.08),
            _circle(right: -60, top: 150, size: 260, alpha: 0.06),
            Positioned(
              left: 95,
              top: 110,
              child: Transform.rotate(
                angle: -6 * 3.14159265 / 180,
                child: Container(
                  width: 200,
                  height: 230,
                  decoration: BoxDecoration(
                    color: PawColors.ground,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E000000),
                        blurRadius: 40,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 23,
                        top: 25,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/welcome_pet.jpg',
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      _bar(
                        left: 109,
                        top: 32,
                        w: 70,
                        h: 12,
                        color: const Color(0xD91F1A17),
                      ),
                      _bar(
                        left: 111,
                        top: 56,
                        w: 50,
                        h: 10,
                        color: PawColors.outline,
                      ),
                      _bar(
                        left: 33,
                        top: 122,
                        w: 140,
                        h: 10,
                        color: const Color(0xFFCFE6E1),
                      ),
                      _bar(
                        left: 37,
                        top: 146,
                        w: 110,
                        h: 10,
                        color: const Color(0xFFCFE6E1),
                      ),
                      _bar(
                        left: 43,
                        top: 172,
                        w: 74,
                        h: 24,
                        color: PawColors.warmSoft,
                        r: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 260,
              top: 280,
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: PawColors.dot,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: PawIcon(
                    PawIconData.paw,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle({
    double? left,
    double? right,
    required double top,
    required double size,
    required double alpha,
  }) => Positioned(
    left: left,
    right: right,
    top: top,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: alpha),
        shape: BoxShape.circle,
      ),
    ),
  );

  Widget _bar({
    required double left,
    required double top,
    required double w,
    required double h,
    required Color color,
    double? r,
  }) => Positioned(
    left: left,
    top: top,
    child: Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r ?? h / 2),
      ),
    ),
  );
}
