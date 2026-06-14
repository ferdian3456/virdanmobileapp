import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_client.dart';
import '../domain/server.dart';
import '../domain/server_member.dart';

class ServerMembersApi {
  ServerMembersApi(this._dio);

  final Dio _dio;

  Future<CursorPage<ServerMember>> getMembers(
    String serverId, {
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;
    final res = await _dio.get<Map<String, dynamic>>(
      '/servers/$serverId/members',
      queryParameters: params,
    );
    return CursorPage.fromJson(res.data ?? const {}, ServerMember.fromJson);
  }

  Future<String> getMyRole(String serverId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/servers/$serverId/members/me',
    );
    return (res.data?['role'] as String?) ?? 'Member';
  }

  Future<void> kickMember(String serverId, String userId) async {
    await _dio.delete<void>('/servers/$serverId/members/$userId');
  }

  Future<void> updateRole(String serverId, String userId, String role) async {
    await _dio.put<void>(
      '/servers/$serverId/members/$userId/role',
      data: {'role': role},
    );
  }

  Future<void> transferOwnership(String serverId, String toUserId) async {
    await _dio.put<void>(
      '/servers/$serverId/ownership',
      data: {'newOwnerId': toUserId},
    );
  }

  Future<void> leaveServer(String serverId) async {
    await _dio.delete<void>('/servers/$serverId/membership');
  }
}

final serverMembersApiProvider = Provider<ServerMembersApi>((ref) {
  return ServerMembersApi(ref.read(apiDioProvider));
});

/// Returns the caller's role ("Owner" | "Admin" | "Member") in a specific server.
/// Used to gate moderation UI (delete others' posts, kick, etc.).
///
/// autoDispose so the role is refetched whenever the watching page is reopened —
/// otherwise a cached role survives logout/login or a role change and the wrong
/// badge (e.g. OWNER for a non-owner) is shown.
final myRoleInServerProvider =
    FutureProvider.autoDispose.family<String, String>((ref, serverId) {
  return ref.read(serverMembersApiProvider).getMyRole(serverId);
});
