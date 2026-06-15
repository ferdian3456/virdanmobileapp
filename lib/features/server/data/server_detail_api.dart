import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/http/dio_client.dart';

@immutable
class ServerDetail {
  const ServerDetail({
    required this.id,
    required this.name,
    required this.shortName,
    this.categoryName,
    this.avatarUrl,
    this.bannerUrl,
    this.description,
    this.createdBy,
    this.memberCount = 0,
    this.isPrivate = false,
    this.plusActive = false,
    this.plusExpiresAt,
  });

  factory ServerDetail.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'] as Map<String, dynamic>?;
    final plusExpires = json['plusExpiresAt'] as String?;
    return ServerDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: (json['shortName'] as String?) ?? '',
      categoryName: json['categoryName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      description: json['description'] as String?,
      createdBy: json['createdBy'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      isPrivate: (settings?['isPrivate'] as bool?) ?? false,
      plusActive: (json['plusActive'] as bool?) ?? false,
      plusExpiresAt: plusExpires != null ? DateTime.tryParse(plusExpires) : null,
    );
  }

  final String id;
  final String name;
  final String shortName;
  final String? categoryName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? description;
  final String? createdBy;
  final int memberCount;
  final bool isPrivate;
  final bool plusActive;
  final DateTime? plusExpiresAt;
}

@immutable
class ServerInviteInfo {
  const ServerInviteInfo({
    required this.code,
    required this.serverId,
    required this.serverName,
    required this.serverShortName,
    this.serverDescription,
    this.serverAvatarUrl,
    this.serverBannerUrl,
    this.memberCount = 0,
    this.alreadyMember = false,
  });

  factory ServerInviteInfo.fromJson(Map<String, dynamic> json) {
    return ServerInviteInfo(
      code: (json['code'] as String?) ?? '',
      serverId: (json['serverId'] as String?) ?? '',
      serverName: (json['serverName'] as String?) ?? 'Server',
      serverShortName: (json['serverShortName'] as String?) ?? '',
      serverDescription: json['serverDescription'] as String?,
      serverAvatarUrl: json['serverAvatarUrl'] as String?,
      serverBannerUrl: json['serverBannerUrl'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      alreadyMember: (json['alreadyMember'] as bool?) ?? false,
    );
  }

  final String code;
  final String serverId;
  final String serverName;
  final String serverShortName;
  final String? serverDescription;
  final String? serverAvatarUrl;
  final String? serverBannerUrl;
  final int memberCount;
  final bool alreadyMember;
}

class ServerDetailApi {
  ServerDetailApi(this._dio);

  final Dio _dio;

  Future<ServerDetail> getById(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/servers/$id');
    return ServerDetail.fromJson(res.data ?? const {});
  }

  Future<ServerInviteInfo> inviteInfo(String code) async {
    final res = await _dio.get<Map<String, dynamic>>('/servers/invites/$code');
    return ServerInviteInfo.fromJson(res.data ?? const {});
  }

  Future<void> joinViaInvite(String code) async {
    await _dio.post<Map<String, dynamic>>(
      '/servers/join',
      data: {'inviteCode': code},
    );
  }

  Future<void> updateName(String id, String name) async {
    await _dio.put<Map<String, dynamic>>('/servers/$id/name', data: {'name': name});
  }

  Future<void> updateShortName(String id, String shortName) async {
    await _dio.put<Map<String, dynamic>>(
      '/servers/$id/shortName',
      data: {'shortName': shortName},
    );
  }

  Future<void> updateCategory(String id, int categoryId) async {
    await _dio.put<Map<String, dynamic>>(
      '/servers/$id/category',
      data: {'categoryId': categoryId},
    );
  }

  Future<void> updateDescription(String id, String description) async {
    await _dio.put<Map<String, dynamic>>(
      '/servers/$id/description',
      data: {'description': description},
    );
  }

  Future<void> updateSettings(String id, {required bool isPrivate}) async {
    await _dio.put<Map<String, dynamic>>(
      '/servers/$id/settings',
      data: {'isPrivate': isPrivate},
    );
  }

  Future<void> updateAvatar(String id, XFile file) async {
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(file.path, filename: file.name),
    });
    await _dio.put<Map<String, dynamic>>(
      '/servers/$id/avatar',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> updateBanner(String id, XFile file) async {
    final form = FormData.fromMap({
      'banner': await MultipartFile.fromFile(file.path, filename: file.name),
    });
    await _dio.put<Map<String, dynamic>>(
      '/servers/$id/banner',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> delete(String id) async {
    await _dio.delete<Map<String, dynamic>>('/servers/$id');
  }

  Future<void> leave(String id) async {
    await _dio.delete<Map<String, dynamic>>('/servers/$id/membership');
  }

  Future<({String code, int? maxUses})> createInvite(String serverId, {int? maxUses}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/servers/$serverId/invites',
      data: {?maxUses},
    );
    final data = res.data ?? const {};
    return (
      code: (data['code'] as String?) ?? '',
      maxUses: (data['maxUses'] as num?)?.toInt(),
    );
  }
}

final serverDetailApiProvider = Provider<ServerDetailApi>((ref) {
  return ServerDetailApi(ref.read(apiDioProvider));
});
