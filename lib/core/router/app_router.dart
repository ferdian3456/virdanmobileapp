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
import '../../features/explore/presentation/explore_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/onboarding/presentation/onboarding_server_choice_page.dart';
import '../../features/post/presentation/create_post_page.dart';
import '../../features/post/presentation/home_page.dart';
import '../../features/profile/presentation/your_profile_page.dart';
import '../../features/server/data/server_repository.dart';
import '../../features/server/presentation/create_server_page.dart';
import '../../shared/layouts/main_layout.dart';
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
        final serversState = ref.read(myServersProvider);
        if (!serversState.isLoading && serversState.servers.isEmpty) {
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
      GoRoute(
        path: Routes.onboardingCreateServer,
        builder: (_, _) => const CreateServerPage(),
      ),

      // Phase 0 dev screen — keep accessible until Phase 6 cleanup.
      GoRoute(path: Routes.devSmoke, builder: (_, _) => const SmokeScreen()),

      // /app shell — bottom tab bar wraps all in-app pages. Sub-routes that
      // should NOT show the bottom nav (e.g., compose, create-server) live
      // outside this shell.
      ShellRoute(
        builder: (_, _, child) => MainLayout(child: child),
        routes: [
          GoRoute(path: Routes.appHome, builder: (_, _) => const HomePage()),
          GoRoute(path: Routes.appExplore, builder: (_, _) => const ExplorePage()),
          GoRoute(path: Routes.appCreate, builder: (_, _) => const CreatePostPage()),
          GoRoute(
            path: Routes.appNotifications,
            builder: (_, _) => const NotificationsPage(),
          ),
          GoRoute(path: Routes.appProfile, builder: (_, _) => const YourProfilePage()),
        ],
      ),

      // Modal-style routes (full screen, no bottom nav).
      GoRoute(
        path: Routes.appCreateServer,
        builder: (_, _) => const CreateServerPage(),
      ),
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
