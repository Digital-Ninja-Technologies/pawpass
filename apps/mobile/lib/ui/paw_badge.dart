import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'paw_icon.dart';

enum PawBadgeTone {
  /// "Vet verified", trust notes.
  verified,

  /// Upcoming reminders, alerts.
  upcoming,

  /// LOST pet marker.
  lost,

  /// Errors and emergencies.
  danger,

  /// Neutral status.
  neutral,
}

/// Small status label. Status is always carried by the text (and a tick for
/// verified), never by colour alone.
class PawBadge extends StatelessWidget {
  const PawBadge(this.label, {super.key, this.tone = PawBadgeTone.neutral});

  const PawBadge.verified(this.label, {super.key})
    : tone = PawBadgeTone.verified;

  final String label;
  final PawBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, FontWeight weight) = switch (tone) {
      PawBadgeTone.verified => (
        PawColors.primarySoft,
        PawColors.primaryText,
        FontWeight.w700,
      ),
      PawBadgeTone.upcoming => (
        PawColors.warmSoft,
        PawColors.warmText,
        FontWeight.w700,
      ),
      PawBadgeTone.lost => (PawColors.warm, Colors.white, FontWeight.w800),
      PawBadgeTone.danger => (
        PawColors.dangerSoft,
        PawColors.danger,
        FontWeight.w700,
      ),
      PawBadgeTone.neutral => (
        PawColors.subtle,
        PawColors.ink2,
        FontWeight.w700,
      ),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(PawRadius.badge),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tone == PawBadgeTone.verified) ...[
                PawIcon(
                  PawIconData.check,
                  size: 12,
                  color: fg,
                  strokeWidth: 2.4,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: weight,
                  height: 1.3,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
