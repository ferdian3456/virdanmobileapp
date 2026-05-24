import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';

enum ToastType { success, error, warning, info }

@immutable
class ToastModel {
  const ToastModel({
    required this.id,
    required this.type,
    required this.title,
    this.caption,
    this.duration,
    this.onRetry,
  });

  final String id;
  final ToastType type;
  final String title;
  final String? caption;
  final Duration? duration;
  final VoidCallback? onRetry;

  Duration get effectiveDuration {
    if (duration != null) return duration!;
    switch (type) {
      case ToastType.error:
        return AppMotion.toastError;
      case ToastType.warning:
        return AppMotion.toastWarning;
      case ToastType.success:
      case ToastType.info:
        return AppMotion.toast;
    }
  }
}

class ToastController extends Notifier<List<ToastModel>> {
  static const _maxStack = 3;
  int _seq = 0;

  @override
  List<ToastModel> build() => const [];

  String _nextId() => 'toast_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  void _push(ToastModel toast) {
    final next = [...state, toast];
    state = next.length > _maxStack ? next.sublist(next.length - _maxStack) : next;
  }

  void dismiss(String id) {
    state = state.where((t) => t.id != id).toList(growable: false);
  }

  void clear() {
    state = const [];
  }

  void success({required String title, String? caption}) {
    _push(ToastModel(id: _nextId(), type: ToastType.success, title: title, caption: caption));
  }

  void error({required String title, String? caption, VoidCallback? onRetry}) {
    _push(ToastModel(
      id: _nextId(),
      type: ToastType.error,
      title: title,
      caption: caption,
      onRetry: onRetry,
    ));
  }

  void warning({required String title, String? caption}) {
    _push(ToastModel(id: _nextId(), type: ToastType.warning, title: title, caption: caption));
  }

  void info({required String title, String? caption}) {
    _push(ToastModel(id: _nextId(), type: ToastType.info, title: title, caption: caption));
  }
}

final toastControllerProvider =
    NotifierProvider<ToastController, List<ToastModel>>(ToastController.new);
