import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../domain/models.dart';
import '../state/app_scope.dart';
import 'onboarding_page.dart';

class AccountTypeScreen extends StatelessWidget {
  const AccountTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ob = AppScope.of(context).onboarding;
    return ListenableBuilder(
      listenable: ob,
      builder: (context, _) => OnboardingPage(
        step: 3,
        title: 'How will you use OurPawPass?',
        subtitle: 'Pick all that apply. You can add more later.',
        error: ob.error,
        gap: 20,
        form: [
          Semantics(
            container: true,
            label: 'Account types',
            child: Column(
              children: [
                for (final t in AccountType.values) ...[
                  if (t != AccountType.values.first) const SizedBox(height: 10),
                  _TypeRow(
                    type: t,
                    selected: ob.accountTypes.contains(t),
                    onTap: () => ob.toggleAccountType(t),
                  ),
                ],
              ],
            ),
          ),
          Text(
            'Providers, breeders and shelters complete a quick ID check before going live.',
            style: PawText.meta12.copyWith(color: PawColors.muted, height: 1.5),
          ),
        ],
        footer: [
          PawButton(
            label: 'Continue',
            loading: ob.busy,
            onPressed: ob.accountTypes.isEmpty
                ? null
                : () async {
                    final ok = await ob.saveAccountTypes();
                    if (ok && context.mounted) context.push('/profile');
                  },
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final AccountType type;
  final bool selected;
  final VoidCallback onTap;

  (Color bg, Color fg, PawIconData icon) get _look => switch (type) {
    AccountType.owner => (
      const Color(0xFFF3D9C4),
      PawColors.warmText,
      PawIconData.paw,
    ),
    AccountType.provider => (
      PawColors.primarySoft,
      PawColors.primaryText,
      PawIconData.vet,
    ),
    AccountType.breeder => (
      const Color(0xFFDCE7F7),
      const Color(0xFF23407A),
      PawIconData.shieldCheck,
    ),
    AccountType.shelter => (
      const Color(0xFFF1E8FB),
      const Color(0xFF5A2E8C),
      PawIconData.shelter,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _look;
    final radius = BorderRadius.circular(20);
    return Semantics(
      container: true,
      checked: selected,
      label: '${type.title}, ${type.subtitle}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: PawColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? const BorderSide(color: PawColors.primary, width: 2)
              : const BorderSide(color: PawColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: PawIcon(icon, color: fg)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.title, style: PawText.button16),
                      const SizedBox(height: 2),
                      Text(
                        type.subtitle,
                        style: PawText.meta13.copyWith(color: PawColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: ExcludeSemantics(
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => onTap(),
                      activeColor: PawColors.primary,
                      checkColor: Colors.white,
                      side: const BorderSide(
                        color: PawColors.outline,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
