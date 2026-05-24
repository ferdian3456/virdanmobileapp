import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/smoke_screen.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.devSmoke,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: Routes.root,
        redirect: (_, _) => Routes.devSmoke,
      ),
      GoRoute(
        path: Routes.devSmoke,
        builder: (_, _) => const SmokeScreen(),
      ),
    ],
    errorBuilder: (_, state) => _NotFoundPage(uri: state.uri.toString()),
  );
});

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Route tidak ada: $uri',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
