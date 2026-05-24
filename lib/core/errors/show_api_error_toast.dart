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
  final mapped = mapException(error);
  String title;
  String? caption;

  switch (mapped) {
    case NetworkError():
      title = 'Tidak ada koneksi';
      caption = 'Periksa internet kamu lalu coba lagi.';
    case TimeoutError():
      title = 'Permintaan terlalu lama';
      caption = 'Coba lagi sebentar.';
    case ApiError(:final message):
      title = message.isEmpty ? 'Permintaan gagal' : message;
    case ValidationError(:final message):
      title = message;
    case UnknownError():
      title = 'Terjadi kesalahan';
      caption = 'Coba lagi nanti.';
  }

  ref
      .read(toastControllerProvider.notifier)
      .error(title: title, caption: caption, onRetry: onRetry);
}
