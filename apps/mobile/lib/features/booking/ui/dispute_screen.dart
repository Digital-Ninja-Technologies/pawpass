import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/booking_logic.dart';
import '../domain/models.dart';
import 'booking_widgets.dart';

/// Report a problem (design/screens/OpenDispute.dc.html): the payment stays on hold and PawPass decides.
class DisputeScreen extends StatefulWidget {
  const DisputeScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  DisputeReason? _reason;
  final _details = TextEditingController();
  final _photos = <PickedPhoto>[];
  String? _photoError;

  static const maxPhotos = 5;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final picker = AppScope.of(context).services.photos;
    final photo = await picker.fromGallery();
    if (photo == null || !mounted) return;
    if (photo.bytes.length > 8 * 1024 * 1024) {
      setState(
        () => _photoError = 'That photo is too large. Choose one under 8 MB.',
      );
      return;
    }
    setState(() {
      _photoError = null;
      _photos.add(photo);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).booking;
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
        final ready = _reason != null && !busy;
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
                      const BookingHeader('Report a problem'),
                      const SizedBox(height: 16),
                      Text(
                        '${b.serviceName} for ${b.petName}',
                        style: PawText.body15Strong,
                      ),
                      Text(
                        '${b.partnerName} · ${dayLabel(b.startsAt)} · ${nairaFromKobo(b.amountKobo)} held',
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                      ),
                      const SizedBox(height: 22),
                      Text('What went wrong?', style: PawText.body14Strong),
                      const SizedBox(height: 10),
                      for (final r in DisputeReason.values)
                        ChoiceRow(
                          title: r.label,
                          selected: _reason == r,
                          onTap: () => setState(() => _reason = r),
                        ),
                      const SizedBox(height: 12),
                      PawNoteField(
                        label: 'Tell us what happened',
                        controller: _details,
                        maxLength: 2000,
                        hint: 'What did you see, and when?',
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Add photos or a vet report',
                        style: PawText.body14Strong,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (var i = 0; i < _photos.length; i++)
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.memory(
                                    _photos[i].bytes,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    semanticLabel: 'Photo ${i + 1}',
                                    errorBuilder: (_, _, _) => Container(
                                      width: 72,
                                      height: 72,
                                      color: PawColors.subtle,
                                      child: const Icon(Icons.image_outlined),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -10,
                                  right: -10,
                                  child: RoundIconButton(
                                    icon: PawIconData.close,
                                    semanticLabel: 'Remove photo ${i + 1}',
                                    onPressed: () =>
                                        setState(() => _photos.removeAt(i)),
                                  ),
                                ),
                              ],
                            ),
                          if (_photos.length < maxPhotos)
                            Semantics(
                              button: true,
                              label: 'Add a photo',
                              excludeSemantics: true,
                              onTap: _addPhoto,
                              child: GestureDetector(
                                key: const Key('add-photo'),
                                onTap: _addPhoto,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: PawColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: PawColors.outline,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: PawIcon(
                                      PawIconData.camera,
                                      color: PawColors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_photoError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _photoError!,
                          style: PawText.meta13.copyWith(
                            color: PawColors.danger,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      PawCard(
                        color: PawColors.primarySoft,
                        radius: PawRadius.cardSmall,
                        child: Text(
                          'The ${nairaFromKobo(b.amountKobo)} stays on hold. The PawPass team reviews both sides and decides within 72 hours.',
                          style: PawText.meta13.copyWith(
                            color: PawColors.primaryText,
                            height: 1.5,
                          ),
                        ),
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
                      label: 'Send to PawPass',
                      loading: busy,
                      onPressed: ready
                          ? () async {
                              final ok = await c.report(
                                b.id,
                                reason: _reason!,
                                details: _details.text.trim().isEmpty
                                    ? null
                                    : _details.text.trim(),
                                evidence: _photos,
                              );
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'We got your report. The payment stays on hold.',
                                    ),
                                  ),
                                );
                                context.pop();
                              }
                            }
                          : null,
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
