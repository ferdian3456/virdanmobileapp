import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_client.dart';
import '../domain/session_tokens.dart';
import '../domain/user_me.dart';

/// Thin wrapper around dio for auth endpoints. Errors propagate as DioException
/// so callers / interceptors decide how to surface them.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<({String sessionId, int otpExpiresAt})> startSignup(String email) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/signup/start',
      data: {'email': email},
    );
    final data = res.data!;
    return (
      sessionId: data['sessionId'] as String,
      otpExpiresAt: (data['otpExpiresAt'] as num).toInt(),
    );
  }

  Future<void> verifyOtp({required String sessionId, required String otp}) async {
    await _dio.post<Map<String, dynamic>>(
      '/auth/signup/otp',
      data: {'sessionId': sessionId, 'otp': otp},
    );
  }

  Future<({int otpExpiresAt})> resendOtp(String sessionId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/signup/resend-otp',
      data: {'sessionId': sessionId},
    );
    final data = res.data ?? const <String, dynamic>{};
    final expires = data['otpExpiresAt'];
    return (otpExpiresAt: expires is num ? expires.toInt() : 0);
  }

  /// Returns the current step value: `start_signup`, `otp_verified`,
  /// `password_set`, or throws on 404 / expired session.
  Future<String> getSignupStatus(String sessionId) async {
    final res = await _dio.get<Map<String, dynamic>>('/auth/signup/$sessionId/status');
    return (res.data?['step'] as String?) ?? '';
  }

  Future<SessionTokens> setPassword({
    required String sessionId,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/signup/password',
      data: {'sessionId': sessionId, 'password': password},
    );
    return SessionTokens.fromJson(res.data!);
  }

  Future<SessionTokens> login({required String email, required String password}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return SessionTokens.fromJson(res.data!);
  }

  Future<void> logout() async {
    await _dio.post<Map<String, dynamic>>('/users/logout');
  }

  Future<UserMe> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me');
    return UserMe.fromJson(res.data!);
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.read(apiDioProvider));
});
