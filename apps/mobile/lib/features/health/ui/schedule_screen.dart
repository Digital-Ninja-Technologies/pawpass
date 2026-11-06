import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/health_logic.dart';
import '../domain/models.dart';
import 'health_widgets.dart';
import 'home_screen.dart' show markDoneFlow;

/// Schedule (design/screens/Schedule.dc.html): what is overdue, due this month, and coming up.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  /// null means all pets.
  String? _petId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.health,
      builder: (context, _) {
        final h = scope.health;
        final today = h.today;
        final groups = groupReminders(h.remindersFor(_petId), today);
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: h.refreshHealth,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.screenSide,
                  12,
                  PawSpace.screenSide,
                  32,
                ),
                children: [
                  Row(
                    children: [
                      const PawBackButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text('Schedule', style: PawText.heading22),
                        ),
                      ),
                      RoundIconButton(
                        icon: PawIconData.plus,
                        filled: true,
                        semanticLabel: 'Add reminder',
                        onPressed: () => context.push('/add-record'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OfflineBanner(onRetry: h.refreshHealth),
                  if (h.pets.length > 1) ...[
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          PawChip(
                            label: 'All pets',
                            selected: _petId == null,
                            onTap: () => setState(() => _petId = null),
                          ),
                          for (final p in h.pets) ...[
                            const SizedBox(width: 8),
                            PawChip(
                              label: p.name,
                              selected: _petId == p.id,
                              onTap: () => setState(() => _petId = p.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (!h.loaded)
                    FirstLoad(error: h.error, onRetry: h.load)
                  else if (groups.isEmpty)
                    const InfoCard(
                      title: 'Nothing scheduled',
                      body: 'When you add a vaccine or treatment, the next dose shows up here and we remind you before it is due.',
                      icon: PawIconData.calendar,
                    )
                  else ...[
                    if (groups.overdue.isNotEmpty) ...[
                      const SectionLabel('Overdue', color: PawColors.danger),
                      const SizedBox(height: 10),
                      for (final r in groups.overdue)
                        _ReminderCard(reminder: r, today: today),
                    ],
                    if (groups.thisMonth.isNotEmpty) ...[
                      const SectionLabel(
                        'This month',
                        color: PawColors.warmText,
                      ),
                      const SizedBox(height: 10),
                      for (final r in groups.thisMonth)
                        _ReminderCard(reminder: r, today: today),
                    ],
                    if (groups.later.isNotEmpty) ...[
                      const SectionLabel('Coming up'),
                      const SizedBox(height: 10),
                      _ComingUp(reminders: groups.later, today: today),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A due or overdue item: the full card with actions. Further off items get a compact row.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder, required this.today});
  final Reminder reminder;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final soon = isSoon(reminder, today);
    final subtitle = reminderSubtitle(reminder, today);
    final label = '${reminder.label}, $subtitle';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PawColors.surface,
          borderRadius: BorderRadius.circular(PawRadius.cardSmall),
          border: Border.all(color: PawColors.border),
        ),
        child: soon
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RowHead(
                    reminder: reminder,
                    subtitle: subtitle,
                    label: label,
                    soon: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: PawButton(
                          label: 'Book a vet',
                          height: 40,
                          onPressed: () => context.go('/book'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PawButton(
                          label: 'Mark done',
                          height: 40,
                          variant: PawButtonVariant.secondary,
                          onPressed: () => markDoneFlow(context, reminder),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _RowHead(
                      reminder: reminder,
                      subtitle: subtitle,
                      label: label,
                      soon: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: PawButton(
                      label: 'Done',
                      height: 36,
                      expand: false,
                      variant: PawButtonVariant.secondary,
                      onPressed: () => markDoneFlow(context, reminder),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RowHead extends StatelessWidget {
  const _RowHead({
    required this.reminder,
    required this.subtitle,
    required this.label,
    required this.soon,
  });

  final Reminder reminder;
  final String subtitle;
  final String label;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Row(
            children: [
              DateBadge(reminder.dueOn, soon: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reminder.label, style: PawText.body14Strong),
                    Text(
                      subtitle,
                      style: PawText.meta12.copyWith(color: PawColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingUp extends StatelessWidget {
  const _ComingUp({required this.reminders, required this.today});
  final List<Reminder> reminders;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: PawColors.surface,
        borderRadius: BorderRadius.circular(PawRadius.cardSmall),
        border: Border.all(color: PawColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < reminders.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i == reminders.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: PawColors.subtle)),
              ),
              child: Semantics(
                container: true,
                label:
                    '${reminders[i].label}, ${reminderSubtitle(reminders[i], today)}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    DateBadge(reminders[i].dueOn),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reminders[i].label, style: PawText.body14Strong),
                          Text(
                            reminderSubtitle(reminders[i], today),
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
        ],
      ),
    );
  }
}
