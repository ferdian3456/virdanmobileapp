import 'app_error.dart';
import 'error_mapper.dart';

/// If [error] surfaces an API error with `param`, returns `{ param: message }`.
/// Else returns null — caller should surface the error as a toast instead.
Map<String, String>? tryParseFieldErrors(Object error) {
  final mapped = mapException(error);
  return switch (mapped) {
    ApiError(:final param, :final message) when param != null && param.isNotEmpty =>
      {param: message},
    _ => null,
  };
}
