import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'paw_button.dart';
import 'paw_icon.dart';

/// Where an empty or error view gets its colour. Matches design/screens/EmptyStates and ErrorStates.
enum PawStateTone {
  /// Calm and positive: nothing yet, add something.
  teal(PawColors.primarySoft, PawColors.primaryText),

  /// Neutral: all caught up, nothing found, offline.
  neutral(PawColors.subtle, PawColors.ink2),

  /// Lost pets and things that need a look.
  warm(PawColors.warmSoft, PawColors.warmText),

  /// Something failed (always with an icon and words, never colour alone).
  danger(PawColors.dangerSoft, PawColors.danger),

  /// Community.
  blue(Color(0xFFDCE7F7), Color(0xFF23407A));

  const PawStateTone(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

/// Shown in place of a list that has nothing in it yet. One icon, one title, one sentence on what will
/// appear, and at most one main action and one quiet link.
class PawEmptyState extends StatelessWidget {
  const PawEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = PawStateTone.teal,
    this.actionLabel,
    this.onAction,
    this.linkLabel,
    this.onLink,
  });

  final PawIconData icon;
  final String title;
  final String message;
  final PawStateTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) => _StateBody(
    icon: icon,
    title: title,
    message: message,
    tone: tone,
    actionLabel: actionLabel,
    onAction: onAction,
    linkLabel: linkLabel,
    onLink: onLink,
  );
}

/// Shown when something could not be done. Say what happened in plain words, whether anything was lost or
/// charged, and offer one way forward. Never shows codes or technical text.
class PawErrorState extends StatelessWidget {
  const PawErrorState({
    super.key,
    required this.title,
    required this.message,
    this.icon = PawIconData.alertTriangle,
    this.tone = PawStateTone.warm,
    this.actionLabel = 'Try again',
    this.onAction,
    this.linkLabel,
    this.onLink,
  });

  final String title;
  final String message;
  final PawIconData icon;
  final PawStateTone tone;
  final String actionLabel;
  final VoidCallback? onAction;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) => _StateBody(
    icon: icon,
    title: title,
    message: message,
    tone: tone,
    actionLabel: onAction == null ? null : actionLabel,
    onAction: onAction,
    linkLabel: linkLabel,
    onLink: onLink,
  );
}

class _StateBody extends StatelessWidget {
  const _StateBody({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
    this.actionLabel,
    this.onAction,
    this.linkLabel,
    this.onLink,
  });

  final PawIconData icon;
  final String title;
  final String message;
  final PawStateTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: tone.background,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: PawIcon(icon, size: 40, color: tone.foreground),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: PawText.heading22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: PawText.body14.copyWith(color: PawColors.ink2),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                PawButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                  height: 48,
                ),
              ],
              if (linkLabel != null && onLink != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onLink,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(PawSize.touch, PawSize.touch),
                    foregroundColor: PawColors.primaryText,
                  ),
                  child: Text(
                    linkLabel!,
                    style: PawText.body14Strong.copyWith(
                      color: PawColors.primaryText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
