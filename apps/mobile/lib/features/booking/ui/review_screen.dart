import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/booking_logic.dart';
import '../domain/models.dart';
import 'booking_widgets.dart';

/// Rate and review (design/screens/Review.dc.html): confirming the visit releases the payment.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  var _stars = 0;
  final _tags = <String>{};
  final _body = TextEditingController();

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final c = scope.booking;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final b = c.bookingById(widget.bookingId);
        if (b == null) {
          return Scaffold(
            backgroundColor: PawColors.ground,
            body: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(PawSpace.screenSide),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PawBackButton(),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'That booking could not be found.',
                        style: PawText.body15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final busy = c.busyId == b.id;
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
                      const BookingHeader('Rate and review'),
                      const SizedBox(height: 18),
                      Semantics(
                        header: true,
                        child: Text(
                          'How was ${b.petName}\'s ${b.serviceName.toLowerCase()}?',
                          style: PawText.title28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${b.partnerName} · ${dayLabel(b.startsAt)} · ${nairaFromKobo(b.amountKobo)}',
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: StarRow(
                          value: _stars,
                          onChanged: (v) => setState(() => _stars = v),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          _stars == 0
                              ? 'Tap a star (optional)'
                              : ratingWord(_stars),
                          style: PawText.body15Strong.copyWith(
                            color: _stars == 0
                                ? PawColors.muted
                                : PawColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('What went well?', style: PawText.body14Strong),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in reviewTags)
                            PawChip(
                              label: t,
                              selected: _tags.contains(t),
                              onTap: () => setState(
                                () => _tags.contains(t)
                                    ? _tags.remove(t)
                                    : _tags.add(t),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      PawNoteField(
                        label: 'Your review',
                        helper:
                            'Optional · shown publicly with your first name',
                        controller: _body,
                        hint: 'What should other owners know?',
                      ),
                      if (c.actionError != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            c.actionError!,
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
                      label:
                          'Confirm visit & release ${nairaFromKobo(b.amountKobo)}',
                      loading: busy,
                      onPressed: busy
                          ? null
                          : () async {
                              final ok = await c.confirmVisit(
                                b.id,
                                rating: _stars == 0 ? null : _stars,
                                tags: _tags.toList(),
                                body: _body.text.trim().isEmpty
                                    ? null
                                    : _body.text.trim(),
                              );
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Thank you. The payment has been released.',
                                    ),
                                  ),
                                );
                                context.pop();
                              }
                            },
                    ),
                    PawButton(
                      label: 'Something went wrong',
                      variant: PawButtonVariant.secondary,
                      onPressed: busy
                          ? null
                          : () => context.pushReplacement('/dispute/${b.id}'),
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
