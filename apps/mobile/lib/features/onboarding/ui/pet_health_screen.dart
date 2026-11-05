import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dates.dart';
import '../../../ui/ui.dart';
import '../domain/reminder_schedule.dart';
import '../state/app_scope.dart';
import 'onboarding_page.dart';

/// "Bingo's health so far": tick what the pet has had and when it was last given.
///
/// Scanning a paper vaccine card needs a text recognition service that is not built yet, so it is
/// not offered here (see the milestone 2 notes).
class PetHealthScreen extends StatelessWidget {
  const PetHealthScreen({super.key});

  Future<void> _tick(BuildContext context, VaccineKind kind) async {
    final ob = AppScope.of(context).onboarding;
    if (ob.given.containsKey(kind)) {
      ob.setGiven(kind, null);
      return;
    }
    await _setDate(context, kind);
  }

  Future<void> _setDate(BuildContext context, VaccineKind kind) async {
    final ob = AppScope.of(context).onboarding;
    final today = ob.today;
    final first = ob.dateOfBirth ?? DateTime(today.year - 30);
    final d = await pickDate(
      context,
      first: first.isAfter(today) ? today : first,
      last: today,
      initial: ob.given[kind] ?? today,
      help: 'When was ${kind.nameFor(ob.species)} last given?',
    );
    if (d != null) ob.setGiven(kind, d);
  }

  @override
  Widget build(BuildContext context) {
    final ob = AppScope.of(context).onboarding;
    return ListenableBuilder(
      listenable: ob,
      builder: (context, _) => OnboardingPage(
        step: 6,
        title: '${ob.petPossessive} health so far',
        subtitle: "Add past vaccines so we can schedule what's next.",
        gap: 18,
        trailing: TextLinkButton(
          label: 'Skip',
          color: PawColors.muted,
          alignment: Alignment.centerRight,
          onPressed: () {
            ob.given.clear();
            context.push('/reminders');
          },
        ),
        form: [
          Row(
            children: [
              const Expanded(child: Divider(color: PawColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Tick what ${ob.petNameOrFallback} has had',
                  style: PawText.meta13.copyWith(color: PawColors.muted),
                ),
              ),
              const Expanded(child: Divider(color: PawColors.border)),
            ],
          ),
          Semantics(
            container: true,
            label: 'Past vaccines',
            child: Column(
              children: [
                for (final k in VaccineKind.values) ...[
                  if (k != VaccineKind.values.first) const SizedBox(height: 8),
                  _VaccineRow(
                    title: k.nameFor(ob.species),
                    date: ob.given[k],
                    onToggle: () => _tick(context, k),
                    onEditDate: () => _setDate(context, k),
                  ),
                ],
              ],
            ),
          ),
        ],
        footer: [
          PawButton(
            label: 'Save health history',
            onPressed: () => context.push('/reminders'),
          ),
        ],
      ),
    );
  }
}

class _VaccineRow extends StatelessWidget {
  const _VaccineRow({
    required this.title,
    required this.date,
    required this.onToggle,
    required this.onEditDate,
  });

  final String title;
  final DateTime? date;
  final VoidCallback onToggle;
  final VoidCallback onEditDate;

  @override
  Widget build(BuildContext context) {
    final on = date != null;
    final radius = BorderRadius.circular(18);
    return Material(
      color: PawColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: PawColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              checked: on,
              label: on
                  ? '$title, last given ${formatDate(date!)}'
                  : '$title, not added',
              excludeSemantics: true,
              onTap: onToggle,
              child: InkWell(
                onTap: onToggle,
                customBorder: RoundedRectangleBorder(borderRadius: radius),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 60),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: ExcludeSemantics(
                            child: Checkbox(
                              value: on,
                              onChanged: (_) => onToggle(),
                              activeColor: PawColors.primary,
                              checkColor: Colors.white,
                              side: const BorderSide(
                                color: PawColors.outline,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(title, style: PawText.body14Strong),
                              Text(
                                on
                                    ? 'Last given ${formatDate(date!)}'
                                    : 'Not added',
                                style: PawText.meta12.copyWith(
                                  color: PawColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (on)
            TextButton(
              onPressed: onEditDate,
              style: TextButton.styleFrom(
                minimumSize: const Size(PawSize.touch, PawSize.touch),
                foregroundColor: PawColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(
                'Edit date',
                semanticsLabel: 'Edit date for $title',
                style: PawText.meta13.copyWith(
                  color: PawColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
