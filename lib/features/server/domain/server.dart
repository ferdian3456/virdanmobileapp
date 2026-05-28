import 'package:flutter/foundation.dart';

/// Minimal server entry from `GET /api/servers/me`.
@immutable
class Server {
  const Server({
    required this.id,
    required this.name,
    required this.shortName,
    this.avatarUrl,
    this.joinedAt,
  });

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: (json['shortName'] as String?) ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      joinedAt: json['joinedAt'] as String?,
    );
  }

  final String id;
  final String name;
  final String shortName;
  final String? avatarUrl;
  final String? joinedAt;
}

/// Category entry from `GET /api/servers/categories`.
@immutable
class ServerCategory {
  const ServerCategory({required this.id, required this.categoryName});

  factory ServerCategory.fromJson(Map<String, dynamic> json) {
    return ServerCategory(
      id: (json['id'] as num).toInt(),
      categoryName: json['categoryName'] as String,
    );
  }

  final int id;
  final String categoryName;
}

/// Public discovery row from `GET /api/servers/`.
@immutable
class DiscoveryServer {
  const DiscoveryServer({
    required this.id,
    required this.name,
    required this.shortName,
    required this.memberCount,
    required this.isMember,
    this.categoryName,
    this.avatarUrl,
    this.bannerUrl,
    this.description,
    this.createdAt,
  });

  factory DiscoveryServer.fromJson(Map<String, dynamic> json) {
    return DiscoveryServer(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: (json['shortName'] as String?) ?? '',
      categoryName: json['categoryName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      description: json['description'] as String?,
      createdAt: json['createdAt'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      isMember: (json['isMember'] as bool?) ?? false,
    );
  }

  final String id;
  final String name;
  final String shortName;
  final String? categoryName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? description;
  final String? createdAt;
  final int memberCount;
  final bool isMember;
}

@immutable
class CursorPage<T> {
  const CursorPage({required this.data, this.nextCursor, this.limit = 0});

  factory CursorPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final list = json['data'] as List<dynamic>? ?? const [];
    final page = json['page'] as Map<String, dynamic>?;
    final next = page?['nextCursor'];
    return CursorPage<T>(
      data: list.whereType<Map<String, dynamic>>().map(parse).toList(growable: false),
      nextCursor: (next is String && next.isNotEmpty) ? next : null,
      limit: (page?['limit'] as num?)?.toInt() ?? 0,
    );
  }

  final List<T> data;
  final String? nextCursor;
  final int limit;
}
