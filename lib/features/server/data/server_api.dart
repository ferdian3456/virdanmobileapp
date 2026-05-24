import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_client.dart';
import '../domain/server.dart';

class ServerApi {
  ServerApi(this._dio);

  final Dio _dio;

  Future<List<ServerCategory>> categories({int limit = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/servers/categories',
      queryParameters: {'limit': limit},
    );
    final page = CursorPage.fromJson(res.data ?? const {}, ServerCategory.fromJson);
    return page.data;
  }

  Future<CursorPage<DiscoveryServer>> discover({
    int? categoryId,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (categoryId != null) params['categoryId'] = categoryId;
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    final res = await _dio.get<Map<String, dynamic>>(
      '/servers/',
      queryParameters: params,
    );
    return CursorPage.fromJson(res.data ?? const {}, DiscoveryServer.fromJson);
  }

  Future<CursorPage<Server>> myServers({int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/servers/me',
      queryParameters: {'limit': limit},
    );
    return CursorPage.fromJson(res.data ?? const {}, Server.fromJson);
  }

  Future<void> join(String serverId) async {
    await _dio.post<Map<String, dynamic>>('/servers/$serverId/join');
  }

  /// `POST /api/servers/create` — multipart. BE requires both the server
  /// fields *and* the owner's per-server profile (multi-identity Opsi B,
  /// copy-on-join), so both are passed in one form.
  ///
  /// Returns the newly-created server id.
  Future<String> createServer({
    required String name,
    required String shortName,
    required int categoryId,
    required bool isPrivate,
    required String nickname,
    required String username,
    String description = '',
    String bio = '',
    // TODO(VIR-90 Phase 4): avatar uploads (serverAvatar, profileAvatar) once
    // image_picker lands.
  }) async {
    final form = FormData.fromMap({
      'name': name,
      'shortName': shortName,
      'categoryId': categoryId.toString(),
      'description': description,
      'isPrivate': isPrivate.toString(),
      'nickname': nickname,
      'username': username,
      'bio': bio,
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/servers/create',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final server = (res.data?['server'] as Map?)?.cast<String, dynamic>();
    if (server == null || server['id'] == null) {
      throw StateError('createServer: malformed response');
    }
    return server['id'] as String;
  }
}

final serverApiProvider = Provider<ServerApi>((ref) {
  return ServerApi(ref.read(apiDioProvider));
});
