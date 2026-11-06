import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dates.dart';
import '../../../ui/ui.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/domain/pet_age.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/health_logic.dart';
import '../domain/models.dart';
import 'health_widgets.dart';

/// Home (design/screens/Main.dc.html): who needs what today.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.session]),
      builder: (context, _) {
        final h = scope.health;
        final pet = h.selected;
        Widget body;
        if (!h.loaded && h.loading) {
          body = const Center(child: CircularProgressIndicator());
        } else if (!h.loaded && h.error != null) {
          body = LoadError(message: h.error!, onRetry: h.load);
        } else if (pet == null) {
          body = _NoPets(onAdd: () => _addPet(context));
        } else {
          body = _HomeBody(pet: pet);
        }
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: h.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header(unread: h.unread)),
                SliverFillRemaining(hasScrollBody: false, child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _addPet(BuildContext context) {
  AppScope.of(context).onboarding.startAnotherPet();
  context.push('/add-pet');
}

class _Header extends StatelessWidget {
  const _Header({required this.unread});
  final int unread;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final now = scope.health.now;
    final name = scope.session.profile?.firstName ?? '';
    final greeting = greetingFor(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PawSpace.screenSide,
        16,
        PawSpace.screenSide,
        18,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatLongDate(now),
                  style: PawText.meta13.copyWith(color: PawColors.muted),
                ),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: Text(
                    name.isEmpty ? greeting : '$greeting, $name',
                    style: PawText.title28.copyWith(fontSize: 26),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: PawIconData.bell,
            dot: unread > 0,
            semanticLabel: unread > 0
                ? 'Notifications, $unread new'
                : 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 8),
          _AccountButton(initial: name.isEmpty ? '?' : name[0].toUpperCase()),
        ],
      ),
    );
  }
}

/// The account circle. The full account screen arrives with partner mode (milestone 6); until then it
/// offers signing out.
class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Your account',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: Material(
        color: const Color(0xFFF3D9C4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _open(context),
          child: SizedBox(
            width: PawSize.touch,
            height: PawSize.touch,
            child: Center(
              child: Text(
                initial,
                style: PawText.button15.copyWith(
                  color: const Color(0xFF7A3E14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final scope = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PawColors.surface,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PawSpace.screenSide,
            0,
            PawSpace.screenSide,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your account', style: PawText.title28),
              const SizedBox(height: 6),
              Text(
                scope.services.auth.email ?? '',
                style: PawText.body15.copyWith(color: PawColors.muted),
              ),
              const SizedBox(height: 18),
              PawButton(
                label: 'Sign out',
                variant: PawButtonVariant.secondary,
                onPressed: () {
                  Navigator.pop(sheet);
                  scope.session.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPets extends StatelessWidget {
  const _NoPets({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PawSpace.screenSide),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('No pets yet', style: PawText.title28),
          const SizedBox(height: 8),
          Text(
            'Add your first pet to start their passport.',
            textAlign: TextAlign.center,
            style: PawText.body15.copyWith(color: PawColors.muted),
          ),
          const SizedBox(height: 20),
          PawButton(label: 'Add a pet', expand: false, onPressed: onAdd),
        ],
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).health;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PawSpace.screenSide,
        0,
        PawSpace.screenSide,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PetSwitcher(pets: h.pets, selectedId: pet.id),
          const SizedBox(height: 18),
          _PetCard(pet: pet),
          const SizedBox(height: 18),
          _NextCard(pet: pet),
          const SizedBox(height: 18),
          const _QuickActions(),
          const SizedBox(height: 18),
          const _EmergencyCard(),
        ],
      ),
    );
  }
}

class _PetSwitcher extends StatelessWidget {
  const _PetSwitcher({required this.pets, required this.selectedId});
  final List<Pet> pets;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).health;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in pets) ...[
            _PetChip(
              pet: p,
              selected: p.id == selectedId,
              onTap: () => h.select(p.id),
            ),
            const SizedBox(width: 8),
          ],
          _AddPetChip(onTap: () => _addPet(context)),
        ],
      ),
    );
  }
}

