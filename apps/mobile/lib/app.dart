import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('PawPass'))),
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
