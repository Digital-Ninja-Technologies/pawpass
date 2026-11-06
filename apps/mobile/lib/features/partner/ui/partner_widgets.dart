import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../../onboarding/state/app_scope.dart';
import '../domain/models.dart';
import '../domain/partner_logic.dart';

/// The dark top block on every partner dashboard: overline, business name, "Owner mode", three numbers.
class PartnerHeader extends StatelessWidget {
  const PartnerHeader({
    super.key,
    required this.overline,
    required this.title,
    required this.stats,
    required this.onOwnerMode,
  });

  final String overline;
  final String title;
  final List<({String label, String value})> stats;
  final VoidCallback onOwnerMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: PawColors.ink,
      padding: EdgeInsets.fromLTRB(
        PawSpace.screenSide,
        MediaQuery.paddingOf(context).top + 16,
        PawSpace.screenSide,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overline,
                      style: PawText.overline12.copyWith(
                        color: const Color(0xFFCFE6E1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PawText.heading22.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Switch to owner mode',
                excludeSemantics: true,
                onTap: onOwnerMode,
                child: GestureDetector(
                  onTap: onOwnerMode,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: PawSize.touch),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Owner mode',
                      style: PawText.meta12.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _StatTile(stats[i].label, stats[i].value)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PawText.meta12.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: PawText.heading22.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The partner bottom bar. The labels depend on the kind of partner.
class PartnerTabBar extends StatelessWidget {
  const PartnerTabBar({
    super.key,
    required this.type,
    required this.index,
    required this.onSelected,
  });

  final PartnerType type;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = tabsFor(type);
    final items = <(String, PawIconData)>[
      ('Today', PawIconData.grid),
      (t.second, type.takesBookings ? PawIconData.calendar : PawIconData.tag),
      ('Messages', PawIconData.messages),
      (
        t.fourth,
        type == PartnerType.shelter
            ? PawIconData.paperclip
            : PawIconData.wallet,
      ),
      ('Business', PawIconData.briefcase),
    ];
    return Semantics(
      container: true,
      label: 'Partner',
      child: Container(
        decoration: const BoxDecoration(
          color: PawColors.surface,
          border: Border(top: BorderSide(color: PawColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: PawSize.tabBar - 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _PartnerTab(
                        label: items[i].$1,
                        icon: items[i].$2,
                        selected: i == index,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PartnerTab extends StatelessWidget {
  const _PartnerTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final PawIconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PawColors.primary : PawColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: PawSize.touch,
            minHeight: PawSize.touch,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PawIcon(icon, color: color),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: PawText.tab11.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small status tag with the words always shown.
class StatusTag extends StatelessWidget {
  const StatusTag(this.label, {super.key, this.highlight = false});
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: highlight ? PawColors.primarySoft : PawColors.subtle,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: PawText.meta12.copyWith(
        fontWeight: FontWeight.w700,
        color: highlight ? PawColors.primaryText : PawColors.muted,
      ),
    ),
  );
}

/// A card-like row used across the dashboards.
class DashRow extends StatelessWidget {
  const DashRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.emphasis = false,
    this.semanticLabel,
    this.footer,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool emphasis;
  final String? semanticLabel;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: PawColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawRadius.cardSmall),
          side: BorderSide(
            color: emphasis ? PawColors.primary : PawColors.border,
            width: emphasis ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(PawRadius.cardSmall),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: PawText.body14Strong),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: PawText.meta12.copyWith(
                                color: PawColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
                if (footer != null) ...[const SizedBox(height: 10), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A heading with a small action on the right ("Your listings" and "+ New listing").
class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.trailingText,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: PawText.body15Strong),
            ),
          ),
          if (trailingText != null)
            Text(
              trailingText!,
              style: PawText.meta13.copyWith(color: PawColors.muted),
            ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(PawSize.touch, PawSize.touch),
                foregroundColor: PawColors.primary,
              ),
              child: Text(
                action!,
                style: PawText.body14Strong.copyWith(color: PawColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// A round letter mark (an enquirer, an applicant).
class LetterMark extends StatelessWidget {
  const LetterMark(this.name, {super.key, this.size = 44});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint =
        PawColors.petTints[name.codeUnits.fold<int>(0, (a, b) => a + b) %
            PawColors.petTints.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: PawText.button15.copyWith(color: PawColors.warmText),
        ),
      ),
    );
  }
}

/// An empty state with a sentence and, optionally, one action.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: PawText.body14.copyWith(color: PawColors.muted),
    ),
  );
}

/// On Home, for an approved partner: a slim bar that opens the partner dashboard.
class PartnerBar extends StatefulWidget {
  const PartnerBar({super.key});

  @override
  State<PartnerBar> createState() => _PartnerBarState();
}

class _PartnerBarState extends State<PartnerBar> {
  var _started = false;

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).partner;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!p.applicationLoaded) {
          p.loadApplication();
        }
      });
    }
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final a = p.application;
        if (a == null || !a.approved) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            PawSpace.screenSide,
            0,
            PawSpace.screenSide,
            14,
          ),
          child: PawCard(
            color: PawColors.ink,
            radius: PawRadius.cardSmall,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            semanticLabel:
                'Partner mode. ${a.businessName}. Open your dashboard',
            onTap: () {
              p.enterPartnerMode();
              context.go('/partner');
            },
            child: Row(
              children: [
                const PawIcon(
                  PawIconData.briefcase,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PARTNER MODE',
                        style: PawText.overline12.copyWith(
                          color: const Color(0xFFCFE6E1),
                        ),
                      ),
                      Text(
                        a.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PawText.body14Strong.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Open',
                  style: PawText.body14Strong.copyWith(color: Colors.white),
                ),
                const SizedBox(width: 4),
                const PawIcon(
                  PawIconData.chevronRight,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
