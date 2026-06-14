import 'package:flutter/foundation.dart';

@immutable
class ServerMember {
  const ServerMember({
    required this.userId,
    required this.role,
    required this.nickname,
    required this.username,
    this.avatarUrl,
    required this.joinedAt,
  });

  factory ServerMember.fromJson(Map<String, dynamic> json) {
    return ServerMember(
      userId: json['userId'] as String,
      role: json['role'] as String,
      nickname: json['nickname'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }

  final String userId;
  final String role;
  final String nickname;
  final String username;
  final String? avatarUrl;
  final DateTime joinedAt;

  bool get isOwner => role == 'Owner';
  bool get isAdmin => role == 'Admin';
  bool get isMember => role == 'Member';
  bool get isModerator => role == 'Owner' || role == 'Admin';
}
