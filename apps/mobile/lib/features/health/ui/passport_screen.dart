import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dates.dart';
import '../../../ui/ui.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../../onboarding/ui/onboarding_page.dart' show TextLinkButton;
import '../domain/health_logic.dart';
import '../domain/models.dart';
import 'health_widgets.dart';

enum _Section { health, origin, services }

/// Pet Passport (design/screens/Passport.dc.html): identity, health, origin and services in one place.
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  var _section = _Section.health;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.health,
      builder: (context, _) {
        final h = scope.health;
        final pet = h.selected;
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: h.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                PawSpace.screenSide,
                12,
                PawSpace.screenSide,
                24,
              ),
              children: [
                _TopBar(canShare: pet != null),
                const SizedBox(height: 16),
                OfflineBanner(onRetry: h.load),
                if (!h.loaded)
                  FirstLoad(error: h.error, onRetry: h.load)
                else if (pet == null)
                  const InfoCard(
                    title: 'No pet yet',
                    body: 'Add a pet from Home to start their passport.',
                    icon: PawIconData.passport,
                  )
                else ...[
                  _IdentityCard(pet: pet),
                  const SizedBox(height: 16),
                  PawSegmented<_Section>(
                    segments: const [
                      PawSegment(_Section.health, 'Health'),
                      PawSegment(_Section.origin, 'Origin'),
                      PawSegment(_Section.services, 'Services'),
                    ],
                    value: _section,
                    onChanged: (s) => setState(() => _section = s),
                  ),
                  const SizedBox(height: 16),
                  switch (_section) {
                    _Section.health => _HealthTab(pet: pet),
                    _Section.origin => _OriginTab(pet: pet),
                    _Section.services => const InfoCard(
                      title: 'No services yet',
                      body: 'Vets, groomers and trainers you book will be listed here, with what they did.',
                      icon: PawIconData.calendar,
                    ),
                  },
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.canShare});
  final bool canShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: PawSize.touch),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Pet Passport',
              textAlign: TextAlign.center,
              style: PawText.heading22.copyWith(fontSize: 20),
            ),
          ),
        ),
        canShare
            ? RoundIconButton(
                icon: PawIconData.share,
                semanticLabel: 'Share passport',
                onPressed: () => context.push('/share'),
              )
            : const SizedBox(width: PawSize.touch),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).health;
    final d = h.detailsFor(pet.id);
    final facts = [
      if ((pet.breed ?? '').isNotEmpty) pet.breed!,
      if (pet.sex != PetSex.unknown) pet.sex.label,
      if (pet.dateOfBirth != null) 'Born ${formatDate(pet.dateOfBirth!)}',
    ];
    final origin = d.originName == null
        ? 'Not recorded'
        : (d.originVerified ? '${d.originName} ✓' : d.originName!);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PawColors.primary,
        borderRadius: BorderRadius.circular(PawRadius.card),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PetAvatar(pet: pet, size: 72, radius: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: PawText.title28.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        facts.join(' · '),
                        style: PawText.meta13.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Fact(label: 'Tag ID', value: pet.tagCode ?? '—'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Fact(label: 'Origin', value: origin),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: PawText.meta12.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PawText.body14Strong.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthTab extends StatelessWidget {
  const _HealthTab({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).health;
    final today = h.today;
    final entries = passportEntries(
      h.recordsFor(pet.id),
      h.remindersFor(pet.id),
    );
    final weight = h.weightFor(pet.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Vaccines & treatments',
                  style: PawText.body15Strong,
                ),
              ),
            ),
            TextLinkButton(
              label: '+ Add record',
              alignment: Alignment.centerRight,
              onPressed: () => context.push('/add-record'),
            ),
          ],
        ),
        if (entries.isEmpty)
          const InfoCard(
            title: 'No records yet',
            body: 'Add a vaccine or treatment and it will show here, with a reminder for the next one.',
          )
        else
          for (final e in entries) ...[
            _EntryRow(entry: e, today: today),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 6),
        _WeightCard(series: weight),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.today});
  final PassportEntry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    final Color dot;
    Widget trailing;
    VoidCallback? onTap;

    if (entry.isUpcoming) {
      final r = entry.reminder!;
      final overdue = r.dueOn.isBefore(today);
      title = r.label;
      subtitle = dueText(r.dueOn);
      dot = PawColors.dot;
      trailing = PawBadge(
        overdue ? 'Overdue' : 'Upcoming',
        tone: overdue ? PawBadgeTone.danger : PawBadgeTone.upcoming,
      );
      onTap = () => context.push('/schedule');
    } else {
      final r = entry.record!;
      title = r.name;
      subtitle = [
        if (r.givenOn != null) formatDate(r.givenOn!),
        r.sourceLabel,
      ].join(' · ');
      dot = PawColors.primary;
      trailing = r.verified
          ? const PawBadge.verified('Vet verified')
          : Text(
              'Done',
              style: PawText.meta12.copyWith(
                color: PawColors.muted,
                fontWeight: FontWeight.w600,
              ),
            );
    }
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$title, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: PawCard(
        radius: PawRadius.cardSmall,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: PawText.body14Strong),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: PawText.meta12.copyWith(color: PawColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.series});
  final WeightSeries series;

  @override
  Widget build(BuildContext context) {
    return PawCard(
      radius: PawRadius.cardSmall,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Weight', style: PawText.body15Strong)),
              if (!series.isEmpty)
                Text(
                  '${kgText(series.latestKg!)} · last ${series.points.length} ${series.points.length == 1 ? 'entry' : 'entries'}',
                  style: PawText.meta13.copyWith(color: PawColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (series.isEmpty)
            Text(
              'No weights yet. Add one with "+ Add record" to see how it changes.',
              style: PawText.meta13.copyWith(
                color: PawColors.muted,
                height: 1.5,
              ),
            )
          else
            Semantics(
              image: true,
              label: series.description,
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 56,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < series.heights.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: FractionallySizedBox(
                            heightFactor: series.heights[i],
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: i == series.heights.length - 1
                                    ? PawColors.primary
                                    : const Color(0xFFCFE6E1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _OriginTab extends StatelessWidget {
  const _OriginTab({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).health;
    final d = h.detailsFor(pet.id);
    final hasParents = d.motherName != null || d.fatherName != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PawCard(
          radius: PawRadius.cardSmall,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where ${pet.name} comes from', style: PawText.body15Strong),
              const SizedBox(height: 8),
              if (d.originName == null)
                Text(
                  'No breeder or shelter is linked to this passport. Pets bought or adopted through OurPawPass show where they came from here.',
                  style: PawText.meta13.copyWith(
                    color: PawColors.muted,
                    height: 1.5,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(d.originName!, style: PawText.body14Strong),
                    ),
                    if (d.originVerified) const PawBadge.verified('Verified'),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PawCard(
          radius: PawRadius.cardSmall,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Parents', style: PawText.body15Strong),
              const SizedBox(height: 8),
              if (!hasParents)
                Text(
                  'Not recorded.',
                  style: PawText.meta13.copyWith(color: PawColors.muted),
                )
              else ...[
                if (d.motherName != null)
                  Text('Mother: ${d.motherName}', style: PawText.body14),
                if (d.fatherName != null)
                  Text('Father: ${d.fatherName}', style: PawText.body14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
