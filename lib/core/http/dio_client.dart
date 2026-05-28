import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';

/// Default API base URL. Override via `--dart-define=API_URL=...` at build time.
const _defaultApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://ungrating-bo-argumentatively.ngrok-free.dev/api',
);

/// Bare Dio used only by the refresh call itself — no auth interceptor to
/// prevent recursive 401 loops.
final _refreshDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: _defaultApiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Content-Type': 'application/json'},
  ));
});

/// Authenticated Dio for all app API calls.
final apiDioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _defaultApiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Content-Type': 'application/json'},
  ));

  final storage = ref.read(secureStorageProvider);
  final refreshDio = ref.read(_refreshDioProvider);

  dio.interceptors.add(AuthInterceptor(storage, dio, refreshDio));

  return dio;
});
