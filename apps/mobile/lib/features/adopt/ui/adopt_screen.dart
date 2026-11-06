import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/adopt_logic.dart';
import '../domain/models.dart';
import 'adopt_widgets.dart';

/// Find a pet (design/screens/Adopt.dc.html): verified breeders and shelters, each pet with a passport.
class AdoptScreen extends StatefulWidget {
  const AdoptScreen({super.key});

  @override
  State<AdoptScreen> createState() => _AdoptScreenState();
}

class _AdoptScreenState extends State<AdoptScreen> {
  final _search = TextEditingController();
  var _started = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).adopt;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => c.load());
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final orders = c.activeOrders;
        final apps = c.activeApplications;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: c.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.screenSide,
                  16,
                  PawSpace.screenSide,
                  32,
                ),
                children: [
                  Semantics(
                    header: true,
                    child: Text('Find a pet', style: PawText.title28),
                  ),
                  const SizedBox(height: 14),
                  if (orders.isNotEmpty || apps.isNotEmpty) ...[
                    const SectionLabel('Your pets on the way'),
                    const SizedBox(height: 10),
                    for (final o in orders)
                      _StatusTile(
                        title: o.petName,
                        subtitle:
                            '${orderStatusBadge(o.status)} · ${o.partnerName}',
                        onTap: () => context.push('/orders/${o.id}'),
                      ),
                    for (final a in apps)
                      _StatusTile(
                        title: a.petName,
                        subtitle:
                            '${applicationLabel(a.status)} · ${a.partnerName}',
                        onTap: () => a.transferId != null
                            ? context.push('/transfer/${a.transferId}')
                            : context.push('/listing/${a.listingId}'),
                      ),
                    const SizedBox(height: 10),
                  ],
                  PawSegmented<ListingKind>(
                    segments: const [
                      PawSegment(ListingKind.sale, 'Verified breeders'),
                      PawSegment(ListingKind.adoption, 'Shelters & rescue'),
                    ],
                    value: c.kind,
                    onChanged: c.setKind,
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        PawChip(
                          label: 'All pets',
                          selected: c.species == null,
                          onTap: () => c.setSpecies(null),
                        ),
                        const SizedBox(width: 8),
                        PawChip(
                          label: 'Dogs',
                          selected: c.species == 'dog',
                          onTap: () => c.setSpecies('dog'),
                        ),
                        const SizedBox(width: 8),
                        PawChip(
                          label: 'Cats',
                          selected: c.species == 'cat',
                          onTap: () => c.setSpecies('cat'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  PawTextField(
                    label: 'Search pets',
                    controller: _search,
                    hint: 'Name, breed or seller',
                    textInputAction: TextInputAction.search,
                    prefix: const PawIcon(
                      PawIconData.search,
                      size: 20,
                      color: PawColors.muted,
                    ),
                    onSubmitted: c.search,
                  ),
                  const SizedBox(height: 14),
                  PawCard(
                    color: PawColors.primarySoft,
                    radius: PawRadius.cardSmall,
                    child: Text(
                      'Every pet here comes with a verified passport, and payments are held in escrow.',
                      style: PawText.meta13.copyWith(
                        color: PawColors.primaryText,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (c.loading && c.listings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (c.error != null && c.listings.isEmpty)
                    LoadError(message: c.error!, onRetry: c.load)
                  else if (c.listings.isEmpty)
                    const InfoCard(
                      title: 'No pets found',
                      body: 'Nothing matches right now. Try another filter, or check back soon.',
                      icon: PawIconData.paw,
                    )
                  else
                    for (final l in c.listings)
                      ListingCard(listing: l, now: c.now),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PawCard(
        radius: PawRadius.cardSmall,
        color: PawColors.warmSoft,
        onTap: onTap,
        semanticLabel: '$title. $subtitle',
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: PawText.body15Strong),
                  Text(
                    subtitle,
                    style: PawText.meta13.copyWith(color: PawColors.warmText),
                  ),
                ],
              ),
            ),
            const PawIcon(
              PawIconData.chevronRight,
              size: 20,
              color: PawColors.warmText,
            ),
          ],
        ),
      ),
    );
  }
}
