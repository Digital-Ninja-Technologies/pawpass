import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'gallery/component_gallery_screen.dart';
import 'ui/ui.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('PawPass', style: PawText.title30),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  PawButton(
                    label: 'Component gallery',
                    expand: false,
                    onPressed: () => context.go('/gallery'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/gallery',
      builder: (context, state) => const ComponentGalleryScreen(),
    ),
  ],
);

class PawPassApp extends StatelessWidget {
  const PawPassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PawPass',
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
