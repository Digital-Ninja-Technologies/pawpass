import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dates.dart';
import '../../../ui/ui.dart';
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../../onboarding/ui/onboarding_page.dart'
    show PickerField, PhotoPickerButton, choosePhoto;
import '../domain/models.dart';
import '../domain/partner_logic.dart';
import 'partner_widgets.dart';

/// Become a partner (design/screens/BecomePartner.dc.html): pick the kind, see what happens next.
class BecomePartnerScreen extends StatefulWidget {
  const BecomePartnerScreen({super.key});

  @override
  State<BecomePartnerScreen> createState() => _BecomePartnerScreenState();
}

class _BecomePartnerScreenState extends State<BecomePartnerScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        p.chosenType ??= p.application?.type ?? PartnerType.vet;
        p.chooseType(p.chosenType!);
      });
    }
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final chosen = p.chosenType ?? PartnerType.vet;
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
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: PawBackButton(),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text('Become a partner', style: PawText.title30),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reach pet owners across Lagos. Your owner account stays the same; you switch between the two any time.',
                        style: PawText.body15.copyWith(color: PawColors.muted),
                      ),
                      const SizedBox(height: 22),
                      const SectionLabel('What kind of partner are you?'),
                      const SizedBox(height: 10),
                      for (final t in PartnerType.values)
                        ChoiceRow(
                          title: t.label,
                          subtitle: t.blurb,
                          selected: chosen == t,
                          onTap: () => p.chooseType(t),
                        ),
                      const SizedBox(height: 18),
                      for (final line in const [
                        '1. Verify your business (about 10 minutes)',
                        '2. We review it within 48 hours',
                        '3. Your dashboard unlocks and you go live',
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            line,
                            style: PawText.body14.copyWith(
                              color: PawColors.ink2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PawStickyFooter(
                  children: [
                    PawButton(
                      label: 'Continue to verification',
                      onPressed: () => context.push('/partner/details'),
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

/// Step 1: the business name and area. Also how the kind is saved.
class BusinessDetailsScreen extends StatefulWidget {
  const BusinessDetailsScreen({super.key});

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _area;
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) {
      return;
    }
    _ready = true;
    final scope = AppScope.of(context);
    final a = scope.partner.application;
    _name = TextEditingController(text: a?.businessName ?? '');
    _area = TextEditingController(
      text: (a?.area.isNotEmpty ?? false)
          ? a!.area
          : scope.session.profile?.area ?? '',
    );
    scope.partner.saveError = null;
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = AppScope.of(context).partner;
    final a = p.application;
    // Once an application is past "draft" the kind is fixed; a draft can still change it.
    final type = a != null && a.status != PartnerStatus.draft
        ? a.type
        : (p.chosenType ?? a?.type ?? PartnerType.vet);
    final cameFromKyc = _cameFromKyc;
    final ok = await p.saveBusiness(
      type: type,
      name: _name.text,
      area: _area.text,
    );
    if (!ok || !mounted) {
      return;
    }
    if (cameFromKyc) {
      context.pop();
    } else {
      context.pushReplacement('/partner/kyc');
    }
  }

  bool get _cameFromKyc =>
      GoRouterState.of(context).uri.queryParameters['from'] == 'kyc';

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
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
                    const BookingHeader('Business details'),
                    const SizedBox(height: 8),
                    Text(
                      '${(p.chosenType ?? p.application?.type ?? PartnerType.vet).label}. Owners see these on your page.',
                      style: PawText.body14.copyWith(color: PawColors.muted),
                    ),
                    const SizedBox(height: 20),
                    PawTextField(
                      label: 'Business name',
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      hint: 'For example, Paws & Claws Vet Clinic',
                    ),
                    const SizedBox(height: 16),
                    PawTextField(
                      label: 'Area',
                      controller: _area,
                      textCapitalization: TextCapitalization.words,
                      hint: 'For example, Lekki',
                    ),
                    if (p.saveError != null) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          p.saveError!,
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
                    label: 'Save and continue',
                    loading: p.saving,
                    onPressed: _save,
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

/// Verify your business (design/screens/KYC.dc.html): the checklist. When [embedded] it is the Business
/// tab of an approved partner, so it only shows the state.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        p.saveError = null;
        if (!p.applicationLoaded) {
          p.loadApplication();
        }
      });
    }
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final a = p.application;
        if (a == null) {
          return Scaffold(
            backgroundColor: PawColors.ground,
            body: SafeArea(
              child: p.loadingApplication
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(PawSpace.screenSide),
                      child: Column(
                        children: [
                          if (!widget.embedded)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: PawBackButton(),
                            ),
                          Expanded(
                            child: LoadError(
                              message: p.applicationError ?? 'You have not started verifying a business yet.',
                              onRetry: p.loadApplication,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        }
        final editable = a.status.editable;
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
                      if (widget.embedded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Semantics(
                            header: true,
                            child: Text('Business', style: PawText.title28),
                          ),
                        )
                      else
                        const BookingHeader('Verify your business'),
                      const SizedBox(height: 14),
                      Text(
                        a.approved
                            ? '${a.businessName} is verified. Owners see the badge on your page.'
                            : 'Verified partners get the badge owners look for. Reviews take up to 48 hours.',
                        style: PawText.body14.copyWith(color: PawColors.muted),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        label: '${a.stepsDone} of ${a.stepsTotal} steps done',
                        child: ExcludeSemantics(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: a.stepsTotal == 0
                                  ? 0
                                  : a.stepsDone / a.stepsTotal,
                              minHeight: 6,
                              backgroundColor: PawColors.border,
                              color: PawColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${a.stepsDone} of ${a.stepsTotal} done',
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < a.steps.length; i++)
                        _StepRow(
                          number: i + 1,
                          step: a.steps[i],
                          title: stepTitle(a.steps[i].key),
                          detail: stepDetail(a, a.steps[i]),
                          enabled: editable,
                          onTap: () => _open(context, a.steps[i].key),
                        ),
                      if (!editable && !a.approved) ...[
                        const SizedBox(height: 8),
                        InfoCard(
                          title: statusHeadline(a),
                          body: 'You can follow it on the status screen.',
                          icon: PawIconData.clock,
                        ),
                      ],
                      if (p.saveError != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            p.saveError!,
                            style: PawText.body14.copyWith(
                              color: PawColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (editable)
                  PawStickyFooter(
                    children: [
                      PawButton(
                        label: 'Submit for review',
                        loading: p.saving,
                        onPressed: a.canSubmit
                            ? () async {
                                final ok = await p.submit();
                                if (ok && context.mounted) {
                                  context.pushReplacement('/partner/review');
                                }
                              }
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.canSubmit
                            ? 'Everything is ready to send.'
                            : 'Finish all ${a.stepsTotal} steps to submit',
                        textAlign: TextAlign.center,
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                      ),
                    ],
                  )
                else if (!a.approved)
                  PawStickyFooter(
                    children: [
                      PawButton(
                        label: 'See your status',
                        onPressed: () => context.push('/partner/review'),
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

  void _open(BuildContext context, StepKey key) {
    switch (key) {
      case StepKey.business:
        context.push('/partner/details?from=kyc');
      case StepKey.ownerId:
        context.push('/partner/doc/owner_id');
      case StepKey.cac:
        context.push('/partner/doc/cac');
      case StepKey.licence:
        context.push('/partner/doc/licence');
      case StepKey.facilityPayout:
        context.push('/partner/facility');
    }
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.step,
    required this.title,
    required this.detail,
    required this.enabled,
    required this.onTap,
  });

  final int number;
  final VerifyStep step;
  final String title;
  final String detail;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = step.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: enabled,
        label: '$title. ${done ? 'Done' : 'Not done'}. $detail',
        excludeSemantics: true,
        onTap: enabled ? onTap : null,
        child: Material(
          color: PawColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PawRadius.cardSmall),
            side: const BorderSide(color: PawColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(PawRadius.cardSmall),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? PawColors.primary : PawColors.subtle,
                    ),
                    child: done
                        ? const PawIcon(
                            PawIconData.check,
                            size: 18,
                            color: Colors.white,
                          )
                        : Text(
                            '$number',
                            style: PawText.body14Strong.copyWith(
                              color: PawColors.muted,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: PawText.body15Strong),
                        Text(
                          detail,
                          style: PawText.meta13.copyWith(
                            color: PawColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: 8),
                    if (!done &&
                        (step.key == StepKey.ownerId ||
                            step.key == StepKey.cac ||
                            step.key == StepKey.licence))
                      const StatusTag('Upload', highlight: true)
                    else
                      const PawIcon(
                        PawIconData.chevronRight,
                        size: 20,
                        color: PawColors.muted,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single document: pick a photo, upload it.
class DocumentStepScreen extends StatefulWidget {
  const DocumentStepScreen({super.key, required this.kind});
  final DocumentKind kind;

  @override
  State<DocumentStepScreen> createState() => _DocumentStepScreenState();
}

class _DocumentStepScreenState extends State<DocumentStepScreen> {
  PickedPhoto? _photo;

  ({String title, String help}) get _copy => switch (widget.kind) {
    DocumentKind.ownerId => (
      title: 'Owner ID',
      help: 'A clear photo of your NIN slip, driver\'s licence or international passport. All four corners should show.',
    ),
    DocumentKind.cac => (
      title: 'CAC registration',
      help: 'A clear photo of your CAC certificate. The registration number must be readable.',
    ),
    DocumentKind.licence => (
      title: 'Vet practising licence',
      help: 'A clear photo of the licence from the Veterinary Council of Nigeria.',
    ),
    DocumentKind.facilityPhoto => (
      title: 'Facility photo',
      help: 'A photo of your clinic, kennel or shelter.',
    ),
  };

  Future<void> _pick() async {
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

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    final step = switch (widget.kind) {
      DocumentKind.ownerId => p.application?.step(StepKey.ownerId),
      DocumentKind.cac => p.application?.step(StepKey.cac),
      DocumentKind.licence => p.application?.step(StepKey.licence),
      DocumentKind.facilityPhoto => null,
    };
    final c = _copy;
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
                    BookingHeader(c.title),
                    const SizedBox(height: 14),
                    Text(
                      c.help,
                      style: PawText.body15.copyWith(color: PawColors.muted),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: PhotoPickerButton(
                        photo: _photo,
                        onTap: _pick,
                        size: 160,
                        label: _photo == null ? 'Add a photo' : null,
                        semanticLabel: _photo == null
                            ? 'Add a photo of your ${c.title}'
                            : 'Change the photo',
                      ),
                    ),
                    if (step?.done == true && _photo == null) ...[
                      const SizedBox(height: 16),
                      InfoCard(
                        title: 'Already uploaded',
                        body: 'Choose a new photo only if you want to replace it.',
                        icon: PawIconData.check,
                      ),
                    ],
                    if (p.saveError != null) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          p.saveError!,
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
                    label: 'Upload',
                    loading: p.saving,
                    onPressed: _photo == null
                        ? null
                        : () async {
                            final ok = await p.addDocument(
                              widget.kind,
                              _photo!,
                            );
                            if (ok && context.mounted) {
                              context.pop();
                            }
                          },
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

/// Step 5: three facility photos and where to pay the partner.
class FacilityPayoutScreen extends StatefulWidget {
  const FacilityPayoutScreen({super.key});

  @override
  State<FacilityPayoutScreen> createState() => _FacilityPayoutScreenState();
}

class _FacilityPayoutScreenState extends State<FacilityPayoutScreen> {
  final _number = TextEditingController();
  final _accountName = TextEditingController();
  Bank? _bank;
  var _editing = false;

  @override
  void dispose() {
    _number.dispose();
    _accountName.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final scope = AppScope.of(context);
    final r = await choosePhoto(
      context,
      fromCamera: scope.services.photos.fromCamera,
      fromGallery: scope.services.photos.fromGallery,
      hasPhoto: false,
    );
    final photo = r?.photo;
    if (photo != null) {
      await scope.partner.addDocument(DocumentKind.facilityPhoto, photo);
    }
  }

  Future<void> _pickBank() async {
    final bank = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PawColors.surface,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            for (final b in banks)
              ListTile(
                title: Text(b.name, style: PawText.body15),
                onTap: () => Navigator.pop(ctx, b),
              ),
          ],
        ),
      ),
    );
    if (bank != null && mounted) {
      setState(() => _bank = bank);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final a = p.application;
        final step = a?.step(StepKey.facilityPayout);
        final photos = step?.photos ?? 0;
        final payout = a?.payout;
        final showForm = payout == null || _editing;
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
                      const BookingHeader('Facility photos & payout'),
                      const SizedBox(height: 18),
                      const SectionLabel('Facility photos'),
                      const SizedBox(height: 8),
                      Text(
                        '$photos of 3 added. You can add up to 6.',
                        style: PawText.body14.copyWith(color: PawColors.muted),
                      ),
                      const SizedBox(height: 10),
                      PawButton(
                        label: photos >= 6
                            ? 'Photo limit reached'
                            : 'Add a photo',
                        variant: PawButtonVariant.secondary,
                        loading: p.saving,
                        onPressed: photos >= 6 ? null : _addPhoto,
                      ),
                      const SizedBox(height: 24),
                      const SectionLabel('Payout account'),
                      const SizedBox(height: 8),
                      if (!showForm) ...[
                        PawCard(
                          radius: PawRadius.cardSmall,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${payout.bankName} ending ${payout.last4}',
                                style: PawText.body15Strong,
                              ),
                              Text(
                                payout.accountName,
                                style: PawText.meta13.copyWith(
                                  color: PawColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        PawButton(
                          label: 'Change account',
                          variant: PawButtonVariant.secondary,
                          onPressed: () => setState(() => _editing = true),
                        ),
                      ] else ...[
                        Text(
                          'Owners pay PawPass. We send your money here every Monday after owners confirm their visits.',
                          style: PawText.body14.copyWith(
                            color: PawColors.muted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        PickerField(
                          label: 'Bank',
                          value: _bank?.name,
                          hint: 'Choose your bank',
                          onTap: _pickBank,
                        ),
                        const SizedBox(height: 14),
                        PawTextField(
                          label: 'Account number',
                          controller: _number,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          hint: '10 digits',
                        ),
                        const SizedBox(height: 14),
                        PawTextField(
                          label: 'Name on the account',
                          controller: _accountName,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 14),
                        PawButton(
                          label: 'Save account',
                          loading: p.saving,
                          onPressed: _bank == null
                              ? null
                              : () async {
                                  final ok = await p.savePayout(
                                    bank: _bank!,
                                    accountNumber: _number.text,
                                    accountName: _accountName.text,
                                  );
                                  if (ok && mounted) {
                                    setState(() => _editing = false);
                                  }
                                },
                        ),
                      ],
                      if (p.saveError != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            p.saveError!,
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
                    PawButton(label: 'Done', onPressed: () => context.pop()),
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

/// Verification status (design/screens/PartnerReview.dc.html): where the application is and what, if anything,
/// is needed from the partner.
class PartnerReviewScreen extends StatefulWidget {
  const PartnerReviewScreen({super.key});

  @override
  State<PartnerReviewScreen> createState() => _PartnerReviewScreenState();
}

class _PartnerReviewScreenState extends State<PartnerReviewScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.partner;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => p.loadApplication());
    }
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final a = p.application;
        if (a == null) {
          return Scaffold(
            backgroundColor: PawColors.ground,
            body: SafeArea(
              child: p.loadingApplication
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(PawSpace.screenSide),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: PawBackButton(),
                          ),
                        ),
                        Expanded(
                          child: LoadError(
                            message:
                                p.applicationError ?? 'No application yet.',
                            onRetry: p.loadApplication,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        }
        final submitted = a.submittedAt;
        final needs = a.status == PartnerStatus.needsInfo;
        final rejected = a.status == PartnerStatus.rejected;
        final approved = a.approved;
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
                      const BookingHeader('Verification status'),
                      const SizedBox(height: 18),
                      Semantics(
                        header: true,
                        child: Text(a.businessName, style: PawText.title28),
                      ),
                      Text(
                        '${a.type.shortLabel}${submitted == null ? '' : ' · submitted ${formatLongDate(submitted)}'}',
                        style: PawText.body14.copyWith(color: PawColors.muted),
                      ),
                      const SizedBox(height: 18),
                      if (needs || rejected)
                        Semantics(
                          liveRegion: true,
                          container: true,
                          child: PawCard(
                            color: needs
                                ? PawColors.warmSoft
                                : PawColors.dangerSoft,
                            radius: PawRadius.cardSmall,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  needs ? 'ONE THING NEEDED' : 'NOT APPROVED',
                                  style: PawText.overline12.copyWith(
                                    color: needs
                                        ? PawColors.warmText
                                        : PawColors.danger,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  needs
                                      ? (a.decisionNote ??
                                            'Open your application')
                                      : (a.decisionNote ??
                                            'The team could not approve this application.'),
                                  style: PawText.body15Strong,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PawPass team',
                                  style: PawText.meta13.copyWith(
                                    color: PawColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (needs || rejected) const SizedBox(height: 18),
                      _Timeline(
                        steps: [
                          (
                            title: 'Submitted',
                            sub: '${a.stepsTotal} items received',
                            state: _S.done,
                          ),
                          (
                            title: approved
                                ? 'Reviewed'
                                : rejected
                                ? 'Reviewed'
                                : needs
                                ? 'In review · waiting on you'
                                : 'In review',
                            sub: needs
                                ? 'Decision within 48 hours of your re-upload'
                                : 'Decision within 48 hours',
                            state: approved || rejected ? _S.done : _S.current,
                          ),
                          (
                            title: rejected
                                ? 'Not approved'
                                : 'Approved · badge and dashboard unlock',
                            sub: '',
                            state: approved ? _S.done : _S.todo,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        approved
                            ? 'You are live. Switch between owner and partner mode any time from Me.'
                            : "We'll notify you by push and email. You can keep using PawPass as an owner meanwhile.",
                        style: PawText.body14.copyWith(color: PawColors.muted),
                      ),
                    ],
                  ),
                ),
                PawStickyFooter(
                  children: [
                    if (needs)
                      PawButton(
                        label: 'Fix it and resubmit',
                        onPressed: () => context.push('/partner/kyc'),
                      )
                    else if (rejected)
                      PawButton(
                        label: 'Start again',
                        onPressed: () => context.push('/partner/become'),
                      )
                    else if (approved)
                      PawButton(
                        label: 'Open your dashboard',
                        onPressed: () {
                          p.enterPartnerMode();
                          context.go('/partner');
                        },
                      ),
                    PawButton(
                      label: 'Back to home',
                      variant: (needs || rejected || approved)
                          ? PawButtonVariant.secondary
                          : PawButtonVariant.primary,
                      onPressed: () {
                        p.leavePartnerMode();
                        context.go('/home');
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

enum _S { done, current, todo }

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});
  final List<({String title, String sub, _S state})> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Semantics(
            container: true,
            label:
                '${steps[i].title}. ${switch (steps[i].state) {
                  _S.done => 'Done',
                  _S.current => 'Now',
                  _S.todo => 'Next',
                }}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: steps[i].state == _S.done
                          ? PawColors.primary
                          : steps[i].state == _S.current
                          ? PawColors.warmSoft
                          : PawColors.subtle,
                      border: steps[i].state == _S.current
                          ? Border.all(color: PawColors.warm, width: 2)
                          : null,
                    ),
                    child: steps[i].state == _S.done
                        ? const PawIcon(
                            PawIconData.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: PawText.body15Strong.copyWith(
                            color: steps[i].state == _S.todo
                                ? PawColors.muted
                                : PawColors.ink,
                          ),
                        ),
                        if (steps[i].sub.isNotEmpty)
                          Text(
                            steps[i].sub,
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
          ),
      ],
    );
  }
}

// Used by the router.
DocumentKind? documentKindFor(String? v) => switch (v) {
  'owner_id' => DocumentKind.ownerId,
  'cac' => DocumentKind.cac,
  'licence' => DocumentKind.licence,
  _ => null,
};
