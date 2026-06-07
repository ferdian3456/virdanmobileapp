import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../domain/chat_models.dart';

const _apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://virdan.cloud/api',
);

String _toWsUrl(String apiUrl) {
  final base = apiUrl
      .replaceFirst('https://', 'wss://')
      .replaceFirst('http://', 'ws://');
  return '$base/ws';
}

/// Generates a random 32-char hex string for idempotent message dedup.
String generateClientMessageId() {
  final rng = math.Random.secure();
  final bytes = List.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class ChatWsService {
  ChatWsService(this._storage);

  final SecureStorage _storage;
  final String _wsUrl = _toWsUrl(_apiUrl);

  WebSocket? _socket;
  bool _disposed = false;
  bool _shouldConnect = false;
  Timer? _retryTimer;

  final _controller = StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get events => _controller.stream;

  void activate() {
    _shouldConnect = true;
    _connect();
  }

  void deactivate() {
    _shouldConnect = false;
    _retryTimer?.cancel();
    _socket?.close();
    _socket = null;
  }

  Future<void> _connect() async {
    if (_disposed || !_shouldConnect || _socket != null) return;

    final token = await _storage.readAccessToken();
    if (token == null || !_shouldConnect) return;

    try {
      final wsUri = '$_wsUrl?token=${Uri.encodeComponent(token)}';
      _socket = await WebSocket.connect(wsUri);

      if (!_shouldConnect) {
        await _socket?.close();
        _socket = null;
        return;
      }

      _socket!.listen(
        (data) {
          if (data is! String) return;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final type = json['type'] as String? ?? '';
            final payload = (json['payload'] as Map<String, dynamic>?) ?? {};
            final wsType = switch (type) {
              'message.new' => WsEventType.messageNew,
              'message.read' => WsEventType.read,
              'typing' => WsEventType.typing,
              'presence' => WsEventType.presence,
              _ => WsEventType.unknown,
            };
            _controller.add(WsEvent(type: wsType, payload: payload));
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: false,
      );
    } catch (_) {
      _socket = null;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _socket = null;
    if (_disposed || !_shouldConnect) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 4), _connect);
  }

  void sendTyping(String conversationId, {required bool isTyping}) {
    final ws = _socket;
    if (ws == null || ws.readyState != WebSocket.open) return;
    try {
      ws.add(jsonEncode({
        'type': 'typing',
        'payload': {'conversationId': conversationId, 'isTyping': isTyping},
      }));
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _socket?.close();
    _controller.close();
  }
}

final chatWsServiceProvider = Provider<ChatWsService>((ref) {
  final service = ChatWsService(ref.read(secureStorageProvider));

  ref.listen<AsyncValue<AuthState>>(
    authRepositoryProvider,
    (_, next) {
      final state = next.asData?.value;
      if (state is AuthAuthenticated) {
        service.activate();
      } else {
        service.deactivate();
      }
    },
    fireImmediately: true,
  );

  ref.onDispose(service.dispose);
  return service;
});
