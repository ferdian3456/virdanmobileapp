import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/post.dart';
import 'post_api.dart';

@immutable
class ServerFeedState {
  const ServerFeedState({
    required this.posts,
    this.serverId,
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasError = false,
  });

  static const initial = ServerFeedState(posts: []);

  final List<Post> posts;
  final String? serverId;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasError;

  bool get hasMore => nextCursor != null;

  ServerFeedState copyWith({
    List<Post>? posts,
    String? serverId,
    String? nextCursor,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasError,
    bool clearNextCursor = false,
  }) {
    return ServerFeedState(
      posts: posts ?? this.posts,
      serverId: serverId ?? this.serverId,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
    );
  }
}

/// Cursor-paginated feed for the currently active server. Holds posts for one
/// server at a time; switching servers clears the buffer and reloads. Multi-
/// server caching can be layered on later via a keyed map if needed.
class ServerFeed extends Notifier<ServerFeedState> {
  @override
  ServerFeedState build() => ServerFeedState.initial;

  /// Switches the active feed target. No-op when [serverId] matches the
  /// current one. Always triggers a fresh load.
  Future<void> loadFor(String serverId) async {
    if (state.serverId != serverId) {
      state = ServerFeedState.initial.copyWith(serverId: serverId);
    }
    return _load(reset: true);
  }

  Future<void> refresh() {
    final id = state.serverId;
    if (id == null) return Future.value();
    return _load(reset: true);
  }

  Future<void> loadMore() {
    final id = state.serverId;
    if (id == null) return Future.value();
    return _load(reset: false);
  }

  Future<void> _load({required bool reset}) async {
    final serverId = state.serverId;
    if (serverId == null) return;
    if (reset) {
      if (state.isLoading) return;
      state = state.copyWith(
        isLoading: true,
        hasError: false,
        posts: const [],
        clearNextCursor: true,
      );
    } else {
      if (state.isLoadingMore || !state.hasMore) return;
      state = state.copyWith(isLoadingMore: true);
    }
    try {
      final page = await ref.read(postApiProvider).listForServer(
            serverId: serverId,
            cursor: reset ? null : state.nextCursor,
          );
      final next = reset ? page.data : [...state.posts, ...page.data];
      state = ServerFeedState(
        serverId: serverId,
        posts: next,
        nextCursor: page.nextCursor,
        isLoading: false,
        isLoadingMore: false,
        hasError: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        hasError: true,
        clearNextCursor: true,
      );
      rethrow;
    }
  }

  /// Optimistic like/unlike with rollback on failure.
  Future<void> toggleLike(String postId) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final before = state.posts[idx];
    final next = before.copyWith(
      isLiked: !before.isLiked,
      likeCount: before.isLiked ? before.likeCount - 1 : before.likeCount + 1,
    );
    final list = [...state.posts]..[idx] = next;
    state = state.copyWith(posts: list);
    try {
      if (before.isLiked) {
        await ref.read(postApiProvider).unlike(postId);
      } else {
        await ref.read(postApiProvider).like(postId);
      }
    } catch (e) {
      final rollback = [...state.posts];
      final j = rollback.indexWhere((p) => p.id == postId);
      if (j != -1) rollback[j] = before;
      state = state.copyWith(posts: rollback);
      rethrow;
    }
  }

  /// Optimistic save/unsave with rollback on failure.
  Future<void> toggleSave(String postId) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final before = state.posts[idx];
    final next = before.copyWith(isSaved: !before.isSaved);
    final list = [...state.posts]..[idx] = next;
    state = state.copyWith(posts: list);
    try {
      if (before.isSaved) {
        await ref.read(postApiProvider).unsave(postId);
      } else {
        await ref.read(postApiProvider).save(postId);
      }
    } catch (e) {
      final rollback = [...state.posts];
      final j = rollback.indexWhere((p) => p.id == postId);
      if (j != -1) rollback[j] = before;
      state = state.copyWith(posts: rollback);
      rethrow;
    }
  }
}

final serverFeedProvider =
    NotifierProvider<ServerFeed, ServerFeedState>(ServerFeed.new);
