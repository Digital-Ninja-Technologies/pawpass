import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dates.dart';
import '../../../ui/ui.dart';
import '../domain/models.dart';
import '../domain/reminder_schedule.dart';
import '../state/app_scope.dart';
import 'onboarding_page.dart';

/// "Never miss a dose": the suggested schedule, where to be reminded, and the step that finally
/// creates the passport.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ob = AppScope.of(context).onboarding;
    return ListenableBuilder(
      listenable: ob,
      builder: (context, _) {
        final items = ob.schedule;
        final today = ob.today;
        final noChannels = ob.channels.isEmpty;
        return OnboardingPage(
          title: 'Never miss a dose',
          subtitle: items.isEmpty
              ? "We'll remind you 7 days and 1 day before anything is due."
              : "Here's ${ob.petPossessive} suggested schedule. We'll remind you 7 days and 1 day before.",
          error: ob.error,
          gap: 18,
          form: [
            if (items.isEmpty)
              const _EmptySchedule()
            else
              _ScheduleCard(items: items, today: today),
            Semantics(
              container: true,
              label: 'Remind me by',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remind me by', style: PawText.body14Strong),
                  const SizedBox(height: 10),
                  for (final c in ReminderChannel.values) ...[
                    if (c != ReminderChannel.values.first)
                      const SizedBox(height: 8),
                    PawToggleRow(
                      label: c.label,
                      value: ob.channels.contains(c),
                      onChanged: (_) => ob.toggleChannel(c),
                    ),
                  ],
                  if (ob.channels.contains(ReminderChannel.whatsapp) &&
                      ob.phone.trim().isEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Add your phone number in your profile to get WhatsApp reminders.',
                      style: PawText.meta13.copyWith(color: PawColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
          footer: [
            PawButton(
              label: noChannels
                  ? 'Continue without reminders'
                  : 'Turn on reminders',
              loading: ob.busy,
              onPressed: () async {
                final ok = await ob.createPassport();
                if (ok && context.mounted) context.go('/all-set');
              },
            ),
          ],
        );
      },
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PawColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PawColors.border),
      ),
      child: Text(
        'No schedule yet. Add vaccines to the passport later and we will plan the reminders for you.',
        style: PawText.body14.copyWith(color: PawColors.ink2, height: 1.5),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.items, required this.today});
  final List<ScheduleItem> items;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Suggested schedule',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PawColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: PawColors.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: PawColors.subtle),
                const SizedBox(height: 14),
              ],
              _ScheduleRow(item: items[i], today: today),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item, required this.today});
  final ScheduleItem item;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final soon = item.isSoon(today);
    return MergeSemantics(
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text(
                  monthAbbrUpper(item.dueOn),
                  style: PawText.meta12.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: soon ? PawColors.warmText : PawColors.muted,
                  ),
                ),
                Text('${item.dueOn.day}', style: PawText.heading22),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: PawText.body14Strong),
                Text(
                  item.subtitle(today),
                  style: PawText.meta12.copyWith(color: PawColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
