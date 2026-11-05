import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../state/app_scope.dart';
import '../state/onboarding_controller.dart';
import 'onboarding_page.dart';

/// Lagos areas offered as one tap suggestions. The field accepts any text.
const lagosAreas = [
  'Lekki',
  'Ikeja',
  'Yaba',
  'Victoria Island',
  'Ikoyi',
  'Surulere',
  'Ajah',
  'Gbagada',
];

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final _first = TextEditingController(text: _ob.firstName);
  late final _last = TextEditingController(text: _ob.lastName);
  late final _area = TextEditingController(text: _ob.area);
  late final _phone = TextEditingController(text: _ob.phone);

  OnboardingController get _ob => AppScope.of(context).onboarding;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _area.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    final scope = AppScope.of(context);
    final ob = scope.onboarding;
    try {
      final result = await choosePhoto(
        context,
        fromCamera: scope.services.photos.fromCamera,
        fromGallery: scope.services.photos.fromGallery,
        hasPhoto: ob.avatar != null,
      );
      if (result == null) return;
      ob.avatar = result.removed ? null : (result.photo ?? ob.avatar);
      ob.notify();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ob = AppScope.of(context).onboarding;
    return ListenableBuilder(
      listenable: ob,
      builder: (context, _) => OnboardingPage(
        step: 4,
        title: 'Tell us about you',
        error: ob.error,
        gap: 18,
        form: [
          Center(
            child: PhotoPickerButton(
              photo: ob.avatar,
              onTap: _photo,
              size: 104,
              circle: true,
              label: 'Add photo',
              semanticLabel: ob.avatar == null
                  ? 'Add your photo'
                  : 'Change your photo',
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PawTextField(
                  label: 'First name',
                  controller: _first,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  onChanged: (v) {
                    ob.firstName = v;
                    ob.notify();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PawTextField(
                  label: 'Last name',
                  controller: _last,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                  onChanged: (v) => ob.lastName = v,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PawTextField(
                label: 'Your area',
                controller: _area,
                hint: 'For example Lekki Phase 1, Lagos',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                prefix: const PawIcon(
                  PawIconData.mapPin,
                  size: 18,
                  color: PawColors.muted,
                ),
                onChanged: (v) => ob.area = v,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in lagosAreas)
                    PawChip(
                      label: a,
                      selected: _area.text.trim() == a,
                      onTap: () {
                        _area.text = a;
                        ob.area = a;
                        ob.notify();
                      },
                    ),
                ],
              ),
            ],
          ),
          PawTextField(
            label: 'Phone (optional)',
            controller: _phone,
            hint: '+234 800 000 0000',
            helperText:
                'Used for WhatsApp and SMS reminders. Never shown to others.',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (v) {
              ob.phone = v;
              ob.clearError();
            },
          ),
          Text(
            'Your area helps us show nearby vets and lost pet alerts. We never show your exact address.',
            style: PawText.meta12.copyWith(color: PawColors.muted, height: 1.5),
          ),
        ],
        footer: [
          PawButton(
            label: 'Continue',
            loading: ob.busy,
            onPressed: ob.firstName.trim().isEmpty
                ? null
                : () async {
                    final ok = await ob.saveProfile();
                    if (ok && context.mounted) context.push('/add-pet');
                  },
          ),
        ],
      ),
    );
  }
}
