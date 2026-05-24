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
}

final serverApiProvider = Provider<ServerApi>((ref) {
  return ServerApi(ref.read(apiDioProvider));
});
