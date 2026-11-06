import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/models.dart';
import 'booking_widgets.dart';

/// Book care (design/screens/Services.dc.html): find a vet, groomer, trainer or boarding near you.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _search = TextEditingController();
  var _started = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = scope.booking;
    if (!_started) {
      _started = true;
      if (!c.providersLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) => c.loadProviders());
      }
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final area = scope.session.profile?.area;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: c.loadProviders,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.screenSide,
                  16,
                  PawSpace.screenSide,
                  32,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text('Book care', style: PawText.title28),
                            ),
                            if (area != null && area.isNotEmpty)
                              Row(
                                children: [
                                  const PawIcon(
                                    PawIconData.mapPin,
                                    size: 16,
                                    color: PawColors.muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      area,
                                      style: PawText.meta13.copyWith(
                                        color: PawColors.muted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      RoundIconButton(
                        icon: PawIconData.calendar,
                        semanticLabel: 'My bookings',
                        onPressed: () => context.push('/bookings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PawTextField(
                    label: 'Search services',
                    controller: _search,
                    hint: 'Vet, groomer, vaccination',
                    textInputAction: TextInputAction.search,
                    prefix: const PawIcon(
                      PawIconData.search,
                      size: 20,
                      color: PawColors.muted,
                    ),
                    onSubmitted: c.search,
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final cat in ServiceCategory.values) ...[
                          PawChip(
                            label: cat.label,
                            selected: c.category == cat,
                            onTap: () => c.setCategory(cat),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  PawCard(
                    color: PawColors.warmSoft,
                    radius: PawRadius.cardSmall,
                    onTap: () => context.push('/emergency'),
                    semanticLabel: 'Emergency? Show clinics open now',
                    child: Row(
                      children: [
                        const PawIcon(
                          PawIconData.alertTriangle,
                          color: PawColors.warmText,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Emergency? Show clinics open now',
                            style: PawText.body15Strong.copyWith(
                              color: PawColors.warmText,
                            ),
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
                  const SizedBox(height: 22),
                  SectionLabel(_heading(c)),
                  const SizedBox(height: 12),
                  if (c.loadingProviders && c.providers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (c.providersError != null && c.providers.isEmpty)
                    LoadError(
                      message: c.providersError!,
                      onRetry: c.loadProviders,
                    )
                  else if (c.providers.isEmpty)
                    InfoCard(
                      title: 'Nobody found',
                      body: c.query.isEmpty
                          ? 'There are no ${c.category.label.toLowerCase()} taking bookings near you yet.'
                          : 'Nothing matches "${c.query}". Try another word.',
                      icon: PawIconData.search,
                    )
                  else
                    for (final p in c.providers)
                      ProviderCard(
                        provider: p,
                        now: c.now,
                        onTap: () => context.push('/provider/${p.id}'),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _heading(dynamic c) => switch (c.category as ServiceCategory) {
    ServiceCategory.vet => 'Verified vets near you',
    ServiceCategory.grooming => 'Groomers near you',
    ServiceCategory.training => 'Trainers near you',
    ServiceCategory.boarding => 'Boarding near you',
  };
}
