import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../domain/models.dart';
import '../domain/pet_age.dart';
import '../state/app_scope.dart';

/// "Bingo's passport is ready".
class AllSetScreen extends StatelessWidget {
  const AllSetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ob = AppScope.of(context).onboarding;
    final pet = ob.createdPet;
    if (pet == null) {
      // Nothing was just created (for example the app was reopened here): go home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/home');
      });
      return const Scaffold(backgroundColor: PawColors.ground);
    }
    final records = ob.given.length;
    final remindersOn = ob.channels.isNotEmpty;
    final summary = [
      if (records > 0) '$records ${records == 1 ? 'record' : 'records'} saved',
      remindersOn ? 'reminders are on' : 'reminders are off',
    ].join(' and ');

    final facts = [
      if ((pet.breed ?? '').isNotEmpty) pet.breed!,
      if (pet.sex != PetSex.unknown) pet.sex.label,
      if (pet.dateOfBirth != null) ageLabel(pet.dateOfBirth!, ob.today),
    ];
    return Scaffold(
      backgroundColor: PawColors.ground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.onboardingSide,
                  56,
                  PawSpace.onboardingSide,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: PawColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const PawIcon(
                          PawIconData.check,
                          size: 38,
                          color: PawColors.primaryText,
                          strokeWidth: 2.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      header: true,
                      child: Text(
                        "${pet.name}'s passport is ready",
                        textAlign: TextAlign.center,
                        style: PawText.title30,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${summary[0].toUpperCase()}${summary.substring(1)}.',
                      textAlign: TextAlign.center,
                      style: PawText.body15.copyWith(
                        color: PawColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _PassportCard(pet: pet, facts: facts, photo: ob.petPhoto),
                    const SizedBox(height: 20),
                    _TagCard(name: pet.name),
                    const Spacer(),
                    const SizedBox(height: 20),
                    PawButton(
                      label: 'Go to home',
                      onPressed: () {
                        // Pick up the pet that was just created.
                        AppScope.of(context).health.load();
                        context.go('/home');
                      },
                    ),
                    const SizedBox(height: 10),
                    PawButton(
                      label: 'Add another pet',
                      variant: PawButtonVariant.secondary,
                      onPressed: () {
                        AppScope.of(context).health.load();
                        ob.startAnotherPet();
                        context.go('/add-pet');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassportCard extends StatelessWidget {
  const _PassportCard({
    required this.pet,
    required this.facts,
    required this.photo,
  });
  final Pet pet;
  final List<String> facts;
  final PickedPhoto? photo;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PawColors.primary,
          borderRadius: BorderRadius.circular(PawRadius.card),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 64,
                height: 64,
                child: photo != null
                    ? Image.memory(photo!.bytes, fit: BoxFit.cover)
                    : ColoredBox(
                        color: PawColors.petTints.first,
                        child: const Center(
                          child: PawIcon(
                            PawIconData.paw,
                            size: 30,
                            color: PawColors.warmText,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: PawText.heading22.copyWith(color: Colors.white),
                  ),
                  if (facts.isNotEmpty)
                    Text(
                      facts.join(' · '),
                      style: PawText.meta13.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  if (pet.tagCode != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tag ID ${pet.tagCode}',
                      style: PawText.meta12.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

/// The QR collar tag needs payment, which arrives in milestone 3, so it is shown as coming soon
/// instead of a button that does nothing.
class _TagCard extends StatelessWidget {
  const _TagCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PawColors.warmSoft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final on in [
                      true,
                      false,
                      true,
                      false,
                      true,
                      false,
                      true,
                      true,
                      false,
                    ])
                      ColoredBox(
                        color: on ? PawColors.ink : Colors.transparent,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Get a QR collar tag', style: PawText.body15Strong),
                  const SizedBox(height: 2),
                  Text(
                    'Anyone who finds $name can reach you safely',
                    style: PawText.meta13.copyWith(
                      color: const Color(0xFF6B4A33),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Coming\nsoon',
              textAlign: TextAlign.center,
              style: PawText.meta12.copyWith(
                color: PawColors.warmText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
