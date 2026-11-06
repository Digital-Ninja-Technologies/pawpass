import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'paw_icon.dart';

enum PawTab {
  home('Home', PawIconData.home),
  passport('Passport', PawIconData.passport),
  book('Book', PawIconData.calendar),
  community('Community', PawIconData.community),
  adopt('Adopt', PawIconData.paw);

  const PawTab(this.label, this.icon);
  final String label;
  final PawIconData icon;
}

/// Owner bottom tab bar (design/screens/TabBar.dc.html): 80 tall, white,
/// 1px top border. The home indicator inset is added below the 80.
class PawTabBar extends StatelessWidget {
  const PawTabBar({super.key, required this.active, required this.onSelected});

  final PawTab active;
  final ValueChanged<PawTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Main',
      // Container (not DecoratedBox) so the 1px border adds to the height: 79 + 1 = 80.
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Equal shares of the width, so five tabs fit any phone.
                  for (final tab in PawTab.values)
                    Expanded(
                      child: _TabItem(
                        tab: tab,
                        selected: tab == active,
                        onTap: () => onSelected(tab),
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

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final PawTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PawColors.primary : PawColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: tab.label,
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
              PawIcon(tab.icon, color: color),
              const SizedBox(height: 4),
              // One line always: with large text the label shrinks a little instead of overflowing.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
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
