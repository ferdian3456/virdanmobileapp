import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/fcm_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/auth_state.dart';
import '../domain/session_tokens.dart';
import 'auth_api.dart';

/// Source of truth for the user's auth state. Other features (router guards,
/// post-auth fetches) watch this provider.
class AuthRepository extends AsyncNotifier<AuthState> {
  late SecureStorage _storage;
  late AuthApi _api;
  late FcmService _fcmService;

  @override
  Future<AuthState> build() async {
    _storage = ref.read(secureStorageProvider);
    _api = ref.read(authApiProvider);
    _fcmService = ref.read(fcmServiceProvider);
    return _bootFromStorage();
  }

  Future<AuthState> _bootFromStorage() async {
    final access = await _storage.readAccessToken();
    if (access == null || access.isEmpty) return const AuthAnonymous();
    try {
      final user = await _api.me();
      return AuthAuthenticated(user: user);
    } catch (_) {
      // Token rejected or network down. Treat as anonymous; let interceptor
      // attempt refresh on the next protected call.
      return const AuthAnonymous();
    }
  }

  Future<void> _afterAuth() async {
    try {
      await _fcmService.registerToken();
    } catch (_) {
      // Best-effort — auth must not fail if FCM registration fails.
    }
  }

  /// Persists tokens + fetches `me`. Called after signup-complete and login.
  Future<void> applyTokensAndFetchUser(SessionTokens tokens) async {
    await _storage.writeTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _api.me();
      return AuthAuthenticated(user: user);
    });
    await _afterAuth();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final tokens = await _api.login(email: email, password: password);
      await _storage.writeTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      final user = await _api.me();
      return AuthAuthenticated(user: user);
    });
    await _afterAuth();
  }

  Future<void> logout() async {
    // Unregister device token before clearing storage (needs access token).
    try {
      await _fcmService.unregisterToken();
    } catch (_) {
      // Best-effort — logout must succeed even if FCM unregister fails.
    }
    try {
      await _api.logout();
    } catch (_) {
      // Best-effort; clear local state regardless.
    }
    await _storage.clear();
    state = const AsyncData(AuthAnonymous());
  }
}

final authRepositoryProvider = AsyncNotifierProvider<AuthRepository, AuthState>(
  AuthRepository.new,
);
