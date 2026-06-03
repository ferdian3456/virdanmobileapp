import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../post/data/post_api.dart';
import '../../post/domain/post.dart';

@immutable
class PostSearchState {
  const PostSearchState({
    this.query = '',
    this.results = const [],
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasError = false,
    this.hasSearched = false,
  });

  static const initial = PostSearchState();

  final String query;
  final List<Post> results;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasError;

  /// True once a query has run at least once for the current term — lets the
  /// view tell "empty because no query yet" apart from "no matches".
  final bool hasSearched;

  bool get hasMore => nextCursor != null;

  PostSearchState copyWith({
    String? query,
    List<Post>? results,
    String? nextCursor,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasError,
    bool? hasSearched,
    bool clearNextCursor = false,
  }) {
    return PostSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasError: hasError ?? this.hasError,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

class PostSearch extends Notifier<PostSearchState> {
  CancelToken? _token;

  @override
  PostSearchState build() {
    ref.onDispose(() => _token?.cancel('disposed'));
    return PostSearchState.initial;
  }

  /// Runs a fresh search for [query] in [serverId]. Cancels any in-flight
  /// request first so a slow earlier response can't overwrite newer results.
  Future<void> run(String serverId, String query) async {
    final trimmed = query.trim();
    _token?.cancel('superseded');
    final token = CancelToken();
    _token = token;

    state = state.copyWith(
      query: trimmed,
      isLoading: true,
      hasError: false,
      results: const [],
      clearNextCursor: true,
      hasSearched: true,
    );

    try {
      final page = await ref.read(postApiProvider).searchPosts(
            serverId: serverId,
            query: trimmed,
            cancelToken: token,
          );
      if (token.isCancelled) return;
      state = state.copyWith(
        results: page.data,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoading: false,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || token.isCancelled) return;
      state = state.copyWith(isLoading: false, hasError: true);
      rethrow;
    }
  }

  /// Loads the next page for the current query. No-op while loading or done.
  Future<void> loadMore(String serverId) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    if (state.query.isEmpty) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await ref.read(postApiProvider).searchPosts(
            serverId: serverId,
            query: state.query,
            cursor: state.nextCursor,
          );
      state = state.copyWith(
        results: [...state.results, ...page.data],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      state = state.copyWith(isLoadingMore: false, hasError: true);
      rethrow;
    }
  }

  /// Resets to the empty state (used when the query is cleared / below min len).
  void clear() {
    _token?.cancel('cleared');
    _token = null;
    state = PostSearchState.initial;
  }
}

final postSearchProvider =
    NotifierProvider<PostSearch, PostSearchState>(PostSearch.new);
