import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../domain/server.dart';
import 'server_api.dart';

@immutable
class MyServersState {
  const MyServersState({
    required this.servers,
    this.activeServerId,
    this.isLoading = false,
    this.isInitialized = false,
  });

  static const initial = MyServersState(servers: []);

  final List<Server> servers;
  final String? activeServerId;
  final bool isLoading;

  /// True once `GET /servers/me` has returned at least once (success or
  /// failure). Router uses this to avoid redirecting to onboarding before
  /// the fetch resolves — otherwise we punt a user with N>0 servers to the
  /// onboarding screen on cold boot just because we hadn't asked yet.
  final bool isInitialized;

  bool get hasServers => servers.isNotEmpty;

  Server? get activeServer {
    if (activeServerId == null) return null;
    for (final s in servers) {
      if (s.id == activeServerId) return s;
    }
    return null;
  }

  MyServersState copyWith({
    List<Server>? servers,
    String? activeServerId,
    bool? isLoading,
    bool? isInitialized,
  }) {
    return MyServersState(
      servers: servers ?? this.servers,
      activeServerId: activeServerId ?? this.activeServerId,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Holds the user's joined servers + active selection. Mirrors Quasar
/// app.store.ts. Listens to auth state so it clears on logout and refetches
/// on login.
class MyServersRepository extends Notifier<MyServersState> {
  bool _initialized = false;

  @override
  MyServersState build() {
    bool isAuthed(AsyncValue<AuthState>? v) => switch (v) {
          AsyncData(value: AuthAuthenticated()) => true,
          _ => false,
        };

    ref.listen<AsyncValue<AuthState>>(authRepositoryProvider, (prev, next) {
      final nowAuthed = isAuthed(next);
      final wasAuthed = isAuthed(prev);
      if (!nowAuthed && wasAuthed) {
        _initialized = false;
        state = MyServersState.initial;
      } else if (nowAuthed && !wasAuthed) {
        _initialized = false;
        // Fire-and-forget: the router will gate `requiresServer` against the
        // freshest state. Avoid blocking the auth transition.
        Future.microtask(fetch);
      }
    });
    return MyServersState.initial;
  }

  Future<void> fetch({bool force = false}) async {
    if (_initialized && !force) return;
    state = state.copyWith(isLoading: true);
    try {
      final page = await ref.read(serverApiProvider).myServers();
      final servers = page.data;
      String? active = state.activeServerId;
      if (servers.isEmpty) {
        active = null;
      } else if (active == null || !servers.any((s) => s.id == active)) {
        active = servers.first.id;
      }
      state = MyServersState(
        servers: servers,
        activeServerId: active,
        isLoading: false,
        isInitialized: true,
      );
      _initialized = true;
    } catch (e) {
      // Mark initialized so the router stops bouncing; let page show error.
      state = state.copyWith(isLoading: false, isInitialized: true);
      _initialized = true;
      rethrow;
    }
  }

  void setActive(String serverId) {
    if (!state.servers.any((s) => s.id == serverId)) return;
    state = state.copyWith(activeServerId: serverId);
  }
}

final myServersProvider = NotifierProvider<MyServersRepository, MyServersState>(
  MyServersRepository.new,
);
