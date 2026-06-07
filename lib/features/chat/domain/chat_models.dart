import 'package:flutter/foundation.dart';

@immutable
class DmIdentity {
  const DmIdentity({
    required this.nickname,
    required this.username,
    this.avatarUrl,
  });

  factory DmIdentity.fromJson(Map<String, dynamic> j) => DmIdentity(
        nickname: j['nickname'] as String,
        username: j['username'] as String,
        avatarUrl: j['avatarUrl'] as String?,
      );

  final String nickname;
  final String username;
  final String? avatarUrl;
}

@immutable
class DmConversationItem {
  const DmConversationItem({
    required this.id,
    required this.serverId,
    required this.peerUserId,
    required this.peer,
    required this.unreadCount,
    required this.isOnline,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  factory DmConversationItem.fromJson(Map<String, dynamic> j) =>
      DmConversationItem(
        id: j['id'] as String,
        serverId: j['serverId'] as String,
        peerUserId: j['peerUserId'] as String,
        peer: DmIdentity.fromJson(j['peer'] as Map<String, dynamic>),
        unreadCount: j['unreadCount'] as int,
        isOnline: j['isOnline'] as bool? ?? false,
        lastMessagePreview: j['lastMessagePreview'] as String?,
        lastMessageAt: j['lastMessageAt'] == null
            ? null
            : DateTime.tryParse(j['lastMessageAt'] as String),
      );

  final String id;
  final String serverId;
  final String peerUserId;
  final DmIdentity peer;
  final int unreadCount;
  final bool isOnline;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
}

@immutable
class DmConversationPage {
  const DmConversationPage({required this.data, this.nextCursor});

  factory DmConversationPage.fromJson(Map<String, dynamic> j) {
    final list = (j['data'] as List).cast<Map<String, dynamic>>();
    final page = j['page'] as Map<String, dynamic>?;
    return DmConversationPage(
      data: list.map(DmConversationItem.fromJson).toList(),
      nextCursor: page?['nextCursor'] as String?,
    );
  }

  final List<DmConversationItem> data;
  final String? nextCursor;
}

@immutable
class DmMessageItem {
  const DmMessageItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.sender,
    required this.content,
    required this.clientMessageId,
    required this.createdAt,
  });

  factory DmMessageItem.fromJson(Map<String, dynamic> j) => DmMessageItem(
        id: j['id'] as String,
        conversationId: j['conversationId'] as String,
        senderId: j['senderId'] as String,
        sender: DmIdentity.fromJson(j['sender'] as Map<String, dynamic>),
        content: j['content'] as String,
        clientMessageId: j['clientMessageId'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  final String id;
  final String conversationId;
  final String senderId;
  final DmIdentity sender;
  final String content;
  final String clientMessageId;
  final DateTime createdAt;
}

@immutable
class DmMessagePage {
  const DmMessagePage({required this.data, this.nextCursor});

  factory DmMessagePage.fromJson(Map<String, dynamic> j) {
    final list = (j['data'] as List).cast<Map<String, dynamic>>();
    final page = j['page'] as Map<String, dynamic>?;
    return DmMessagePage(
      data: list.map(DmMessageItem.fromJson).toList(),
      nextCursor: page?['nextCursor'] as String?,
    );
  }

  final List<DmMessageItem> data;
  final String? nextCursor;
}

// ── WS event types ──

enum WsEventType { messageNew, read, typing, presence, unknown }

@immutable
class WsEvent {
  const WsEvent({required this.type, required this.payload});

  final WsEventType type;
  final Map<String, dynamic> payload;
}

// ── Navigation extras ──

@immutable
class ChatConversationArgs {
  const ChatConversationArgs({
    required this.peerUserId,
    required this.peerNickname,
    this.peerAvatarUrl,
    this.peerIsOnline = false,
  });

  final String peerUserId;
  final String peerNickname;
  final String? peerAvatarUrl;
  final bool peerIsOnline;
}
