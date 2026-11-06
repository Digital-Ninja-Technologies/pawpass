import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../../../ui/ui.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../../onboarding/ui/onboarding_page.dart' show PickerField, pickDate;
import '../domain/models.dart';

/// A round pet picture: the photo when there is one, otherwise a tinted circle with the first letter.
class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.pet, this.size = 32, this.radius});

  final Pet pet;
  final double size;

  /// Corner radius; defaults to a circle.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final url = AppScope.of(context).health.photoUrlFor(pet.id);
    final r = radius ?? size / 2;
    final tint =
        PawColors.petTints[pet.name.codeUnits.fold<int>(0, (a, b) => a + b) %
            PawColors.petTints.length];
    final fallback = ColoredBox(
      color: tint,
      child: Center(
        child: Text(
          pet.name.isEmpty ? '?' : pet.name[0].toUpperCase(),
          style: PawText.heading22.copyWith(
            fontSize: size * 0.42,
            color: PawColors.warmText,
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback,
                ),
        ),
      ),
    );
  }
}

/// 44 circle button with an icon, used for back, bell, share and add.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.filled = false,
    this.dot = false,
    this.background,
    this.iconColor,
  });

  final PawIconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  /// Solid primary fill with a white icon (the "add" button).
  final bool filled;

  /// The small orange "unread" dot.
  final bool dot;
  final Color? background;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? (filled ? PawColors.primary : PawColors.surface);
    final fg = iconColor ?? (filled ? Colors.white : PawColors.ink);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: bg,
        shape: CircleBorder(
          side: filled || background != null
              ? BorderSide.none
              : const BorderSide(color: PawColors.border),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: PawSize.touch,
            height: PawSize.touch,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PawIcon(icon, size: 22, color: fg),
                if (dot)
                  const Positioned(
                    top: 10,
                    right: 11,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: PawColors.dot,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 8, height: 8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "NOV" over "12", for schedule rows.
class DateBadge extends StatelessWidget {
  const DateBadge(this.date, {super.key, this.soon = false, this.width = 46});
  final DateTime date;
  final bool soon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Text(
              monthAbbrUpper(date),
              style: PawText.meta12.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: soon ? PawColors.warmText : PawColors.muted,
              ),
            ),
            Text('${date.day}', style: PawText.heading22),
          ],
        ),
      ),
    );
  }
}

/// A small spaced caps heading ("THIS MONTH").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color = PawColors.muted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: PawText.overline12.copyWith(color: color),
      ),
    );
  }
}

/// Shown when something could not load, with a way to try again.
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: PawText.body15),
            const SizedBox(height: 16),
            PawButton(label: 'Try again', expand: false, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

/// Asks when a dose was given, then confirms. Returns the date, or null if dismissed.
Future<DateTime?> showMarkDoneSheet(
  BuildContext context, {
  required Reminder reminder,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PawColors.surface,
    showDragHandle: true,
    builder: (_) => _MarkDoneSheet(reminder: reminder),
  );
}

class _MarkDoneSheet extends StatefulWidget {
  const _MarkDoneSheet({required this.reminder});
  final Reminder reminder;

  @override
  State<_MarkDoneSheet> createState() => _MarkDoneSheetState();
}

class _MarkDoneSheetState extends State<_MarkDoneSheet> {
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    final today = AppScope.of(context).health.today;
    final date = _date ?? today;
    final r = widget.reminder;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        PawSpace.screenSide,
        0,
        PawSpace.screenSide,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Mark as done', style: PawText.title28),
            ),
            const SizedBox(height: 6),
            Text(
              '${r.label} for ${r.petName}. We will add it to the passport and schedule the next one.',
              style: PawText.body15.copyWith(
                color: PawColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            PickerField(
              label: 'Date given',
              value: date == today
                  ? 'Today, ${formatDate(date)}'
                  : formatDate(date),
              onTap: () async {
                final d = await pickDate(
                  context,
                  first: DateTime(today.year - 5),
                  last: today,
                  initial: date,
                  help: 'When was it given?',
                );
                if (d != null) setState(() => _date = d);
              },
              trailing: const PawIcon(
                PawIconData.calendar,
                size: 18,
                color: PawColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            PawButton(
              label: 'Mark as done',
              onPressed: () => Navigator.pop(context, date),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bordered tappable row: icon tile, title and subtitle (settings and tab placeholders).
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.body,
    this.icon,
  });
  final String title;
  final String body;
  final PawIconData? icon;

  @override
  Widget build(BuildContext context) {
    return PawCard(
      radius: PawRadius.cardSmall,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            PawIcon(icon!, color: PawColors.primary),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PawText.body15Strong),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: PawText.meta13.copyWith(
                    color: PawColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when what is on screen is a saved copy because the phone has no signal. Says when it was saved, and offers
/// to try again. Nothing here can be changed until the connection is back, and the app says so when you try.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.onRetry});
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final cache = scope.services.cache;
    if (cache == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: cache,
      builder: (context, _) {
        final at = cache.staleSince;
        if (at == null) {
          return const SizedBox.shrink();
        }
        final text =
            "You're offline. Showing what was saved ${savedAtLabel(at, scope.services.now())}.";
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              decoration: BoxDecoration(
                color: PawColors.warmSoft,
                borderRadius: BorderRadius.circular(PawRadius.cardSmall),
              ),
              child: Row(
                children: [
                  const PawIcon(
                    PawIconData.alertTriangle,
                    size: 20,
                    color: PawColors.warmText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: PawText.meta13.copyWith(color: PawColors.warmText),
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(PawSize.touch, PawSize.touch),
                        foregroundColor: PawColors.warmText,
                      ),
                      child: Text(
                        'Retry',
                        style: PawText.body14Strong.copyWith(
                          color: PawColors.warmText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// What to show in place of a list while the first load has not finished: a spinner, or the reason it failed with a
/// way to try again. Without this an empty screen would claim "nothing here" when the truth is "we do not know yet".
class FirstLoad extends StatelessWidget {
  const FirstLoad({super.key, required this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: error != null
          ? LoadError(message: error!, onRetry: onRetry)
          : Semantics(
              label: 'Loading',
              liveRegion: true,
              child: const Center(child: CircularProgressIndicator()),
            ),
    );
  }
}
