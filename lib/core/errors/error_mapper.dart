import 'dart:io';

import 'package:dio/dio.dart';

import 'app_error.dart';

/// Converts low-level errors (Dio, Socket, etc) into AppError sealed types.
AppError mapException(Object error, [StackTrace? stack]) {
  if (error is AppError) return error;

  if (error is DioException) {
    final type = error.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return TimeoutError(cause: error);
    }
    if (type == DioExceptionType.connectionError ||
        error.error is SocketException) {
      return NetworkError(cause: error);
    }

    final response = error.response;
    if (response != null) {
      final body = response.data;
      final statusCode = response.statusCode ?? 0;
      String message = 'Request failed (HTTP $statusCode)';
      String? code;
      String? param;

      if (body is Map<String, dynamic> && body['error'] is Map) {
        final inner = body['error'] as Map<String, dynamic>;
        message = (inner['message'] as String?) ?? message;
        code = inner['code'] as String?;
        param = inner['param'] as String?;
      } else if (body is String && body.isNotEmpty) {
        message = body;
      }

      return ApiError(
        message: message,
        statusCode: statusCode,
        code: code,
        param: param,
        cause: error,
      );
    }
  }

  if (error is SocketException) {
    return NetworkError(cause: error);
  }

  return UnknownError(cause: error);
}
