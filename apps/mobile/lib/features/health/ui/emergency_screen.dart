import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../onboarding/data/repositories.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../../onboarding/ui/onboarding_page.dart';
import '../domain/health_logic.dart';
import '../domain/models.dart';
import 'health_widgets.dart';

/// Emergency vets (design/screens/Emergency.dc.html): who is open, how far, and a Call button.
/// Phone numbers are used to place the call and are never shown on screen.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  List<EmergencyVet>? _vets;
  ({double lat, double lng})? _where;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  AppServices get _services => AppScope.of(context).services;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // The position is optional: without it the list still shows, just without distances.
      final where = await _services.location.current();
      final vets = await _services.vets.emergencyVets(
        lat: where?.lat,
        lng: where?.lng,
      );
      if (!mounted) return;
      setState(() {
        _where = where;
        _vets = vets;
        _loading = false;
      });
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _open(Uri uri, String failure) async {
    final ok = await _services.links.open(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  Future<void> _shareLocation(EmergencyVet vet) async {
    final w = _where;
    if (w == null) return;
    final text =
        'I need a vet urgently. My location: ${locationUri(w.lat, w.lng)}';
    await _open(whatsAppUri(text), 'We could not open WhatsApp.');
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final area = scope.session.profile?.area;
    final pet = scope.health.selected;
    final intro = _where == null && !_loading
        ? "Turn on location to see the nearest clinics. Open ones come first, 24 hour clinics at the top. Call ahead so they're ready."
        : "Open now${(area ?? '').isEmpty ? ' near you' : ' near $area'}, 24 hour clinics first. Call ahead so they're ready.";
    return Scaffold(
      backgroundColor: PawColors.ground,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              color: PawColors.danger,
              padding: EdgeInsets.fromLTRB(
                PawSpace.screenSide,
                MediaQuery.paddingOf(context).top + 12,
                PawSpace.screenSide,
                22,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoundIconButton(
                    icon: PawIconData.chevronLeft,
                    semanticLabel: 'Back',
                    background: Colors.white.withValues(alpha: 0.16),
                    iconColor: Colors.white,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    header: true,
                    child: Text(
                      'Emergency vets',
                      style: PawText.title28.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    intro,
                    style: PawText.body14.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PawSpace.screenSide,
                16,
                PawSpace.screenSide,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null) ...[
                    ErrorNote(_error!),
                    TextLinkButton(label: 'Try again', onPressed: _load),
                  ] else if ((_vets ?? const []).isEmpty)
                    const InfoCard(
                      title: 'No clinics found',
                      body: 'We could not find an emergency clinic to show. Call a vet you know, or pull down to try again.',
                    )
                  else
                    for (final v in _vets!) ...[
                      _VetCard(
                        vet: v,
                        canShareLocation: _where != null,
                        onCall: v.phone == null
                            ? null
                            : () => _open(
                                telUri(v.phone!),
                                'We could not start the call.',
                              ),
                        onDirections: v.lat == null || v.lng == null
                            ? null
                            : () => _open(
                                directionsUri(v.lat!, v.lng!),
                                'We could not open maps.',
                              ),
                        onShareLocation: () => _shareLocation(v),
                      ),
                      const SizedBox(height: 12),
                    ],
                  if (pet != null) ...[
                    const SizedBox(height: 4),
                    _SharePassportRow(petName: pet.name),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VetCard extends StatelessWidget {
  const _VetCard({
    required this.vet,
    required this.canShareLocation,
    required this.onCall,
    required this.onDirections,
    required this.onShareLocation,
  });

  final EmergencyVet vet;
  final bool canShareLocation;
  final VoidCallback? onCall;
  final VoidCallback? onDirections;
  final VoidCallback onShareLocation;

  @override
  Widget build(BuildContext context) {
    final distance = distanceText(vet.distanceMeters);
    final where = distance ?? ((vet.area ?? '').isEmpty ? null : vet.area);
    final status = vet.homeVisits && !vet.open24h
        ? 'Visits homes'
        : openStatus(vet);
    final meta = [?where, status].join(' · ');
    return PawCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vet.name, style: PawText.button16),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: PawText.meta12.copyWith(color: PawColors.muted),
                    ),
                  ],
                ),
              ),
              if (vet.open24h) const PawBadge.verified('24/7'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (onCall != null)
                Expanded(
                  child: PawButton(
                    label: 'Call',
                    variant: PawButtonVariant.danger,
                    height: 46,
                    onPressed: onCall,
                  ),
                ),
              if (onCall != null &&
                  (onDirections != null ||
                      (vet.homeVisits && canShareLocation)))
                const SizedBox(width: 8),
              if (vet.homeVisits && canShareLocation)
                Expanded(
                  child: PawButton(
                    label: 'Share location',
                    variant: PawButtonVariant.secondary,
                    height: 46,
                    onPressed: onShareLocation,
                  ),
                )
              else if (onDirections != null)
                Expanded(
                  child: PawButton(
                    label: 'Directions',
                    variant: PawButtonVariant.secondary,
                    height: 46,
                    onPressed: onDirections,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SharePassportRow extends StatelessWidget {
  const _SharePassportRow({required this.petName});
  final String petName;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(PawRadius.input);
    return Semantics(
      button: true,
      label: "Share $petName's passport with the clinic",
      excludeSemantics: true,
      onTap: () => context.push('/share'),
      child: Material(
        color: PawColors.dangerSoft,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: () => context.push('/share'),
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Share $petName's passport with the clinic",
                      style: PawText.body14Strong.copyWith(
                        color: const Color(0xFF8A2016),
                      ),
                    ),
                  ),
                  const PawIcon(
                    PawIconData.share,
                    size: 20,
                    color: Color(0xFF8A2016),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
