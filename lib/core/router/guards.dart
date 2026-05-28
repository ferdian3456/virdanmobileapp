import 'package:go_router/go_router.dart';

import 'routes.dart';

/// Returns the redirect path, or null to allow current navigation.
///
/// Auth + server state wiring filled in Phase 1+. Phase 0 stub: always allow.
String? appRedirect(GoRouterState state, {bool isAuthenticated = false, bool hasServer = false}) {
  final matched = state.matchedLocation;
  final isGuestRoute = matched.startsWith('/auth');
  final isProtectedApp = matched.startsWith('/app');
  final isOnboarding = matched.startsWith('/onboarding');

  if (!isAuthenticated && (isProtectedApp || isOnboarding)) {
    return Routes.authLogin;
  }

  if (isAuthenticated && isGuestRoute) {
    return hasServer ? Routes.appHome : Routes.onboardingServerChoice;
  }

  if (isAuthenticated && isProtectedApp && !hasServer) {
    return Routes.onboardingServerChoice;
  }

  return null;
}
