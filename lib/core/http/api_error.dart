/// Mirrors backend error envelope `{ error: { code, message, param? } }`.
class ApiErrorEnvelope {
  const ApiErrorEnvelope({required this.code, required this.message, this.param});

  factory ApiErrorEnvelope.fromJson(Map<String, dynamic> json) {
    final error = json['error'];
    if (error is! Map<String, dynamic>) {
      return const ApiErrorEnvelope(code: 'UNKNOWN', message: 'Unknown error');
    }
    return ApiErrorEnvelope(
      code: (error['code'] as String?) ?? 'UNKNOWN',
      message: (error['message'] as String?) ?? 'Unknown error',
      param: error['param'] as String?,
    );
  }

  final String code;
  final String message;
  final String? param;
}
