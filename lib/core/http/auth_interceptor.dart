import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';

/// Adds Authorization header + handles refresh-on-401 (single in-flight, retry once).
///
/// Phase 0 stub: refresh logic wired but actual `/auth/refresh` call shape is
/// pending Phase 1 (auth feature implementation). Treats 401 as terminal here.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._dio, this._refreshDio);

  final SecureStorage _storage;
  final Dio _dio;
  final Dio _refreshDio;

  Completer<void>? _refreshCompleter;

  static const _retriedKey = 'auth_retried';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) return handler.next(err);
    if (err.requestOptions.extra[_retriedKey] == true) return handler.next(err);

    final refreshed = await _refreshToken();
    if (!refreshed) {
      await _storage.clear();
      return handler.next(err);
    }

    final req = err.requestOptions;
    req.extra[_retriedKey] = true;
    final accessToken = await _storage.readAccessToken();
    if (accessToken != null) {
      req.headers['Authorization'] = 'Bearer $accessToken';
    }

    try {
      final response = await _dio.fetch<dynamic>(req);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<bool> _refreshToken() async {
    if (_refreshCompleter != null) {
      try {
        await _refreshCompleter!.future;
        return true;
      } catch (_) {
        return false;
      }
    }

    final completer = _refreshCompleter = Completer<void>();
    try {
      final refresh = await _storage.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        throw StateError('no refresh token');
      }
      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = res.data;
      if (data == null) throw StateError('empty refresh response');
      await _storage.writeTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      completer.complete();
      return true;
    } catch (e, st) {
      completer.completeError(e, st);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
}
