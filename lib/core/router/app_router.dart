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
import '../../features/chat/presentation/chat_page.dart';
import '../../features/explore/presentation/explore_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/onboarding/presentation/onboarding_server_choice_page.dart';
import '../../features/post/presentation/comments_page.dart';
import '../../features/post/presentation/create_post_page.dart';
import '../../features/post/presentation/home_page.dart';
import '../../features/post/presentation/post_detail_page.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/your_profile_page.dart';
import '../../features/server/data/server_repository.dart';
import '../../features/server/presentation/create_server_page.dart';
import '../../features/server/presentation/edit_server_settings_page.dart';
import '../../features/server/presentation/join_by_invite_page.dart';
import '../../features/server/presentation/server_detail_page.dart';
import '../../features/settings/presentation/change_email_page.dart';
import '../../features/settings/presentation/change_password_page.dart';
import '../../features/settings/presentation/help_center_page.dart';
import '../../features/settings/presentation/notification_settings_page.dart';
import '../../features/settings/presentation/privacy_security_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/static_pages.dart';
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
      final isStandaloneProtected = matched.startsWith('/server') ||
          matched.startsWith('/posts') ||
          matched.startsWith('/profile/') ||
          matched.startsWith('/settings') ||
          matched.startsWith('/chat') ||
          matched.startsWith('/join');

      if (!isAuthed &&
          (isProtectedApp || isOnboarding || isStandaloneProtected)) {
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

      // Dev surface — keep until Phase 6 cleanup.
      GoRoute(path: Routes.devSmoke, builder: (_, _) => const SmokeScreen()),

      // Bottom-tab shell.
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

      // Standalone protected pages (no bottom nav).
      GoRoute(path: Routes.appCreateServer, builder: (_, _) => const CreateServerPage()),
      GoRoute(path: Routes.appJoin, builder: (_, _) => const JoinByInvitePage()),
      GoRoute(path: Routes.appChat, builder: (_, _) => const ChatPage()),
      GoRoute(path: Routes.appEditProfile, builder: (_, _) => const EditProfilePage()),

      GoRoute(
        path: '/server/:id',
        builder: (_, state) => ServerDetailPage(serverId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/server/:id/settings',
        builder: (_, state) =>
            EditServerSettingsPage(serverId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/posts/:id',
        builder: (_, state) => PostDetailPage(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/posts/:id/comments',
        builder: (_, state) => CommentsPage(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (_, state) => ProfilePage(userId: state.pathParameters['userId']!),
      ),

      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsPage()),
      GoRoute(path: Routes.settingsEmail, builder: (_, _) => const ChangeEmailPage()),
      GoRoute(path: Routes.settingsPassword, builder: (_, _) => const ChangePasswordPage()),
      GoRoute(
        path: Routes.settingsNotifications,
        builder: (_, _) => const NotificationSettingsPage(),
      ),
      GoRoute(path: Routes.settingsPrivacy, builder: (_, _) => const PrivacySecurityPage()),
      GoRoute(path: Routes.settingsHelp, builder: (_, _) => const HelpCenterPage()),
      GoRoute(path: Routes.settingsTerms, builder: (_, _) => const TermsOfServicePage()),
      GoRoute(
        path: Routes.settingsPrivacyPolicy,
        builder: (_, _) => const PrivacyPolicyPage(),
      ),
    ],
    errorBuilder: (_, state) => _NotFoundPage(uri: state.uri.toString()),
  );
});

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