class _PetChip extends StatelessWidget {
  const _PetChip({
    required this.pet,
    required this.selected,
    required this.onTap,
  });
  final Pet pet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Semantics(
      button: true,
      selected: selected,
      label: pet.name,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? PawColors.primary : PawColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? BorderSide.none
              : const BorderSide(color: PawColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: Container(
            height: 44,
            padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PetAvatar(pet: pet),
                const SizedBox(width: 8),
                Text(
                  pet.name,
                  style: PawText.body14Strong.copyWith(
                    color: selected ? Colors.white : PawColors.ink,
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

class _AddPetChip extends StatelessWidget {
  const _AddPetChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add pet',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: PawColors.outline, width: 1.5),
          ),
          child: Text(
            '+ Add pet',
            style: PawText.body14Strong.copyWith(color: PawColors.muted),
          ),
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).health;
    final status = h.statusFor(pet.id);
    final weight = h.weightFor(pet.id).latestKg;
    final facts = [
      if ((pet.breed ?? '').isNotEmpty) pet.breed!,
      if (pet.dateOfBirth != null) ageLabel(pet.dateOfBirth!, h.today),
      if (weight != null) kgText(weight),
    ];
    final good = status.state == PassportState.upToDate;
    return PawCard(
      semanticLabel: "${pet.name}, ${status.label}. Open passport",
      onTap: () => context.go('/passport'),
      child: Row(
        children: [
          PetAvatar(pet: pet, size: 84, radius: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name, style: PawText.heading22),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    facts.join(' · '),
                    style: PawText.meta13.copyWith(color: PawColors.muted),
                  ),
                ],
                const SizedBox(height: 6),
                PawBadge(
                  status.label,
                  tone: good
                      ? PawBadgeTone.verified
                      : (status.state == PassportState.overdue
                            ? PawBadgeTone.danger
                            : PawBadgeTone.upcoming),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const ExcludeSemantics(
            child: CircleAvatar(
              radius: 22,
              backgroundColor: PawColors.ground,
              child: PawIcon(PawIconData.chevronRight),
            ),
          ),
        ],
      ),
    );
  }
}

/// What is due next for this pet: the warm card when it is close, a calm card otherwise.
class _NextCard extends StatelessWidget {
  const _NextCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).health;
    final next = h.nextFor(pet.id);
    if (next == null) {
      return PawCard(
        radius: PawRadius.card,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('All caught up', style: PawText.body15Strong),
            const SizedBox(height: 4),
            Text(
              'Add ${pet.name}\'s vaccines to the passport and we will remind you when the next ones are due.',
              style: PawText.meta13.copyWith(
                color: PawColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            PawButton(
              label: 'Add a record',
              height: 46,
              onPressed: () => context.push('/add-record'),
            ),
          ],
        ),
      );
    }
    final today = h.today;
    final soon = isSoon(next, today);
    final overline = soon
        ? 'Due ${whenText(next, today)}'.replaceFirst('Due overdue', 'Overdue')
        : 'Next up';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: soon ? PawColors.warmSoft : PawColors.surface,
        borderRadius: BorderRadius.circular(PawRadius.card),
        border: soon ? null : Border.all(color: PawColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: soon ? Colors.white : PawColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: PawIcon(
                      PawIconData.calendar,
                      color: soon ? PawColors.warm : PawColors.primaryText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overline.toUpperCase(),
                      style: PawText.overline12.copyWith(
                        color: soon ? PawColors.warmText : PawColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${next.label} for ${pet.name}',
                      style: PawText.button16,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: PawText.meta13.copyWith(
                          color: const Color(0xFF6B4A33),
                        ),
                        children: [
                          TextSpan(
                            text: next.givenOn == null
                                ? '${formatDate(next.dueOn)} · '
                                : 'Last dose ${formatDate(next.givenOn!)} · ',
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: () => context.push('/schedule'),
                              child: Text(
                                'See schedule',
                                semanticsLabel: 'See schedule',
                                style: PawText.meta13.copyWith(
                                  color: const Color(0xFF6B3A16),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (soon) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PawButton(
                    label: 'Book a vet',
                    height: 46,
                    onPressed: () => context.go('/book'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _MarkDoneButton(reminder: next)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MarkDoneButton extends StatelessWidget {
  const _MarkDoneButton({required this.reminder});
  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).health;
    final radius = BorderRadius.circular(23);
    Future<void> tap() => markDoneFlow(context, reminder);
    return Semantics(
      button: true,
      label: 'Mark as done',
      excludeSemantics: true,
      onTap: tap,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: Color(0xFFE6C6AB), width: 1.5),
        ),
        child: InkWell(
          onTap: h.busy ? null : tap,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: SizedBox(
            height: 46,
            child: Center(
              child: Text(
                'Mark as done',
                style: PawText.button15.copyWith(
                  fontSize: 14,
                  color: const Color(0xFF6B3A16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks when, marks the reminder done, and says what comes next.
Future<void> markDoneFlow(BuildContext context, Reminder reminder) async {
  final scope = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final date = await showMarkDoneSheet(context, reminder: reminder);
  if (date == null) return;
  final ok = await scope.health.markDone(reminder, date: date);
  final next = scope.health.lastNextDue;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (next == null
                    ? '${reminder.label} marked as done.'
                    : '${reminder.label} marked as done. The next one is due ${formatDate(next)}.')
              : (scope.health.error ?? 'We could not mark that as done.'),
        ),
      ),
    );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Vet',
        PawIconData.vet,
        PawColors.primarySoft,
        PawColors.primaryText,
        '/book',
      ),
      (
        'Grooming',
        PawIconData.scissors,
        const Color(0xFFF1E8FB),
        const Color(0xFF5A2E8C),
        '/book',
      ),
      (
        'Report lost',
        PawIconData.alertTriangle,
        PawColors.warmSoft,
        PawColors.warmText,
        '/lost',
      ),
      (
        'Find a pet',
        PawIconData.search,
        const Color(0xFFDCE7F7),
        const Color(0xFF23407A),
        '/adopt',
      ),
    ];
    return Semantics(
      container: true,
      label: 'Quick actions',
      child: Row(
        children: [
          for (final (label, icon, bg, fg, route) in items)
            Expanded(
              child: Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                onTap: () =>
                    route == '/lost' ? context.push(route) : context.go(route),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => route == '/lost'
                      ? context.push(route)
                      : context.go(route),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(child: PawIcon(icon, color: fg)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: PawText.meta12.copyWith(
                          fontWeight: FontWeight.w600,
                          color: PawColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      label: 'Emergency vet. Nearest clinics open now, tap to call',
      excludeSemantics: true,
      onTap: () => context.push('/emergency'),
      child: Material(
        color: PawColors.dangerSoft,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: () => context.push('/emergency'),
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: PawIcon(
                      PawIconData.medicalCross,
                      color: PawColors.danger,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency vet',
                        style: PawText.body15Strong.copyWith(
                          color: PawColors.danger,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Nearest clinics open now · tap to call',
                        style: PawText.meta13.copyWith(
                          color: const Color(0xFF8A2016),
                        ),
                      ),
                    ],
                  ),
                ),
                const PawIcon(
                  PawIconData.chevronRight,
                  color: PawColors.danger,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
