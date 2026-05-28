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

  Future<void> like(String postId) async {
    await _dio.post<Map<String, dynamic>>('/posts/$postId/likes');
  }

  Future<void> unlike(String postId) async {
    await _dio.delete<Map<String, dynamic>>('/posts/$postId/likes');
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
