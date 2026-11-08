import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../adopt/domain/adopt_logic.dart' show shortDay;
import '../../adopt/ui/adopt_widgets.dart' show AdoptPetMark;
import '../../booking/domain/booking_logic.dart' show dayLabel, nairaFromKobo;
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../data/partner_repository.dart';
import '../domain/models.dart';
import '../domain/partner_logic.dart';
import '../state/partner_controller.dart';
import 'partner_widgets.dart';

/// Today: the dashboard for this kind of partner (design/screens/ProviderDash, BreederDash, ShelterDash).
class PartnerTodayScreen extends StatelessWidget {
  const PartnerTodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.partner;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final d = p.dashboard;
        if (d == null) {
          return p.dashboardError != null
              ? SafeArea(
                  child: LoadError(
                    message: p.dashboardError!,
                    onRetry: p.loadDashboard,
                  ),
                )
              : const Center(child: CircularProgressIndicator());
        }
        void ownerMode() {
          p.leavePartnerMode();
          context.go('/home');
        }

        final type = d.partner.type;
        final header = switch (type) {
          PartnerType.vet || PartnerType.service => PartnerHeader(
            overline: 'PARTNER MODE',
            title: d.partner.name,
            onOwnerMode: ownerMode,
            stats: [
              (
                label: 'Today',
                value: d.visitsToday == 1
                    ? '1 visit'
                    : '${d.visitsToday} visits',
              ),
              (label: 'This week', value: compactNaira(d.weekKobo)),
              (
                label: 'Rating',
                value: d.rating == null
                    ? 'No reviews'
                    : '★ ${d.rating!.toStringAsFixed(1)}',
              ),
            ],
          ),
          PartnerType.breeder => PartnerHeader(
            overline: 'PARTNER MODE · BREEDER',
            title: d.partner.name,
            onOwnerMode: ownerMode,
            stats: [
              (label: 'Live listings', value: '${d.liveListings}'),
              (label: 'New enquiries', value: '${d.newEnquiries}'),
              (label: 'In escrow', value: compactNaira(d.inEscrowKobo)),
            ],
          ),
          PartnerType.shelter => PartnerHeader(
            overline: 'PARTNER MODE · SHELTER',
            title: d.partner.name,
            onOwnerMode: ownerMode,
            stats: [
              (label: 'Pets listed', value: '${d.petsListed}'),
              (label: 'New applications', value: '${d.newApplications}'),
              (
                label: 'Adopted · ${_monthAbbr(p.now)}',
                value: '${d.adoptedMonth}',
              ),
            ],
          ),
        };
        return RefreshIndicator(
          onRefresh: p.refresh,
          edgeOffset: 120,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              header,
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.screenSide,
                  16,
                  PawSpace.screenSide,
                  24,
                ),
                child: switch (type) {
                  PartnerType.vet || PartnerType.service => _ProviderBody(
                    d: d,
                    now: p.now,
                    onEarnings: () =>
                        StatefulNavigationShell.of(context).goBranch(3),
                  ),
                  PartnerType.breeder => _BreederBody(d: d),
                  PartnerType.shelter => _ShelterBody(d: d, controller: p),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

String _monthAbbr(DateTime d) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return m[d.month - 1];
}

// ----------------------------------------------------------------- provider

class _ProviderBody extends StatelessWidget {
  const _ProviderBody({
    required this.d,
    required this.now,
    required this.onEarnings,
  });
  final PartnerDashboard d;
  final DateTime now;
  final VoidCallback onEarnings;

