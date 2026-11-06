import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/domain/booking_logic.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/models.dart';
import '../state/lost_controller.dart';

/// Report a lost pet (design/screens/LostPet.dc.html): where and when, what finders should know, and how far to alert.
class LostPetScreen extends StatefulWidget {
  const LostPetScreen({super.key});

  @override
  State<LostPetScreen> createState() => _LostPetScreenState();
}

class _LostPetScreenState extends State<LostPetScreen> {
  final _address = TextEditingController();
  final _note = TextEditingController();
  String? _petId;
  DateTime? _seenAt;
  var _radius = 5000;
  var _started = false;

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lost = scope.lost;
    final pets = scope.health.pets;
    if (!_started) {
      _started = true;
      _petId = scope.health.selected?.id;
      _seenAt = lost.now;
      WidgetsBinding.instance.addPostFrameCallback((_) => lost.startRaise());
    }
    final pet = pets.where((p) => p.id == _petId).firstOrNull;
    final seen = _seenAt ?? lost.now;
    return ListenableBuilder(
      listenable: lost,
      builder: (context, _) {
        final ready = pet != null && lost.spot != null && !lost.sending;
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
                      const BookingHeader('Report a lost pet'),
                      const SizedBox(height: 18),
                      if (pets.isEmpty)
                        const InfoCard(
                          title: 'Add a pet first',
                          body: 'Alerts are sent for a pet with a passport.',
                          icon: PawIconData.paw,
                        )
                      else ...[
                        if (pets.length > 1) ...[
                          const SectionLabel('Which pet'),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final p in pets) ...[
                                  PawChip(
                                    label: p.name,
                                    selected: _petId == p.id,
                                    onTap: () => setState(() => _petId = p.id),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (pet != null)
                          PawCard(
                            radius: PawRadius.cardSmall,
                            child: Row(
                              children: [
                                PetAvatar(pet: pet, size: 52, radius: 14),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pet.name,
                                        style: PawText.body15Strong,
                                      ),
                                      Text(
                                        [
                                          pet.breed,
                                          pet.species.label,
                                        ].whereType<String>().join(' · '),
                                        style: PawText.meta13.copyWith(
                                          color: PawColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 22),
                        const SectionLabel('Last seen'),
                        const SizedBox(height: 10),
                        PawTextField(
                          label: 'Address',
                          controller: _address,
                          hint: 'Street, area',
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 10),
                        PawButton(
                          label: lost.spot != null
                              ? 'Location set · tap to update'
                              : 'Use my current location',
                          variant: PawButtonVariant.secondary,
                          loading: lost.locating,
                          onPressed: lost.locating ? null : lost.useMyLocation,
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            lost.spot != null
                                ? 'Alerts reach people around this spot.'
                                : 'Stand where your pet was last seen, or set it from the phone you have with you.',
                            style: PawText.meta13.copyWith(
                              color: PawColors.muted,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _PickerField(
                                label: 'Date',
                                value: dayLabel(seen),
                                onTap: () => _pickDate(context, seen),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PickerField(
                                label: 'Time',
                                value: timeLabel(seen),
                                onTap: () => _pickTime(context, seen),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        PawNoteField(
                          label: 'Anything finders should know?',
                          controller: _note,
                          maxLength: 500,
                          hint: 'Collar, how friendly, what to do',
                        ),
                        const SizedBox(height: 20),
                        const SectionLabel('Alert people within'),
                        const SizedBox(height: 10),
                        PawSegmented<int>(
                          segments: [
                            for (final r in lostRadiusOptions)
                              PawSegment(r, '${r ~/ 1000} km'),
                          ],
                          value: _radius,
                          onChanged: (v) => setState(() => _radius = v),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Finders chat with you in the app; your number stays hidden.${pet == null ? '' : " ${pet.name}'s QR tag switches to Lost mode."}",
                          style: PawText.meta13.copyWith(
                            color: PawColors.muted,
                            height: 1.5,
                          ),
                        ),
                        if (lost.sendError != null) ...[
                          const SizedBox(height: 14),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              lost.sendError!,
                              style: PawText.body14.copyWith(
                                color: PawColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                PawStickyFooter(
                  children: [
                    PawButton(
                      label: 'Send lost-pet alert',
                      variant: PawButtonVariant.warm,
                      loading: lost.sending,
                      onPressed: ready
                          ? () => _send(context, lost, pet.id, seen)
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

  Future<void> _send(
    BuildContext context,
    LostController lost,
    String petId,
    DateTime seen,
  ) async {
    final id = await lost.raise(
      petId: petId,
      address: _address.text,
      seenAt: seen,
      description: _note.text,
      radiusM: _radius,
    );
    if (id != null && context.mounted) {
      final n = lost.lastNotified;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              n == 0
                  ? 'Your alert is live.'
                  : 'Your alert is live. $n ${n == 1 ? 'person' : 'people'} nearby were told.',
            ),
          ),
        );
      context.pushReplacement('/lost/$id');
    }
  }

  Future<void> _pickDate(BuildContext context, DateTime current) async {
    final now = AppScope.of(context).lost.now;
    final l = lagos(current);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(l.year, l.month, l.day),
      firstDate: now.subtract(const Duration(days: 14)),
      lastDate: now,
    );
    if (picked != null) {
      final cur = lagos(current);
      // Lagos wall clock back to an instant.
      final wall = DateTime.utc(
        picked.year,
        picked.month,
        picked.day,
        cur.hour,
        cur.minute,
      );
      setState(() => _seenAt = wall.subtract(const Duration(hours: 1)));
    }
  }

  Future<void> _pickTime(BuildContext context, DateTime current) async {
    final l = lagos(current);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: l.hour, minute: l.minute),
    );
    if (picked != null) {
      final wall = DateTime.utc(
        l.year,
        l.month,
        l.day,
        picked.hour,
        picked.minute,
      );
      setState(() => _seenAt = wall.subtract(const Duration(hours: 1)));
    }
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(PawRadius.input),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: PawSize.input),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: PawColors.surface,
            borderRadius: BorderRadius.circular(PawRadius.input),
            border: Border.all(color: PawColors.outline, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: PawText.meta12.copyWith(color: PawColors.muted),
              ),
              Text(value, style: PawText.body15Strong),
            ],
          ),
        ),
      ),
    );
  }
}
