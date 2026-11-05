import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// Review screen for every design system component, with the states the
/// designs show (design/screens/Specs.dc.html). Open it at `/gallery`.
class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  String _species = 'Dog';
  String _filter = 'Selected';
  String _segment = 'Health';
  bool _pushOn = true;
  bool _whatsappOn = false;
  PawTab _tab = PawTab.home;
  int _step = 5;
  bool _loading = false;
  final _name = TextEditingController(text: 'Bingo');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawColors.ground,
      bottomNavigationBar: PawTabBar(
        active: _tab,
        onSelected: (t) => setState(() => _tab = t),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            PawSpace.screenSide,
            12,
            PawSpace.screenSide,
            32,
          ),
          children: [
            Row(
              children: [
                const PawBackButton(),
                const SizedBox(width: 14),
                Expanded(child: PawStepProgress(step: _step, total: 6)),
              ],
            ),
            const SizedBox(height: 18),
            Semantics(
              header: true,
              child: const Text('Component gallery', style: PawText.title30),
            ),
            const SizedBox(height: 6),
            const Text(
              'Every design system component in the states the designs use.',
              style: PawText.body15,
            ),
            _section('Step progress'),
            PawSegmented<int>(
              segments: const [
                PawSegment(1, 'Step 1'),
                PawSegment(3, 'Step 3'),
                PawSegment(5, 'Step 5'),
              ],
              value: _step,
              onChanged: (v) => setState(() => _step = v),
            ),
            _section('Colour'),
            _colours(),
            _section('Type'),
            const Text('Display 36', style: PawText.display36),
            const Text('Title 30', style: PawText.title30),
            const Text('Title 28', style: PawText.title28),
            const Text('Heading 22', style: PawText.heading22),
            const SizedBox(height: 8),
            const Text('Button 16 / 15 bold', style: PawText.button16),
            const Text(
              'Body 15 and 14, medium to semibold',
              style: PawText.body15,
            ),
            const Text('Meta 13 and 12 for captions', style: PawText.meta13),
            const Text('OVERLINE 12 BOLD', style: PawText.overline12),
            _section('Buttons'),
            PawButton(label: 'Primary', onPressed: () {}),
            const SizedBox(height: 12),
            PawButton(
              label: 'Secondary',
              variant: PawButtonVariant.secondary,
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            PawButton(
              label: 'Lost pet action',
              variant: PawButtonVariant.warm,
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            PawButton(
              label: 'Call emergency vet',
              variant: PawButtonVariant.danger,
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            const PawButton(label: 'Disabled', onPressed: null),
            const SizedBox(height: 12),
            PawButton(
              label: 'Save changes',
              loading: _loading,
              onPressed: () async {
                setState(() => _loading = true);
                await Future<void>.delayed(const Duration(seconds: 1));
                if (mounted) setState(() => _loading = false);
              },
            ),
            _section('Chips'),
            Row(
              children: [
                for (final s in ['Dog', 'Cat', 'Other']) ...[
                  PawChip(
                    label: s,
                    size: PawChipSize.large,
                    expand: true,
                    selected: _species == s,
                    onTap: () => setState(() => _species = s),
                  ),
                  if (s != 'Other') const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                PawChip(
                  label: 'Selected',
                  selected: _filter == 'Selected',
                  onTap: () => setState(() => _filter = 'Selected'),
                ),
                PawChip(
                  label: 'Default',
                  selected: _filter == 'Default',
                  onTap: () => setState(() => _filter = 'Default'),
                ),
              ],
            ),
            _section('Badges'),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PawBadge.verified('Vet verified'),
                PawBadge('Upcoming', tone: PawBadgeTone.upcoming),
                PawBadge('LOST', tone: PawBadgeTone.lost),
                PawBadge('Overdue', tone: PawBadgeTone.danger),
                PawBadge('Draft'),
              ],
            ),
            _section('Segmented control'),
            PawSegmented<String>(
              segments: const [
                PawSegment('Health', 'Health'),
                PawSegment('Origin', 'Origin'),
                PawSegment('Services', 'Services'),
              ],
              value: _segment,
              onChanged: (v) => setState(() => _segment = v),
            ),
            _section('Inputs'),
            PawTextField(
              label: 'Pet\'s name',
              controller: _name,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            const PawTextField(
              label: 'Breed',
              hint: 'Choose a breed',
              suffix: PawIcon(
                PawIconData.chevronDown,
                size: 16,
                color: PawColors.muted,
                strokeWidth: 2.2,
              ),
            ),
            const SizedBox(height: 14),
            const PawTextField(
              label: 'Email',
              errorText: 'Enter an email like name@example.com',
            ),
            const SizedBox(height: 14),
            const PawTextField(
              label: 'Area',
              helperText: 'Used to find vets near you',
              enabled: false,
            ),
            const SizedBox(height: 14),
            PawToggleRow(
              label: 'Push notifications',
              value: _pushOn,
              onChanged: (v) => setState(() => _pushOn = v),
            ),
            const SizedBox(height: 10),
            PawToggleRow(
              label: 'WhatsApp reminders',
              subtitle: 'Sent the day before',
              value: _whatsappOn,
              onChanged: (v) => setState(() => _whatsappOn = v),
            ),
            _section('Card and list rows'),
            PawCard(
              onTap: () {},
              semanticLabel: 'Bingo, Boerboel, passport up to date',
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: PawColors.petTints[0],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: const Text('B', style: PawText.heading22),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bingo', style: PawText.heading22),
                        Text('Boerboel · 2 yrs · 41 kg', style: PawText.meta13),
                        SizedBox(height: 6),
                        PawBadge.verified('Passport up to date'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PawListRow(title: 'My bookings', onTap: () {}),
            PawListRow(
              title: 'Transfer a passport',
              subtitle: 'Hand over to a new owner',
              onTap: () {},
            ),
            PawListRow(
              title: 'Sign out',
              destructive: true,
              showDivider: false,
              onTap: () {},
            ),
            _section('Sticky footer'),
            ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(PawRadius.cardSmall),
              ),
              child: PawStickyFooter(
                axis: Axis.horizontal,
                children: [
                  PawButton(
                    label: 'Back',
                    variant: PawButtonVariant.secondary,
                    onPressed: () {},
                  ),
                  PawButton(label: 'Continue', onPressed: () {}),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The tab bar is pinned to the bottom of this screen.',
              style: PawText.meta13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Semantics(
      header: true,
      child: Text(title.toUpperCase(), style: PawText.overline12),
    ),
  );

  Widget _colours() {
    const swatches = <(String, Color)>[
      ('primary', PawColors.primary),
      ('primarySoft', PawColors.primarySoft),
      ('warm', PawColors.warm),
      ('warmSoft', PawColors.warmSoft),
      ('danger', PawColors.danger),
      ('dangerSoft', PawColors.dangerSoft),
      ('dot (decor only)', PawColors.dot),
      ('ground', PawColors.ground),
      ('surface', PawColors.surface),
      ('ink', PawColors.ink),
      ('ink2', PawColors.ink2),
      ('muted', PawColors.muted),
      ('border', PawColors.border),
      ('subtle', PawColors.subtle),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (name, color) in swatches)
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PawColors.border),
                  ),
                ),
                const SizedBox(height: 4),
                Text(name, style: PawText.meta12),
              ],
            ),
          ),
        for (var i = 0; i < PawColors.petTints.length; i++)
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: PawColors.petTints[i],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 4),
                Text('petTint ${i + 1}', style: PawText.meta12),
              ],
            ),
          ),
      ],
    );
  }
}