  @override
  Widget build(BuildContext context) {
    final schedule = d.schedule;
    final nextIndex = schedule.indexWhere((v) => !v.done);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading("Today's schedule", trailingText: dayLabel(now)),
        if (schedule.isEmpty)
          const EmptyNote('No visits today. New bookings show up here.')
        else
          for (var i = 0; i < schedule.length; i++)
            DashRow(
              emphasis: i == nextIndex,
              semanticLabel:
                  '${visitTime(schedule[i].startsAt)} ${visitMeridiem(schedule[i].startsAt)}. ${schedule[i].service}, ${schedule[i].petName}',
              leading: SizedBox(
                width: 52,
                child: Text(
                  visitTime(schedule[i].startsAt),
                  style: PawText.body14Strong.copyWith(
                    color: i == nextIndex ? PawColors.primary : PawColors.muted,
                  ),
                ),
              ),
              title: '${schedule[i].service} · ${schedule[i].petName}',
              subtitle: [
                schedule[i].ownerName,
                if (schedule[i].breed != null) schedule[i].breed!,
                if (schedule[i].passportShared) 'passport shared',
              ].join(' · '),
              trailing: schedule[i].done
                  ? const StatusTag('Done')
                  : i == nextIndex
                  ? const StatusTag('Next', highlight: true)
                  : null,
            ),
        const SizedBox(height: 6),
        PawCard(
          color: PawColors.primarySoft,
          radius: PawRadius.cardSmall,
          onTap: onEarnings,
          semanticLabel:
              'Next payout ${nairaFromKobo(d.nextPayoutKobo)}. Open earnings',
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT PAYOUT',
                      style: PawText.overline12.copyWith(
                        color: PawColors.primaryText,
                      ),
                    ),
                    Text(
                      nairaFromKobo(d.nextPayoutKobo),
                      style: PawText.title28.copyWith(
                        color: PawColors.primaryText,
                      ),
                    ),
                    Text(
                      'Released after owners confirm visits',
                      style: PawText.meta13.copyWith(
                        color: PawColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Details',
                style: PawText.body14Strong.copyWith(
                  color: PawColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ breeder

String listingTitle(PartnerListing l) => l.sale && l.priceKobo != null
    ? '${l.petName} · ${nairaFromKobo(l.priceKobo!)}'
    : l.petName;

String listingSubtitle(PartnerListing l) {
  if (l.reserved && l.orderId != null) {
    final by = l.buyerName ?? 'A buyer';
    return l.handoverBy == null
        ? 'Deposit paid by $by'
        : 'Deposit paid by $by · handover by ${shortDay(l.handoverBy!)}';
  }
  final parts = <String>[
    if (l.sale)
      '${l.enquiries} enquir${l.enquiries == 1 ? 'y' : 'ies'}'
    else
      '${l.applications} application${l.applications == 1 ? '' : 's'}',
    if (l.handoverBy != null) 'handover by ${shortDay(l.handoverBy!)}',
  ];
  return parts.join(' · ');
}

class ListingRow extends StatelessWidget {
  const ListingRow({super.key, required this.listing, this.actions});
  final PartnerListing listing;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return DashRow(
      leading: AdoptPetMark(
        name: l.petName,
        path: l.photoPath,
        size: 52,
        radius: 12,
      ),
      title: listingTitle(l),
      subtitle: listingSubtitle(l),
      trailing: StatusTag(
        l.reserved ? 'Reserved' : (l.live ? 'Live' : l.status),
        highlight: l.live,
      ),
      footer: actions,
      onTap: () {
        if (l.orderId != null) {
          context.push('/orders/${l.orderId}');
        } else {
          context.push('/listing/${l.listingId}');
        }
      },
    );
  }
}

class _BreederBody extends StatelessWidget {
  const _BreederBody({required this.d});
  final PartnerDashboard d;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          'Your listings',
          action: '+ New listing',
          onAction: () => context.push('/partner/listing/new'),
        ),
        if (d.listings.isEmpty)
          const EmptyNote('No listings yet. Add your first litter.')
        else
          for (final l in d.listings.take(5)) ListingRow(listing: l),
        const SectionHeading('Latest enquiries'),
        if (d.enquiries.isEmpty)
          const EmptyNote(
            'No enquiries yet. They show here when someone messages you about a listing.',
          )
        else
          for (final e in d.enquiries) EnquiryRow(enquiry: e),
      ],
    );
  }
}

class EnquiryRow extends StatelessWidget {
  const EnquiryRow({super.key, required this.enquiry});
  final Enquiry enquiry;

