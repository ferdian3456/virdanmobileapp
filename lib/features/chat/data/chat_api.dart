import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_client.dart';
import '../domain/chat_models.dart';

class ChatApi {
  ChatApi(this._dio);

  final Dio _dio;

  Future<DmConversationPage> listConversations(
    String serverId, {
    String? cursor,
    int limit = 20,
  }) async {
    final resp = await _dio.get(
      '/servers/$serverId/conversations',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return DmConversationPage.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<DmConversationItem> getOrCreateConversation(
    String serverId,
    String peerUserId,
  ) async {
    final resp = await _dio.post(
      '/servers/$serverId/conversations',
      data: {'peerUserId': peerUserId},
    );
    return DmConversationItem.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<DmMessagePage> listMessages(
    String conversationId, {
    String? cursor,
    int limit = 20,
  }) async {
    final resp = await _dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return DmMessagePage.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<DmMessageItem> sendMessage(
    String conversationId, {
    required String content,
    required String clientMessageId,
  }) async {
    final resp = await _dio.post(
      '/conversations/$conversationId/messages',
      data: {'content': content, 'clientMessageId': clientMessageId},
    );
    return DmMessageItem.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> markRead(
    String conversationId, {
    String? lastReadMessageId,
  }) async {
    await _dio.post(
      '/conversations/$conversationId/read',
      data: {
        if (lastReadMessageId != null) 'lastReadMessageId': lastReadMessageId,
      },
    );
  }
}

final chatApiProvider = Provider<ChatApi>((ref) {
  return ChatApi(ref.read(apiDioProvider));
});
