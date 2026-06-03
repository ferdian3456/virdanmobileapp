import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_client.dart';
import '../../server/domain/server.dart';
import '../domain/post.dart';

class PostApi {
  PostApi(this._dio);

  final Dio _dio;

  Future<CursorPage<Post>> listForServer({
    required String serverId,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    final res = await _dio.get<Map<String, dynamic>>(
      '/servers/$serverId/posts',
      queryParameters: params,
    );
    return CursorPage.fromJson(res.data ?? const {}, Post.fromJson);
  }

  Future<CursorPage<Post>> postsForMe({
    required String serverId,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    final res = await _dio.get<Map<String, dynamic>>(
      '/servers/$serverId/posts/me',
      queryParameters: params,
    );
    return CursorPage.fromJson(res.data ?? const {}, Post.fromJson);
  }

  Future<CursorPage<Post>> postsForUser({
    required String serverId,
    required String userId,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    final res = await _dio.get<Map<String, dynamic>>(
      '/servers/$serverId/members/$userId/posts',
      queryParameters: params,
    );
    return CursorPage.fromJson(res.data ?? const {}, Post.fromJson);
  }

  Future<Post> getById(String postId) async {
    final res = await _dio.get<Map<String, dynamic>>('/posts/$postId');
    return Post.fromJson(res.data ?? const {});
  }

  Future<Post> create({
    required String serverId,
    required String caption,
    // TODO(Phase 4): image upload via multipart once image_picker is wired.
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/servers/$serverId/posts',
      data: {'caption': caption},
    );
    return Post.fromJson(res.data ?? const {});
  }

  /// Edit a post's caption. Only the author can update; image is immutable
  /// server-side (PUT accepts caption only). Returns the refreshed post.
  Future<Post> updateCaption({
    required String serverId,
    required String postId,
    required String caption,
  }) async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/servers/$serverId/posts/$postId',
      data: {'caption': caption},
    );
    return Post.fromJson(res.data ?? const {});
  }

  /// Hard-delete a post. Author-only server-side; cascades images/comments/likes.
  Future<void> delete({
    required String serverId,
    required String postId,
  }) async {
    await _dio.delete<Map<String, dynamic>>('/servers/$serverId/posts/$postId');
  }

  Future<void> like(String postId) async {
    await _dio.post<Map<String, dynamic>>('/posts/$postId/likes');
  }

  Future<void> unlike(String postId) async {
    await _dio.delete<Map<String, dynamic>>('/posts/$postId/likes');
  }

  Future<void> save(String postId) async {
    await _dio.post<Map<String, dynamic>>('/posts/$postId/saves');
  }

  Future<void> unsave(String postId) async {
    await _dio.delete<Map<String, dynamic>>('/posts/$postId/saves');
  }

  /// Search posts by caption within one server (active-server scoped).
  /// [cancelToken] lets the caller drop a stale in-flight request when the
  /// query changes. Server enforces min 2 chars; callers should gate on that.
  Future<CursorPage<Post>> searchPosts({
    required String serverId,
    required String query,
    String? cursor,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    final params = <String, dynamic>{'q': query, 'limit': limit};
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    final res = await _dio.get<Map<String, dynamic>>(
      '/servers/$serverId/posts/search',
      queryParameters: params,
      cancelToken: cancelToken,
    );
    return CursorPage.fromJson(res.data ?? const {}, Post.fromJson);
  }

  /// Saved (bookmarked) posts for the current user within one server.
  /// Per-server scoped, ordered by save time (newest first).
  Future<CursorPage<Post>> savedForServer({
    required String serverId,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    final res = await _dio.get<Map<String, dynamic>>(
      '/servers/$serverId/posts/saved',
      queryParameters: params,
    );
    return CursorPage.fromJson(res.data ?? const {}, Post.fromJson);
  }

  Future<CursorPage<Comment>> comments(String postId,
      {String? cursor, int limit = 20}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    final res = await _dio.get<Map<String, dynamic>>(
      '/posts/$postId/comments',
      queryParameters: params,
    );
    return CursorPage.fromJson(res.data ?? const {}, Comment.fromJson);
  }

  Future<Comment> postComment(
    String postId,
    String content, {
    String? parentId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/posts/$postId/comments',
      data: {
        'content': content,
        if (parentId != null) 'parentId': parentId,
      },
    );
    return Comment.fromJson(res.data ?? const {});
  }
}

final postApiProvider = Provider<PostApi>((ref) {
  return PostApi(ref.read(apiDioProvider));
});