  @override
  Widget build(BuildContext context) {
    final e = enquiry;
    return DashRow(
      leading: LetterMark(e.otherName),
      title: '${e.otherName} · ${e.petName}',
      subtitle: e.lastBody == null ? '' : '"${e.lastBody}"',
      trailing: e.unread > 0
          ? Semantics(
              label: 'Unread',
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: PawColors.dot,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
      onTap: () => context.push('/chat/${e.conversationId}'),
    );
  }
}

// ------------------------------------------------------------------ shelter

class _ShelterBody extends StatelessWidget {
  const _ShelterBody({required this.d, required this.controller});
  final PartnerDashboard d;
  final PartnerController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          'Applications to review',
          action: '+ Add pet',
          onAction: () => context.push('/partner/listing/new'),
        ),
        ApplicationsList(
          applications: d.applications,
          controller: controller,
          limit: 4,
        ),
        if (d.stalePets > 0) ...[
          const SizedBox(height: 6),
          InfoCard(
            title: 'Quiet listings',
            body:
                '${d.stalePets} pet${d.stalePets == 1 ? ' has' : 's have'} had no applications in 30 days. Share ${d.stalePets == 1 ? 'it' : 'them'} to the community?',
            icon: PawIconData.community,
          ),
        ],
      ],
    );
  }
}

