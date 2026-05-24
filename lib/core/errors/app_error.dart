/// Top-level error type for the app. Use sealed pattern matching at call sites.
sealed class AppError implements Exception {
  const AppError({required this.message, this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType($code): $message';
}

class NetworkError extends AppError {
  const NetworkError({super.message = 'No internet connection', super.cause})
      : super(code: 'NETWORK');
}

class TimeoutError extends AppError {
  const TimeoutError({super.message = 'Request timed out. Please try again', super.cause})
      : super(code: 'TIMEOUT');
}

class ApiError extends AppError {
  const ApiError({
    required super.message,
    required int statusCode,
    super.code,
    this.param,
    super.cause,
  }) : _statusCode = statusCode;

  final int _statusCode;
  final String? param;

  int get statusCode => _statusCode;
}

class ValidationError extends AppError {
  const ValidationError({required super.message, this.fields, super.cause})
      : super(code: 'VALIDATION');

  final Map<String, String>? fields;
}

class UnknownError extends AppError {
  const UnknownError({super.message = 'Something went wrong. Please try again later', super.cause})
      : super(code: 'UNKNOWN');
}
