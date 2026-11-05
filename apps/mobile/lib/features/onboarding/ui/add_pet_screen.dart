import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dates.dart';
import '../../../ui/ui.dart';
import '../domain/models.dart';
import '../domain/pet_age.dart';
import '../state/app_scope.dart';
import '../state/onboarding_controller.dart';
import 'onboarding_page.dart';

const _dogBreeds = [
  'Boerboel',
  'German Shepherd',
  'Rottweiler',
  'Labrador Retriever',
  'Golden Retriever',
  'Caucasian Shepherd',
  'Cane Corso',
  'Siberian Husky',
  'Pit Bull',
  'Poodle',
  'Mixed or local breed',
];
const _catBreeds = [
  'Domestic shorthair',
  'Persian',
  'Siamese',
  'Maine Coon',
  'British Shorthair',
  'Tabby',
  'Mixed or local breed',
];

List<String> breedsFor(Species s) => switch (s) {
  Species.dog => _dogBreeds,
  Species.cat => _catBreeds,
  Species.other => const [],
};

class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key});

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _name = TextEditingController();
  final _years = TextEditingController();
  final _months = TextEditingController();
  var _approx = false;
  var _seeded = false;
  String? _ageError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded) {
      _seeded = true;
      _name.text = AppScope.of(context).onboarding.petName;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _years.dispose();
    _months.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final scope = AppScope.of(context);
    final ob = scope.onboarding;
    try {
      final result = await choosePhoto(
        context,
        fromCamera: scope.services.photos.fromCamera,
        fromGallery: scope.services.photos.fromGallery,
        hasPhoto: ob.petPhoto != null,
      );
      if (result == null) return;
      ob.petPhoto = result.removed ? null : (result.photo ?? ob.petPhoto);
      ob.notify();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _pickDob() async {
    final ob = AppScope.of(context).onboarding;
    final today = ob.today;
    final d = await pickDate(
      context,
      first: DateTime(today.year - 30),
      last: today,
      initial:
          ob.dateOfBirth ?? DateTime(today.year - 1, today.month, today.day),
      help: "Date of birth",
    );
    if (d != null) ob.setDateOfBirth(d);
  }

  Future<void> _pickBreed() async {
    final ob = AppScope.of(context).onboarding;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PawColors.surface,
      showDragHandle: true,
      builder: (_) => _BreedSheet(species: ob.species, current: ob.breed),
    );
    if (picked != null) {
      ob.breed = picked;
      ob.notify();
    }
  }

  void _ageChanged() {
    final ob = AppScope.of(context).onboarding;
    final y = int.tryParse(
      _years.text.trim().isEmpty ? '0' : _years.text.trim(),
    );
    final m = int.tryParse(
      _months.text.trim().isEmpty ? '0' : _months.text.trim(),
    );
    if (y == null || m == null) {
      setState(() => _ageError = 'Use numbers only.');
      return;
    }
    final ok = ob.setApproximateAge(years: y, months: m);
    setState(
      () => _ageError = ok || (y == 0 && m == 0)
          ? null
          : 'Years can be 0 to 40 and months 0 to 11.',
    );
    if (!ok) ob.setDateOfBirth(null);
  }

  /// Sex and birth date side by side. In "approximate age" mode the age boxes get their own row so
  /// they stay readable on small screens with large text.
  Widget _sexAndAge(OnboardingController ob, DateTime? dob) {
    final sex = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sex', style: PawText.meta13.copyWith(color: PawColors.ink2)),
        const SizedBox(height: 6),
        PawSegmented<PetSex?>(
          segments: const [
            PawSegment<PetSex?>(PetSex.male, 'Male'),
            PawSegment<PetSex?>(PetSex.female, 'Female'),
          ],
          value: ob.sex,
          onChanged: (v) {
            ob.sex = v;
            ob.notify();
          },
        ),
      ],
    );
    if (!_approx) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: sex),
          const SizedBox(width: 10),
          Expanded(
            child: PickerField(
              label: 'Date of birth',
              value: dob == null ? null : formatDate(dob),
              hint: 'Choose',
              onTap: _pickDob,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sex,
        const SizedBox(height: 18),
        Text(
          'Age (about)',
          style: PawText.meta13.copyWith(color: PawColors.ink2),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _AgeBox(
                controller: _years,
                suffix: 'yrs',
                label: 'Years',
                onChanged: _ageChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AgeBox(
                controller: _months,
                suffix: 'mos',
                label: 'Months',
                onChanged: _ageChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final ob = scope.onboarding;
    return ListenableBuilder(
      listenable: ob,
      builder: (context, _) {
        final dob = ob.dateOfBirth;
        return OnboardingPage(
          step: ob.anotherPet ? null : 5,
          title: ob.anotherPet ? 'Add another pet' : 'Add your first pet',
          subtitle: 'This creates their Pet Passport.',
          error: ob.error,
          gap: 18,
          form: [
            Semantics(
              container: true,
              label: 'Species',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Species',
                    style: PawText.meta13.copyWith(color: PawColors.ink2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final s in Species.values) ...[
                        if (s != Species.values.first) const SizedBox(width: 8),
                        PawChip(
                          label: s.label,
                          size: PawChipSize.large,
                          expand: true,
                          selected: ob.species == s,
                          onTap: () => ob.setSpecies(s),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PhotoPickerButton(
                  photo: ob.petPhoto,
                  onTap: _pickPhoto,
                  semanticLabel: ob.petPhoto == null
                      ? 'Add pet photo'
                      : 'Change pet photo',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PawTextField(
                    label: "Pet's name",
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 40,
                    onChanged: (v) {
                      ob.petName = v;
                      ob.notify();
                    },
                  ),
                ),
              ],
            ),
            PickerField(
              label: 'Breed',
              value: ob.breed,
              hint: ob.species == Species.other
                  ? 'Type or choose'
                  : 'Choose a breed',
              onTap: _pickBreed,
              trailing: const PawIcon(
                PawIconData.chevronDown,
                size: 16,
                color: PawColors.muted,
              ),
            ),
            _sexAndAge(ob, dob),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_approx && _ageError != null)
                  Text(
                    _ageError!,
                    style: PawText.meta13.copyWith(color: PawColors.danger),
                  )
                else if (_approx && dob != null)
                  Text(
                    'About ${ageLabel(dob, ob.today)} old',
                    style: PawText.meta13.copyWith(color: PawColors.muted),
                  ),
                TextLinkButton(
                  label: _approx
                      ? 'Enter the exact date instead'
                      : 'Not sure? Enter approximate age',
                  onPressed: () => setState(() {
                    _approx = !_approx;
                    _ageError = null;
                    if (!_approx) return;
                    _years.clear();
                    _months.clear();
                    ob.setDateOfBirth(null);
                  }),
                ),
              ],
            ),
          ],
          footer: [
            PawButton(
              label: 'Continue',
              onPressed: ob.petValid ? () => context.push('/pet-health') : null,
            ),
          ],
        );
      },
    );
  }
}

class _AgeBox extends StatelessWidget {
  const _AgeBox({
    required this.controller,
    required this.suffix,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String suffix;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      textField: true,
      child: Container(
        height: PawSize.input,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: PawColors.surface,
          borderRadius: BorderRadius.circular(PawRadius.input),
          border: Border.all(color: PawColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 2,
                onChanged: (_) => onChanged(),
                cursorColor: PawColors.primary,
                style: PawText.body15Strong,
                decoration: const InputDecoration.collapsed(hintText: '0')
                    .copyWith(counterText: ''),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                suffix,
                style: PawText.meta13.copyWith(color: PawColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Type a breed or tap a suggestion.
class _BreedSheet extends StatefulWidget {
  const _BreedSheet({required this.species, required this.current});
  final Species species;
  final String current;

  @override
  State<_BreedSheet> createState() => _BreedSheetState();
}

class _BreedSheetState extends State<_BreedSheet> {
  late final _text = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = breedsFor(widget.species);
    final q = _text.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? all
        : all.where((b) => b.toLowerCase().contains(q)).toList();
    final typed = _text.text.trim();
    final exact = all.any((b) => b.toLowerCase() == q);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PawSpace.onboardingSide,
            0,
            PawSpace.onboardingSide,
            16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PawTextField(
                label: 'Breed',
                controller: _text,
                hint: 'Type a breed',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (v) => Navigator.pop(context, v.trim()),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final b in shown)
                      InkWell(
                        onTap: () => Navigator.pop(context, b),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          alignment: Alignment.centerLeft,
                          child: Text(b, style: PawText.body15Strong),
                        ),
                      ),
                  ],
                ),
              ),
              if (typed.isNotEmpty && !exact) ...[
                const SizedBox(height: 8),
                PawButton(
                  label: 'Use "$typed"',
                  onPressed: () => Navigator.pop(context, typed),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
