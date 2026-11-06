import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../../onboarding/ui/onboarding_page.dart'
    show PickerField, PhotoPickerButton, choosePhoto, pickDate;
import '../domain/models.dart';
import '../domain/partner_logic.dart';

/// New listing (design/screens/BreederListing.dc.html). Breeders list a puppy or a whole litter for a price;
/// shelters add a pet for adoption, which is free.
class ListingFormScreen extends StatefulWidget {
  const ListingFormScreen({super.key});

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _price = TextEditingController();
  PickedPhoto? _photo;
  var _litter = false;
  var _count = 3;
  var _species = Species.dog;
  var _sex = PetSex.unknown;
  DateTime? _born;
  DateTime? _handover;
  Pet? _mother;
  Pet? _father;
  String? _nameError;
  String? _priceError;

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final scope = AppScope.of(context);
    final r = await choosePhoto(
      context,
      fromCamera: scope.services.photos.fromCamera,
      fromGallery: scope.services.photos.fromGallery,
      hasPhoto: _photo != null,
    );
    if (r == null || !mounted) {
      return;
    }
    setState(() => _photo = r.removed ? null : (r.photo ?? _photo));
  }

  Future<void> _pickParent(bool mother) async {
    final pets = AppScope.of(context).health.pets
        .where((p) => p.sex == (mother ? PetSex.female : PetSex.male))
        .toList();
    final picked = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: PawColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text('Not listed', style: PawText.body15),
              onTap: () => Navigator.pop(ctx, 'none'),
            ),
            for (final p in pets)
              ListTile(
                leading: PetAvatar(pet: p, size: 40),
                title: Text(p.name, style: PawText.body15),
                subtitle: p.breed == null ? null : Text(p.breed!),
                onTap: () => Navigator.pop(ctx, p),
              ),
            if (pets.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Add the ${mother ? 'mother' : 'father'} as a pet first, then choose it here.',
                  style: PawText.body14.copyWith(color: PawColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      final pet = picked is Pet ? picked : null;
      if (mother) {
        _mother = pet;
      } else {
        _father = pet;
      }
    });
  }

  Future<void> _publish(PartnerType type) async {
    final p = AppScope.of(context).partner;
    final nameProblem = validateListingName(_name.text);
    final sale = type == PartnerType.breeder;
    final priceProblem = sale ? validatePrice(_price.text) : null;
    setState(() {
      _nameError = nameProblem;
      _priceError = priceProblem;
    });
    if (nameProblem != null || priceProblem != null) {
      return;
    }
    final ok = await p.publish(
      NewListing(
        name: _name.text.trim(),
        species: _species,
        breed: _breed.text.trim().isEmpty ? null : _breed.text.trim(),
        sex: _sex,
        bornOn: _born,
        priceKobo: sale ? parsePriceKobo(_price.text) : null,
        count: sale && _litter ? _count : 1,
        motherPetId: _mother?.id,
        fatherPetId: _father?.id,
        handoverBy: _handover,
      ),
      photo: _photo,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              sale && _litter
                  ? 'Your litter is live.'
                  : '${_name.text.trim()} is live.',
            ),
          ),
        );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.partner;
    final type = p.application?.type ?? PartnerType.breeder;
    final sale = type == PartnerType.breeder;
    final now = p.now;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => Scaffold(
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
                    BookingHeader(
                      sale ? 'New listing' : 'Add a pet',
                      trailing: const PawBadge.verified('Verified'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: PhotoPickerButton(
                        photo: _photo,
                        onTap: _pickPhoto,
                        size: 120,
                        label: _photo == null ? 'Add a photo' : null,
                        semanticLabel: _photo == null
                            ? 'Add a photo'
                            : 'Change the photo',
                      ),
                    ),
                    if (sale) ...[
                      const SizedBox(height: 18),
                      PawSegmented<bool>(
                        segments: const [
                          PawSegment(false, 'Single puppy'),
                          PawSegment(true, 'Whole litter'),
                        ],
                        value: _litter,
                        onChanged: (v) => setState(() => _litter = v),
                      ),
                      if (_litter) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'How many puppies?',
                                style: PawText.body15Strong,
                              ),
                            ),
                            RoundIconButton(
                              icon: PawIconData.chevronLeft,
                              semanticLabel: 'Fewer puppies',
                              onPressed: () {
                                if (_count > 2) {
                                  setState(() => _count--);
                                }
                              },
                            ),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '$_count',
                                textAlign: TextAlign.center,
                                style: PawText.heading22,
                              ),
                            ),
                            RoundIconButton(
                              icon: PawIconData.chevronRight,
                              semanticLabel: 'More puppies',
                              onPressed: () {
                                if (_count < 12) {
                                  setState(() => _count++);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 18),
                    PawTextField(
                      label: _litter ? 'Litter name' : 'Name',
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      errorText: _nameError,
                      hint: _litter ? 'Each puppy is numbered' : null,
                    ),
                    const SizedBox(height: 14),
                    const SectionLabel('Species'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final s in Species.values)
                          PawChip(
                            label: s.label,
                            selected: _species == s,
                            onTap: () => setState(() => _species = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    PawTextField(
                      label: 'Breed',
                      controller: _breed,
                      textCapitalization: TextCapitalization.words,
                    ),
                    if (!_litter) ...[
                      const SizedBox(height: 14),
                      const SectionLabel('Sex'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s in PetSex.values)
                            PawChip(
                              label: s.label,
                              selected: _sex == s,
                              onTap: () => setState(() => _sex = s),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    PickerField(
                      label: 'Born',
                      value: _born == null
                          ? null
                          : '${_born!.day}/${_born!.month}/${_born!.year}',
                      hint: 'Choose a date',
                      onTap: () async {
                        final d = await pickDate(
                          context,
                          first: DateTime(now.year - 20),
                          last: now,
                          initial: _born,
                          help: 'Date of birth',
                        );
                        if (d != null) {
                          setState(() => _born = d);
                        }
                      },
                    ),
                    if (sale) ...[
                      const SizedBox(height: 14),
                      PawTextField(
                        label: _litter ? 'Price each (₦)' : 'Price (₦)',
                        controller: _price,
                        keyboardType: TextInputType.number,
                        errorText: _priceError,
                        hint: '450,000',
                      ),
                      const SizedBox(height: 14),
                      PickerField(
                        label: 'Ready to go home from (optional)',
                        value: _handover == null
                            ? null
                            : '${_handover!.day}/${_handover!.month}/${_handover!.year}',
                        hint: 'Choose a date',
                        onTap: () async {
                          final d = await pickDate(
                            context,
                            first: now,
                            last: DateTime(now.year + 1),
                            initial: _handover,
                            help: 'Handover by',
                          );
                          if (d != null) {
                            setState(() => _handover = d);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 22),
                    PawCard(
                      radius: PawRadius.cardSmall,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Passport details', style: PawText.body15Strong),
                          const SizedBox(height: 10),
                          if (sale) ...[
                            PickerField(
                              label: 'Mother',
                              value: _mother?.name,
                              hint: 'Choose from your pets',
                              onTap: () => _pickParent(true),
                            ),
                            const SizedBox(height: 10),
                            PickerField(
                              label: 'Father',
                              value: _father?.name,
                              hint: 'Choose from your pets',
                              onTap: () => _pickParent(false),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            'Add vaccines and vet checks from each passport after you publish. Records a vet verified show to buyers with a tick.',
                            style: PawText.meta13.copyWith(
                              color: PawColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (p.publishError != null) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          p.publishError!,
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
                    label: sale ? 'Publish listing' : 'Publish for adoption',
                    loading: p.publishing,
                    onPressed: () => _publish(type),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sale
                        ? 'Each puppy gets its own passport that moves to the buyer.'
                        : "Each pet's passport moves to the adopter. Adoption is free.",
                    textAlign: TextAlign.center,
                    style: PawText.meta13.copyWith(color: PawColors.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
