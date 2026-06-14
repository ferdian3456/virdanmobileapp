import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';

/// Default API base URL. Points to production. Override via `--dart-define=API_URL=...` at build time.
/// Local dev: flutter run --dart-define=API_URL=http://<LAN-IP>:8081/api
const _defaultApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://virdan.cloud/api',
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
  dio.interceptors.add(_LogInterceptor());

  return dio;
});

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[HTTP] ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[HTTP] ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[HTTP ERROR] ${err.response?.statusCode} ${err.requestOptions.path} — ${err.response?.data}',
    );
    handler.next(err);
  }
}
