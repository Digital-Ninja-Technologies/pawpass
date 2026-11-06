import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../adopt/domain/adopt_logic.dart';
import '../../booking/domain/booking_logic.dart' show nairaFromKobo;
import '../../booking/ui/booking_widgets.dart';
import '../../health/ui/health_widgets.dart';
import '../../onboarding/domain/models.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/models.dart';
import 'partner_widgets.dart';

/// Me (design/screens/Profile.dc.html): who you are, your pets, the account links, and partner mode.
class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scope.partner.loadApplication();
      });
    }
    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.session,
        scope.partner,
        scope.health,
      ]),
      builder: (context, _) {
        final p = scope.session.profile;
        final name = [
          p?.firstName,
          p?.lastName,
        ].where((s) => s != null && s.trim().isNotEmpty).join(' ');
        final email = scope.services.auth.email ?? '';
        final line = [
          if (p?.area != null && p!.area!.isNotEmpty) p.area!,
          if (email.isNotEmpty) email,
        ].join(' · ');
        final pets = scope.health.pets;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                PawSpace.screenSide,
                12,
                PawSpace.screenSide,
                28,
              ),
              children: [
                const BookingHeader('Me'),
                const SizedBox(height: 16),
                PawCard(
                  radius: PawRadius.cardSmall,
                  child: Row(
                    children: [
                      LetterMark(name.isEmpty ? '?' : name, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Your account' : name,
                              style: PawText.body15Strong,
                            ),
                            if (line.isNotEmpty)
                              Text(
                                line,
                                style: PawText.meta13.copyWith(
                                  color: PawColors.muted,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/me/edit'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(PawSize.touch, PawSize.touch),
                        ),
                        child: Text(
                          'Edit',
                          style: PawText.body14Strong.copyWith(
                            color: PawColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionLabel('My pets'),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final pet in pets)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _PetChip(
                            pet: pet,
                            onTap: () async {
                              await scope.health.select(pet.id);
                              if (context.mounted) {
                                context.go('/passport');
                              }
                            },
                          ),
                        ),
                      _AddPetChip(
                        onTap: () {
                          scope.onboarding.startAnotherPet();
                          context.push('/add-pet');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PawListRow(
                  title: 'My bookings',
                  onTap: () => context.push('/bookings'),
                ),
                PawListRow(
                  title: 'Payments & escrow',
                  onTap: () => context.push('/orders'),
                ),
                PawListRow(
                  title: 'QR tags',
                  onTap: () => context.push('/soon/QR tags'),
                ),
                PawListRow(
                  title: 'Notifications & reminders',
                  onTap: () => context.push('/notifications'),
                ),
                PawListRow(
                  title: 'Privacy & sharing',
                  onTap: () => context.push('/soon/Privacy & sharing'),
                ),
                PawListRow(
                  title: 'Help & support',
                  onTap: () => context.push('/help'),
                  showDivider: false,
                ),
                const SizedBox(height: 18),
                _PartnerCard(
                  error: scope.partner.applicationLoaded
                      ? null
                      : scope.partner.applicationError,
                  onRetry: scope.partner.loadApplication,
                  application: scope.partner.application,
                  loading:
                      !scope.partner.applicationLoaded &&
                      scope.partner.loadingApplication,
                  onBecome: () => context.push('/partner/become'),
                  onContinue: () => context.push('/partner/kyc'),
                  onStatus: () => context.push('/partner/review'),
                  onOpen: () {
                    scope.partner.enterPartnerMode();
                    context.go('/partner');
                  },
                ),
                const SizedBox(height: 12),
                PawListRow(
                  title: 'Log out',
                  destructive: true,
                  showDivider: false,
                  onTap: () => scope.session.signOut(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PetChip extends StatelessWidget {
  const _PetChip({required this.pet, required this.onTap});
  final Pet pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${pet.name}, open passport',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64),
          child: Column(
            children: [
              PetAvatar(pet: pet, size: 56),
              const SizedBox(height: 6),
              Text(pet.name, style: PawText.meta13, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPetChip extends StatelessWidget {
  const _AddPetChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add pet',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: PawColors.outline, width: 2),
                ),
                child: const Center(
                  child: PawIcon(PawIconData.plus, color: PawColors.muted),
                ),
              ),
              const SizedBox(height: 6),
              Text('Add pet', style: PawText.meta13),
            ],
          ),
        ),
      ),
    );
  }
}

/// The partner entry on the Me screen: it changes with where the application stands.
class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.error,
    required this.onRetry,
    required this.application,
    required this.loading,
    required this.onBecome,
    required this.onContinue,
    required this.onStatus,
    required this.onOpen,
  });

  final String? error;
  final VoidCallback onRetry;
  final PartnerApplication? application;
  final bool loading;
  final VoidCallback onBecome;
  final VoidCallback onContinue;
  final VoidCallback onStatus;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final a = application;
    final String title;
    final String body;
    final VoidCallback onTap;
    String? tag;
    if (error != null && a == null) {
      // Do not offer "Become a partner" to someone who may already be one: say we could not check.
      title = 'We could not check your partner status';
      body = '$error Tap to try again.';
      onTap = onRetry;
    } else if (a == null) {
      title = 'Become a partner';
      body = 'Offer services, list litters or rehome pets';
      onTap = onBecome;
    } else {
      switch (a.status) {
        case PartnerStatus.approved:
          title = a.businessName;
          body = 'Open your partner dashboard';
          onTap = onOpen;
          tag = 'Verified';
        case PartnerStatus.draft:
          title = 'Finish verifying ${a.businessName}';
          body = '${a.stepsDone} of ${a.stepsTotal} steps done';
          onTap = onContinue;
        case PartnerStatus.needsInfo:
          title = 'One thing needed';
          body = a.decisionNote ?? 'Open your application';
          onTap = onStatus;
          tag = 'Action needed';
        case PartnerStatus.submitted:
          title = 'Verification in review';
          body = 'We decide within 48 hours';
          onTap = onStatus;
          tag = 'In review';
        case PartnerStatus.rejected:
          title = 'Application not approved';
          body = 'See why, and try again';
          onTap = onStatus;
        case PartnerStatus.suspended:
          title = 'Partner account paused';
          body = 'Contact support to find out why';
          onTap = onStatus;
      }
    }
    return PawCard(
      color: PawColors.primarySoft,
      radius: PawRadius.cardSmall,
      onTap: loading ? null : onTap,
      semanticLabel: '$title. $body',
      child: Row(
        children: [
          const PawIcon(PawIconData.briefcase, color: PawColors.primaryText),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PawText.body15Strong.copyWith(
                    color: PawColors.primaryText,
                  ),
                ),
                Text(
                  body,
                  style: PawText.meta13.copyWith(color: PawColors.primaryText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 8),
            StatusTag(tag, highlight: true),
          ],
          const SizedBox(width: 4),
          const PawIcon(
            PawIconData.chevronRight,
            size: 20,
            color: PawColors.primaryText,
          ),
        ],
      ),
    );
  }
}

