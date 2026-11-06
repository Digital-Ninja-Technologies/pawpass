import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/models.dart';

/// Adoption application (design/screens/AdoptApply.dc.html).
class ApplyScreen extends StatefulWidget {
  const ApplyScreen({super.key, required this.listingId});
  final String listingId;

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  HomeType? _home;
  final _daytime = TextEditingController();
  final _why = TextEditingController();
  var _agree = false;
  var _started = false;

  @override
  void dispose() {
    _daytime.dispose();
    _why.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = scope.adopt;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        c.applyError = null;
        if (c.detail?.listing.id != widget.listingId) {
          c.openListing(widget.listingId);
        }
      });
    }
    final pets = scope.health.pets;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final d = c.detail;
        final name = d?.listing.petName ?? 'this pet';
        final ready =
            _home != null &&
            _why.text.trim().length >= 10 &&
            _agree &&
            !c.applying;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      PawSpace.screenSide,
                      12,
                      PawSpace.screenSide,
                      24,
                    ),
                    children: [
                      BookingHeader('Apply to adopt $name'),
                      const SizedBox(height: 6),
                      if (d != null)
                        Text(
                          '${d.listing.petName} · ${d.listing.breed ?? d.listing.species} · ${d.listing.partnerName}',
                          style: PawText.meta13.copyWith(
                            color: PawColors.muted,
                          ),
                        ),
                      const SizedBox(height: 20),
                      const SectionLabel('Your home'),
                      const SizedBox(height: 10),
                      for (final h in HomeType.values)
                        ChoiceRow(
                          title: h.label,
                          selected: _home == h,
                          onTap: () => setState(() => _home = h),
                        ),
                      const SizedBox(height: 10),
                      const SectionLabel('Other pets at home'),
                      const SizedBox(height: 8),
                      PawCard(
                        radius: PawRadius.cardSmall,
                        child: Text(
                          pets.isEmpty
                              ? 'No other pets yet.'
                              : '${pets.map((p) => p.name).join(' and ')}, shared from their passports',
                          style: PawText.body14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      PawTextField(
                        label: 'Who is home during the day?',
                        controller: _daytime,
                        hint: 'For example, I work from home',
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 18),
                      PawNoteField(
                        label: 'Why $name?',
                        controller: _why,
                        maxLength: 600,
                        hint:
                            'Tell the shelter a little about you and your home',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      PawToggleRow(
                        label: 'I agree to a short home visit or video call with the shelter',
                        value: _agree,
                        onChanged: (v) => setState(() => _agree = v),
                      ),
                      if (c.applyError != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            c.applyError!,
                            style: PawText.body14.copyWith(
                              color: PawColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PawStickyFooter(
                  children: [
                    PawButton(
                      label: 'Send application',
                      loading: c.applying,
                      onPressed: !ready
                          ? null
                          : () async {
                              final other = pets.isEmpty
                                  ? ''
                                  : pets.map((p) => p.name).join(' and ');
                              final ok = await c.apply(
                                widget.listingId,
                                AdoptionAnswers(
                                  homeType: _home!,
                                  otherPets: other,
                                  daytime: _daytime.text,
                                  why: _why.text,
                                  agreeVisit: _agree,
                                ),
                              );
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Application sent. The shelter will be in touch.',
                                      ),
                                    ),
                                  );
                                context.pop();
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
