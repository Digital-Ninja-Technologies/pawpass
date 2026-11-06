import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';

/// The owner's five tab frame: the current tab above, the tab bar below.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PawColors.ground,
      body: shell,
      bottomNavigationBar: PawTabBar(
        active: PawTab.values[shell.currentIndex],
        onSelected: (tab) => shell.goBranch(
          tab.index,
          // Tapping the tab you are on goes back to its first screen.
          initialLocation: tab.index == shell.currentIndex,
        ),
      ),
    );
  }
}

/// What the Book, Community and Adopt tabs show until their milestones are built.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    this.showBack = false,
  });

  final String title;
  final String body;
  final PawIconData icon;
  final bool showBack;

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
              if (showBack)
                Align(
                  alignment: Alignment.centerLeft,
                  child: const PawBackButton(),
                )
              else
                const SizedBox(height: 44),
              const Spacer(),
              ExcludeSemantics(
                child: Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: PawColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: PawIcon(icon, size: 34, color: PawColors.primaryText),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: PawText.title28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: PawText.body15.copyWith(
                  color: PawColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: PawBadge('Coming soon', tone: PawBadgeTone.upcoming),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