/// Edit name, area and phone.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _area;
  late final TextEditingController _phone;
  var _saving = false;
  String? _error;
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) {
      return;
    }
    _ready = true;
    final p = AppScope.of(context).session.profile;
    _first = TextEditingController(text: p?.firstName ?? '');
    _last = TextEditingController(text: p?.lastName ?? '');
    _area = TextEditingController(text: p?.area ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _area.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final scope = AppScope.of(context);
    if (_first.text.trim().isEmpty) {
      setState(() => _error = 'Enter your first name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await scope.services.profiles.save(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        area: _area.text.trim(),
        phone: _phone.text.trim(),
      );
      // Go back first: refreshing the session makes the router re-check the page it is on.
      if (mounted) {
        context.pop();
      }
      await scope.session.refreshProfile();
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const BookingHeader('Edit your details'),
                  const SizedBox(height: 20),
                  PawTextField(
                    label: 'First name',
                    controller: _first,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.givenName],
                  ),
                  const SizedBox(height: 16),
                  PawTextField(
                    label: 'Last name',
                    controller: _last,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.familyName],
                  ),
                  const SizedBox(height: 16),
                  PawTextField(
                    label: 'Area',
                    controller: _area,
                    hint: 'For example, Lekki Phase 1',
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  PawTextField(
                    label: 'Phone (optional)',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: PawText.body14.copyWith(color: PawColors.danger),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PawStickyFooter(
              children: [
                PawButton(label: 'Save', loading: _saving, onPressed: _save),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Payments & escrow: every puppy order, newest first.
class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).adopt;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => c.load());
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final orders = c.orders;
        return Scaffold(
          backgroundColor: PawColors.ground,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: c.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  PawSpace.screenSide,
                  12,
                  PawSpace.screenSide,
                  24,
                ),
                children: [
                  const BookingHeader('Payments & escrow'),
                  const SizedBox(height: 16),
                  if (!c.loaded && c.loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!c.loaded && c.error != null)
                    SizedBox(
                      height: 260,
                      child: LoadError(message: c.error!, onRetry: c.load),
                    )
                  else if (orders.isEmpty)
                    const EmptyNote(
                      'No puppy orders yet. When you pay a deposit into escrow, it shows here.',
                    )
                  else
                    for (final o in orders)
                      DashRow(
                        leading: LetterMark(o.petName),
                        title: '${o.petName} · ${o.partnerName}',
                        subtitle:
                            '${orderStatusBadge(o.status)} · ${nairaFromKobo(o.priceKobo)}',
                        trailing: const PawIcon(
                          PawIconData.chevronRight,
                          size: 18,
                          color: PawColors.muted,
                        ),
                        onTap: () => context.push('/orders/${o.id}'),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Screens that are referenced by the designs but not designed yet (QR tags, privacy).
class SoonScreen extends StatelessWidget {
  const SoonScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawColors.ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PawSpace.screenSide),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BookingHeader(title),
              const Spacer(),
              Text(
                'This part is coming soon',
                textAlign: TextAlign.center,
                style: PawText.title28,
              ),
              const SizedBox(height: 8),
              Text(
                'We are still designing it. Write to Help & support if you need something sooner.',
                textAlign: TextAlign.center,
                style: PawText.body15.copyWith(color: PawColors.muted),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
