import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_api.dart';

class FcmService {
  FcmService(this._api);

  final NotificationApi _api;

  static const _androidChannel = AndroidNotificationChannel(
    'virdan_high_importance',
    'Virdan Notifications',
    description: 'Push notifications from Virdan',
    importance: Importance.high,
  );

  static final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await _setupLocalNotifications();
    await _requestPermission();
    _listenForeground();
  }

  Future<void> _setupLocalNotifications() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  Future<void> _requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification == null || android == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  Future<String?> getToken() async {
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> registerToken() async {
    final token = await getToken();
    if (token == null) return;

    final platform = Platform.isAndroid ? 'android' : 'ios';
    await _api.registerDevice(token: token, platform: platform);

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _api.registerDevice(token: newToken, platform: platform);
    });
  }

  Future<void> unregisterToken() async {
    final token = await getToken();
    if (token == null) return;
    await _api.unregisterDevice(token: token);
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref.read(notificationApiProvider));
});
