import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_client.dart';
import '../../server/domain/server.dart';

@immutable
class ServerMemberProfile {
  const ServerMemberProfile({
    required this.profileId,
    required this.serverId,
    required this.nickname,
    required this.username,
    this.bio,
    this.avatarImageId,
    this.avatarUrl,
  });

  factory ServerMemberProfile.fromJson(Map<String, dynamic> json) {
    return ServerMemberProfile(
      profileId: (json['profileId'] as String?) ?? (json['id'] as String? ?? ''),
      serverId: (json['serverId'] as String?) ?? '',
      nickname: (json['nickname'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      bio: json['bio'] as String?,
      avatarImageId: json['avatarImageId'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  final String profileId;
  final String serverId;
  final String nickname;
  final String username;
  final String? bio;
  final String? avatarImageId;
  final String? avatarUrl;
}

@immutable
class ProfileHistoryItem {
  const ProfileHistoryItem({
    required this.profileId,
    required this.serverId,
    required this.serverName,
    required this.nickname,
    required this.username,
    this.bio,
    this.avatarUrl,
    this.isStillMember = false,
  });

  factory ProfileHistoryItem.fromJson(Map<String, dynamic> json) {
    return ProfileHistoryItem(
      profileId: (json['profileId'] as String?) ?? '',
      serverId: (json['serverId'] as String?) ?? '',
      serverName: (json['serverName'] as String?) ?? '',
      nickname: (json['nickname'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isStillMember: (json['isStillMember'] as bool?) ?? false,
    );
  }

  final String profileId;
  final String serverId;
  final String serverName;
  final String nickname;
  final String username;
  final String? bio;
  final String? avatarUrl;
  final bool isStillMember;
}

class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<ServerMemberProfile> meForServer(String serverId) async {
    final res = await _dio.get<Map<String, dynamic>>('/servers/$serverId/profile/me');
    return ServerMemberProfile.fromJson(res.data ?? const {});
  }

  Future<CursorPage<ProfileHistoryItem>> history() async {
    final res = await _dio.get<Map<String, dynamic>>('/profiles/history');
    return CursorPage.fromJson(res.data ?? const {}, ProfileHistoryItem.fromJson);
  }

  Future<void> upsert({
    required String serverId,
    required String nickname,
    required String username,
    String bio = '',
  }) async {
    await _dio.put<Map<String, dynamic>>(
      '/servers/$serverId/profile',
      data: {
        'nickname': nickname,
        'username': username,
        'bio': bio,
      },
    );
  }
}

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(ref.read(apiDioProvider));
});
