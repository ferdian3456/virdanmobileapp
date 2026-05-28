import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_client.dart';

class AccountApi {
  AccountApi(this._dio);

  final Dio _dio;

  Future<void> verifyCurrentPassword(String password) async {
    await _dio.post<Map<String, dynamic>>(
      '/users/password/verify',
      data: {'password': password},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.put<Map<String, dynamic>>(
      '/users/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> requestEmailChange(String newEmail) async {
    await _dio.post<Map<String, dynamic>>(
      '/users/email/change/request',
      data: {'newEmail': newEmail},
    );
  }

  Future<void> confirmEmailChange(String otp) async {
    await _dio.post<Map<String, dynamic>>(
      '/users/email/change/confirm',
      data: {'otp': otp},
    );
  }
}

final accountApiProvider = Provider<AccountApi>((ref) {
  return AccountApi(ref.read(apiDioProvider));
});
