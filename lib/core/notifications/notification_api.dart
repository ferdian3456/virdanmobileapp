import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../http/dio_client.dart';

class NotificationApi {
  NotificationApi(this._dio);

  final Dio _dio;

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    await _dio.post('/devices', data: {
      'token': token,
      'platform': platform,
    });
  }

  Future<void> unregisterDevice({required String token}) async {
    await _dio.delete('/devices', data: {'token': token});
  }

  /// Returns the raw feed payload: { data: [...], page: { nextCursor } }.
  Future<Map<String, dynamic>> getNotifications({String? cursor, int limit = 10}) async {
    final response = await _dio.get('/notifications', queryParameters: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> markRead(String notifId) async {
    await _dio.post('/notifications/$notifId/read');
  }

  Future<int> getUnreadCount() async {
    final response = await _dio.get('/notifications/unread-count');
    return (response.data as Map<String, dynamic>)['count'] as int? ?? 0;
  }

  Future<void> updateNotificationPreferences({
    required bool notifLike,
    required bool notifComment,
    required bool notifReply,
  }) async {
    await _dio.put('/users/me/notification-preferences', data: {
      'notifLike': notifLike,
      'notifComment': notifComment,
      'notifReply': notifReply,
    });
  }
}

final notificationApiProvider = Provider<NotificationApi>((ref) {
  return NotificationApi(ref.read(apiDioProvider));
});

/// Unread badge count for the Activity tab. Polled (no WebSocket); invalidate to refresh
/// (on tab open, and after marking a notification read).
final unreadCountProvider = FutureProvider<int>((ref) async {
  try {
    return await ref.read(notificationApiProvider).getUnreadCount();
  } catch (_) {
    return 0;
  }
});
