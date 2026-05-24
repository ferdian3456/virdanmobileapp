import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/smoke_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/verify_otp_page.dart';
import '../../features/auth/presentation/verify_password_page.dart';
import '../../features/onboarding/presentation/onboarding_server_choice_page.dart';
import '../../features/server/data/server_repository.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: Routes.authLogin,
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authAsync = ref.read(authRepositoryProvider);
      if (authAsync.isLoading || !authAsync.hasValue) return null;

      final isAuthed = authAsync.requireValue is AuthAuthenticated;
      final matched = state.matchedLocation;
      final isGuestRoute = matched.startsWith('/auth');
      final isProtectedApp = matched.startsWith('/app');
      final isOnboarding = matched.startsWith('/onboarding');
      final isDevRoute = matched.startsWith('/dev');

      if (!isAuthed && (isProtectedApp || isOnboarding)) {
        return Routes.authLogin;
      }
      if (isAuthed && isGuestRoute) {
        // Lazy-fetch servers post-login. The provider hydrates on auth flip
        // already; this is a defensive nudge for cold path.
        final serversState = ref.read(myServersProvider);
        if (!serversState.isLoading && serversState.servers.isEmpty) {
          // Kick off fetch; redirect will run again once it lands.
          Future.microtask(() => ref.read(myServersProvider.notifier).fetch());
        }
        return serversState.hasServers
            ? Routes.appHome
            : Routes.onboardingServerChoice;
      }
      if (isAuthed && isProtectedApp && !isDevRoute) {
        final serversState = ref.read(myServersProvider);
        if (!serversState.hasServers && !serversState.isLoading) {
          return Routes.onboardingServerChoice;
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.root, redirect: (_, _) => Routes.authLogin),
      GoRoute(path: Routes.authLogin, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.authRegister, builder: (_, _) => const RegisterPage()),
      GoRoute(path: Routes.authVerifyOtp, builder: (_, _) => const VerifyOtpPage()),
      GoRoute(path: Routes.authVerifyPassword, builder: (_, _) => const VerifyPasswordPage()),
      GoRoute(
        path: Routes.onboardingServerChoice,
        builder: (_, _) => const OnboardingServerChoicePage(),
      ),

      // Phase 0 dev screen — keep accessible until Phase 6 cleanup.
      GoRoute(path: Routes.devSmoke, builder: (_, _) => const SmokeScreen()),

      // Placeholder for /app/home — full HomePage lands in Phase 4. For now we
      // redirect there so authenticated users have a landing target.
      GoRoute(path: Routes.appHome, builder: (_, _) => const _AppHomeStub()),
    ],
    errorBuilder: (_, state) => _NotFoundPage(uri: state.uri.toString()),
  );
});

/// Bridges Riverpod state changes into a Listenable so go_router refreshes
/// its redirect chain when auth or server state flips.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _authSub = _ref.listen<AsyncValue<AuthState>>(
      authRepositoryProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
    _serversSub = _ref.listen<MyServersState>(
      myServersProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }

  final Ref _ref;
  late final ProviderSubscription _authSub;
  late final ProviderSubscription _serversSub;

  @override
  void dispose() {
    _authSub.close();
    _serversSub.close();
    super.dispose();
  }
}

class _AppHomeStub extends ConsumerWidget {
  const _AppHomeStub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = switch (ref.watch(authRepositoryProvider)) {
      AsyncData(value: AuthAuthenticated(:final user)) => user.email,
      _ => '(loading)',
    };
    final servers = ref.watch(myServersProvider).servers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home (Phase 4 TODO)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authRepositoryProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Hi $email\n\nServers joined: ${servers.length}\nHomePage lands in Phase 4.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Route not found: $uri',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