/// Adoption applications with the shelter's decisions.
class ApplicationsList extends StatelessWidget {
  const ApplicationsList({
    super.key,
    required this.applications,
    required this.controller,
    this.limit,
  });
  final List<ShelterApplication> applications;
  final PartnerController controller;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return const EmptyNote(
        'No applications to review. They show here when someone applies for a pet.',
      );
    }
    final items = limit == null
        ? applications
        : applications.take(limit!).toList();
    return Column(
      children: [
        for (final a in items) _ApplicationCard(a: a, controller: controller),
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.a, required this.controller});
  final ShelterApplication a;
  final PartnerController controller;

  String get _summary => [
    if (a.homeType != null) _homeLabel(a.homeType!),
    if (a.otherPets != null) 'has ${a.otherPets}',
    if (a.daytime != null) a.daytime!,
  ].join(' · ');

  static String _homeLabel(String v) => switch (v) {
    'house' => 'House',
    'flat' => 'Flat',
    _ => 'Other home',
  };

  Future<void> _decide(
    BuildContext context,
    ApplicationDecision d,
    String done,
  ) async {
    final ok = await controller.decide(a.id, d);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok ? done : controller.actionError ?? 'That did not work.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final visit = a.state == ApplicationState.homeVisit;
    final approved = a.state == ApplicationState.approved;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PawCard(
        radius: PawRadius.cardSmall,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AdoptPetMark(
                  name: a.petName,
                  path: a.photoPath,
                  size: 48,
                  radius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${a.applicantName} wants to adopt ${a.petName}',
                        style: PawText.body14Strong,
                      ),
                      if (_summary.isNotEmpty)
                        Text(
                          _summary,
                          style: PawText.meta12.copyWith(
                            color: PawColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusTag(
                  approved
                      ? 'Approved'
                      : visit
                      ? 'Home visit'
                      : 'New',
                  highlight: !approved && !visit,
                ),
              ],
            ),
            if (a.why != null) ...[
              const SizedBox(height: 10),
              Text(
                '"${a.why}"',
                style: PawText.body14.copyWith(color: PawColors.ink2),
              ),
            ],
            if (a.petsVaccinatedAll) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const PawIcon(
                    PawIconData.shieldCheck,
                    size: 18,
                    color: PawColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current pets are vaccinated, per their passports',
                      style: PawText.meta13.copyWith(
                        color: PawColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (approved)
              PawButton(
                label: 'Hand over ${a.petName}',
                loading: controller.busy,
                onPressed: controller.busy
                    ? null
                    : () async {
                        final transfer = await controller.completeAdoption(
                          a.id,
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                transfer == null
                                    ? controller.actionError ??
                                          'That did not work.'
                                    : '${a.petName} is handed over. ${a.applicantName} will accept the passport.',
                              ),
                            ),
                          );
                      },
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    // Wider than Approve, so "Book home visit" is not cut off on a 390 wide phone.
                    flex: 3,
                    child: PawButton(
                      label: visit ? 'Message' : 'Book home visit',
                      variant: PawButtonVariant.secondary,
                      height: 44,
                      onPressed: () async {
                        final conv = await controller.chatWith(a.id);
                        if (conv != null && !visit) {
                          await controller.decide(
                            a.id,
                            ApplicationDecision.homeVisit,
                          );
                        }
                        if (conv != null && context.mounted) {
                          context.push('/chat/$conv');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: PawButton(
                      label: 'Approve',
                      height: 44,
                      onPressed: controller.busy
                          ? null
                          : () => _decide(
                              context,
                              ApplicationDecision.approve,
                              '${a.applicantName} is approved for ${a.petName}.',
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PawButton(
                label: 'Decline politely',
                variant: PawButtonVariant.secondary,
                height: 44,
                onPressed: controller.busy
                    ? null
                    : () => _decide(
                        context,
                        ApplicationDecision.decline,
                        'We let ${a.applicantName} know, kindly.',
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The fourth tab for shelters: every application, with tabs and a search (design/screens/ShelterApplications).
class ApplicationsTab extends StatefulWidget {
  const ApplicationsTab({super.key});

  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> {
  var _filter = ApplicationFilter.all;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    return ListenableBuilder(
      listenable: Listenable.merge([p, _search]),
      builder: (context, _) {
        final d = p.dashboard;
        final all = d?.applications ?? const <ShelterApplication>[];
        final shown = filterApplications(all, _filter, query: _search.text);
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: p.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                PawSpace.screenSide,
                16,
                PawSpace.screenSide,
                24,
              ),
              children: [
                Semantics(
                  header: true,
                  child: Text('Applications', style: PawText.title28),
                ),
                const SizedBox(height: 12),
                if (d == null && p.dashboardError != null)
                  SizedBox(
                    height: 360,
                    child: LoadError(
                      message: p.dashboardError!,
                      onRetry: p.loadDashboard,
                    ),
                  )
                else if (d == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (all.isEmpty)
                  SizedBox(
                    height: 380,
                    child: PawEmptyState(
                      icon: PawIconData.passport,
                      tone: PawStateTone.teal,
                      title: 'No applications yet',
                      message:
                          'When someone applies to adopt, you will see them here. Sharing a pet to the community helps.',
                      actionLabel: 'See your pets',
                      onAction: () =>
                          StatefulNavigationShell.of(context).goBranch(1),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in ApplicationFilter.values)
                        PawChip(
                          label: '${f.label} · ${applicationCount(all, f)}',
                          selected: _filter == f,
                          onTap: () => setState(() => _filter = f),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PawTextField(
                    label: 'Search applications',
                    controller: _search,
                    hint: 'Search by name or pet',
                    textInputAction: TextInputAction.search,
                  ),
                  const SizedBox(height: 12),
                  if (shown.isEmpty)
                    const EmptyNote('No applications match that.')
                  else
                    ApplicationsList(applications: shown, controller: p),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The second tab for breeders and shelters: all their listings, with take down and put back.
class ListingsTab extends StatelessWidget {
  const ListingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final d = p.dashboard;
        final shelter = d?.partner.type == PartnerType.shelter;
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: p.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                PawSpace.screenSide,
                16,
                PawSpace.screenSide,
                24,
              ),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    shelter ? 'Pets' : 'Listings',
                    style: PawText.title28,
                  ),
                ),
                SectionHeading(
                  shelter
                      ? 'Everyone you have listed'
                      : 'Everything you have listed',
                  action: shelter ? '+ Add pet' : '+ New listing',
                  onAction: () => context.push('/partner/listing/new'),
                ),
                if (d == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (d.listings.isEmpty)
                  const EmptyNote('Nothing listed yet.')
                else
                  for (final l in d.listings)
                    ListingRow(
                      listing: l,
                      actions: l.live
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: p.busy
                                    ? null
                                    : () => p.setListingLive(
                                        l.listingId,
                                        live: false,
                                      ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(
                                    PawSize.touch,
                                    PawSize.touch,
                                  ),
                                  foregroundColor: PawColors.danger,
                                ),
                                child: Text(
                                  'Take down',
                                  style: PawText.body14Strong.copyWith(
                                    color: PawColors.danger,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                if (p.actionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      p.actionError!,
                      style: PawText.body14.copyWith(color: PawColors.danger),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Calendar for vets and service providers (design/screens/PartnerCalendar.dc.html): a week strip, the day's visits
/// and free times, and a way to close free times so nobody can book them.
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  var _started = false;

  Future<void> _block(
    BuildContext context, {
    required String title,
    required String body,
    required DateTime from,
    required DateTime to,
  }) async {
    final p = AppScope.of(context).partner;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: PawText.heading22),
        content: Text(body, style: PawText.body14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep open'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    final n = await p.blockTimes(from, to);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            n == null
                ? (p.blockError ?? 'We could not block that. Please try again.')
                : n == 0
                ? 'Nothing to block. Booked times stay as they are.'
                : n == 1
                ? 'Blocked. Nobody can book that time now.'
                : 'Blocked $n times. Nobody can book them now.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => p.loadCalendar());
    }
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final week = p.calendarWeek ?? lagosWeekStart(p.now);
        final day = p.calendarDay ?? lagosDayStart(p.now);
        final cal = p.calendar;
        final entries = cal == null
            ? const <CalendarEntry>[]
            : entriesForDay(cal, day);
        final booked = entries.where((e) => e.visit != null).length;
        final open = entries.where((e) => e.slot != null).length;
        final dayEnd = day.add(const Duration(days: 1));
        final restFrom = p.now.isAfter(day) ? p.now : day;
        return Column(
          children: [
            _CalendarHeader(
              week: week,
              busy: p.loadingCalendar,
              onPrevious: () => p.shiftCalendarWeek(-1),
              onNext: () => p.shiftCalendarWeek(1),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  p.loadingCalendar = false;
                  await p.loadCalendar();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    PawSpace.screenSide,
                    14,
                    PawSpace.screenSide,
                    24,
                  ),
                  children: [
                    Row(
                      children: [
                        for (final d in weekDays(week)) ...[
                          Expanded(
                            child: _DayButton(
                              day: d,
                              selected: d == day,
                              dots: cal == null ? 0 : visitsOn(cal, d),
                              onTap: () => p.selectCalendarDay(d),
                            ),
                          ),
                          if (d != weekDays(week).last)
                            const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (cal == null && p.calendarError != null)
                      SizedBox(
                        height: 320,
                        child: PawErrorState(
                          title: 'We could not load your calendar',
                          message: p.calendarError!,
                          onAction: () {
                            p.loadingCalendar = false;
                            p.loadCalendar();
                          },
                        ),
                      )
                    else if (cal == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              dayHeading(day),
                              style: PawText.body15Strong,
                            ),
                          ),
                          Text(
                            '$booked booked · $open open',
                            style: PawText.meta13.copyWith(
                              color: PawColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (entries.isEmpty)
                        const EmptyNote('Nothing booked and no open times.')
                      else
                        for (final e in entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: e.visit != null
                                ? _VisitTile(v: e.visit!)
                                : _OpenTile(
                                    slot: e.slot!,
                                    onBlock: () => _block(
                                      context,
                                      title: 'Block this time?',
                                      body:
                                          'Nobody will be able to book ${visitTime(e.slot!.startsAt)}${visitMeridiem(e.slot!.startsAt)} on ${dayHeading(day)}.',
                                      from: e.slot!.startsAt,
                                      to: e.slot!.startsAt.add(
                                        const Duration(minutes: 1),
                                      ),
                                    ),
                                  ),
                          ),
                      if (p.blockError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              p.blockError!,
                              style: PawText.body14.copyWith(
                                color: PawColors.danger,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      PawButton(
                        label: 'Block the rest of this day',
                        variant: PawButtonVariant.secondary,
                        height: 48,
                        loading: p.busy,
                        onPressed: open == 0
                            ? null
                            : () => _block(
                                context,
                                title: 'Block the rest of the day?',
                                body:
                                    '$open open ${open == 1 ? 'time' : 'times'} on ${dayHeading(day)} will close. Visits already booked stay.',
                                from: restFrom,
                                to: dayEnd,
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.week,
    required this.busy,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime week;
  final bool busy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: PawColors.ink,
      padding: EdgeInsets.fromLTRB(
        PawSpace.screenSide,
        MediaQuery.paddingOf(context).top + 16,
        PawSpace.screenSide,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PARTNER MODE',
            style: PawText.overline12.copyWith(color: const Color(0xFFCFE6E1)),
          ),
          const SizedBox(height: 2),
          Semantics(
            header: true,
            child: Text(
              'Calendar',
              style: PawText.heading22.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _WeekButton(
                label: 'Previous week',
                icon: PawIconData.chevronLeft,
                onTap: busy ? null : onPrevious,
              ),
              Text(
                weekRangeLabel(week),
                style: PawText.body14Strong.copyWith(color: Colors.white),
              ),
              _WeekButton(
                label: 'Next week',
                icon: PawIconData.chevronRight,
                onTap: busy ? null : onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekButton extends StatelessWidget {
  const _WeekButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final PawIconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    enabled: onTap != null,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: PawSize.touch,
        height: PawSize.touch,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: PawIcon(
          icon,
          size: 20,
          color: onTap == null ? Colors.white38 : Colors.white,
        ),
      ),
    ),
  );
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.day,
    required this.selected,
    required this.dots,
    required this.onTap,
  });
  final DateTime day;
  final bool selected;
  final int dots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : PawColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${dayHeading(day)}, ${dots == 0 ? 'no visits' : dots == 1 ? '1 visit' : '$dots visits'}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: selected ? PawColors.primary : PawColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: selected ? null : Border.all(color: PawColors.border),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dayAbbr(day),
                style: PawText.meta12.copyWith(
                  color: fg.withValues(alpha: selected ? 0.9 : 0.7),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              Text('${dayNumber(day)}', style: PawText.heading22.copyWith(
                fontSize: 18,
                color: fg,
              )),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < dots.clamp(0, 3); i++)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : PawColors.dot,
                          shape: BoxShape.circle,
                        ),
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

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.v});
  final VisitItem v;

  @override
  Widget build(BuildContext context) {
    return PawCard(
      radius: PawRadius.cardSmall,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      semanticLabel:
          '${visitTime(v.startsAt)}${visitMeridiem(v.startsAt)}, ${v.service} for ${v.petName}, ${v.ownerName}',
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              visitTime(v.startsAt),
              style: PawText.body14Strong.copyWith(color: PawColors.muted),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${v.service} · ${v.petName}', style: PawText.body14Strong),
                Text(
                  [v.ownerName, if (v.breed != null) v.breed!].join(' · '),
                  style: PawText.meta12.copyWith(color: PawColors.muted),
                ),
              ],
            ),
          ),
          StatusTag(
            v.done
                ? 'Done'
                : v.status == 'confirmed'
                ? 'Confirmed'
                : v.status,
            highlight: v.status == 'confirmed',
          ),
        ],
      ),
    );
  }
}

class _OpenTile extends StatelessWidget {
  const _OpenTile({required this.slot, required this.onBlock});
  final OpenSlot slot;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PawRadius.cardSmall),
        border: Border.all(color: PawColors.outline, width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              visitTime(slot.startsAt),
              style: PawText.body14Strong.copyWith(color: PawColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              'Open for booking',
              style: PawText.body14Strong.copyWith(color: PawColors.muted),
            ),
          ),
          PawButton(
            label: 'Block',
            variant: PawButtonVariant.secondary,
            expand: false,
            height: 44,
            onPressed: onBlock,
          ),
        ],
      ),
    );
  }
}
