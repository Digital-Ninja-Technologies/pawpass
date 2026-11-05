import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/ui.dart';
import '../onboarding/domain/models.dart';
import '../onboarding/state/app_scope.dart';

/// A stand in until the Home screen is built (milestone 2). It shows who is signed in and their pets
/// so the end of onboarding has somewhere real to land.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Pet>>? _pets;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pets ??= AppScope.of(context).services.pets.myPets();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.session,
      builder: (context, _) {
        final name = scope.session.profile?.firstName ?? '';
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(PawSpace.screenSide),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    name.isEmpty ? 'Welcome to PawPass' : 'Hi $name',
                    style: PawText.title30,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your home screen is coming next. For now, here are your pets.',
                  style: PawText.body15.copyWith(color: PawColors.muted),
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<Pet>>(
                  future: _pets,
                  builder: (context, snap) {
                    final pets = snap.data ?? const <Pet>[];
                    return Column(
                      children: [
                        for (final p in pets)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PawCard(
                              child: Row(
                                children: [
                                  const PawIcon(PawIconData.paw),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: PawText.heading22),
                                        if (p.tagCode != null)
                                          Text(
                                            'Tag ID ${p.tagCode}',
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
                  },
                ),
                const SizedBox(height: 10),
                PawButton(
                  label: 'Add a pet',
                  variant: PawButtonVariant.secondary,
                  onPressed: () {
                    scope.onboarding.startAnotherPet();
                    context.go('/add-pet');
                  },
                ),
                const SizedBox(height: 10),
                PawButton(
                  label: 'Sign out',
                  variant: PawButtonVariant.secondary,
                  onPressed: scope.session.signOut,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 10),
                  PawButton(
                    label: 'Component gallery',
                    variant: PawButtonVariant.secondary,
                    onPressed: () => context.go('/gallery'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
