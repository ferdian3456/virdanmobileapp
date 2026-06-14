import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/toast/toast_controller.dart';
import 'app_error.dart';
import 'error_mapper.dart';

/// Surfaces an exception as an error toast.
///
/// Pass [onRetry] ONLY for safe-to-repeat operations (GET / load). Skip for
/// mutations (POST/PUT/DELETE) — accidental double-write is worse than a
/// missing retry button.
void showApiErrorToast(WidgetRef ref, Object error, {VoidCallback? onRetry}) {
  debugPrint('[API ERROR] ${error.runtimeType}: $error');
  final mapped = mapException(error);
  String title;
  String? caption;

  switch (mapped) {
    case NetworkError():
      title = 'No internet connection';
      caption = 'Check your network and try again.';
    case TimeoutError():
      title = 'Request timed out';
      caption = 'Please try again shortly.';
    case ApiError(:final message):
      title = message.isEmpty ? 'Request failed' : message;
    case ValidationError(:final message):
      title = message;
    case UnknownError():
      title = 'Something went wrong';
      caption = 'Please try again later.';
  }

  ref
      .read(toastControllerProvider.notifier)
      .error(title: title, caption: caption, onRetry: onRetry);
}
