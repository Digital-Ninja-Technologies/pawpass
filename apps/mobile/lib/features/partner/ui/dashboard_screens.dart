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

/// The fourth tab for shelters: every application.
class ApplicationsTab extends StatelessWidget {
  const ApplicationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => SafeArea(
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
              if (p.dashboard == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ApplicationsList(
                  applications: p.dashboard!.applications,
                  controller: p,
                ),
            ],
          ),
        ),
      ),
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

/// Calendar for vets and service providers (the design lists it but does not draw it).
class CalendarTab extends StatelessWidget {
  const CalendarTab({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(PawSpace.screenSide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Calendar', style: PawText.title28),
          ),
          const Spacer(),
          Text(
            'The full calendar is coming soon',
            textAlign: TextAlign.center,
            style: PawText.heading22,
          ),
          const SizedBox(height: 8),
          Text(
            "Today's visits are on the Today tab.",
            textAlign: TextAlign.center,
            style: PawText.body15.copyWith(color: PawColors.muted),
          ),
          const SizedBox(height: 16),
          PawButton(
            label: 'See today',
            expand: false,
            variant: PawButtonVariant.secondary,
            onPressed: () => StatefulNavigationShell.of(context).goBranch(0),
          ),
          const Spacer(),
        ],
      ),
    ),
  );
}
