import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'toast_controller.dart';
import 'v_toast.dart';

/// Mount once at the root (above MaterialApp builder) so toasts can be shown
/// from anywhere via `ref.read(toastControllerProvider.notifier)`.
class ToastHost extends ConsumerStatefulWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends ConsumerState<ToastHost> {
  final Map<String, Timer> _timers = {};

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  void _scheduleAutoDismiss(List<ToastModel> toasts) {
    final ids = toasts.map((t) => t.id).toSet();
    _timers.removeWhere((id, timer) {
      if (!ids.contains(id)) {
        timer.cancel();
        return true;
      }
      return false;
    });

    for (final toast in toasts) {
      if (_timers.containsKey(toast.id)) continue;
      _timers[toast.id] = Timer(toast.effectiveDuration, () {
        if (!mounted) return;
        ref.read(toastControllerProvider.notifier).dismiss(toast.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final toasts = ref.watch(toastControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoDismiss(toasts));

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).viewPadding.top + 70,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: toasts.isEmpty,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final toast in toasts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) {
                          final slide = Tween<Offset>(
                            begin: const Offset(0, -0.12),
                            end: Offset.zero,
                          ).animate(anim);
                          return SlideTransition(
                            position: slide,
                            child: FadeTransition(opacity: anim, child: child),
                          );
                        },
                        child: VToast(
                          key: ValueKey(toast.id),
                          toast: toast,
                          onDismiss: () =>
                              ref.read(toastControllerProvider.notifier).dismiss(toast.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
