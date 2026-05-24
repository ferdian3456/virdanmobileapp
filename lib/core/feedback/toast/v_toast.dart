import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'toast_controller.dart';

const _bubbleSuccessInfo = AppColors.primary;
const _bubbleWarning = Color(0xFFF59E0B);
const _bubbleError = Color(0xFFEF4444);
const _cardBorder = Color(0xFFEEF0F4);
const _errorBorderTint = Color(0x47EF4444);
const _retryBg = Color(0x1AEF4444);
const _retryFg = Color(0xFFEF4444);
const _toastShadow = Color(0x1F14142B);
const _toastTitle = Color(0xFF14142B);
const _toastCaption = Color(0xFF9B9DB0);

class VToast extends StatefulWidget {
  const VToast({super.key, required this.toast, required this.onDismiss});

  final ToastModel toast;
  final VoidCallback onDismiss;

  @override
  State<VToast> createState() => _VToastState();
}

class _VToastState extends State<VToast> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    if (widget.toast.type != ToastType.error) return;
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      final disable = MediaQuery.of(context).disableAnimations;
      if (!disable) _shake.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Color get _bubbleColor {
    switch (widget.toast.type) {
      case ToastType.success:
      case ToastType.info:
        return _bubbleSuccessInfo;
      case ToastType.warning:
        return _bubbleWarning;
      case ToastType.error:
        return _bubbleError;
    }
  }

  IconData get _icon {
    switch (widget.toast.type) {
      case ToastType.success:
        return LucideIcons.check;
      case ToastType.error:
        return LucideIcons.x;
      case ToastType.warning:
        return LucideIcons.triangleAlert;
      case ToastType.info:
        return LucideIcons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.toast.type == ToastType.error;

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onDismiss,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isError ? _errorBorderTint : _cardBorder),
              boxShadow: const [
                BoxShadow(color: _toastShadow, offset: Offset(0, 8), blurRadius: 24),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bubble(color: _bubbleColor, icon: _icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.toast.title,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _toastTitle,
                          letterSpacing: -0.13,
                          height: 1.3,
                        ),
                      ),
                      if (widget.toast.caption != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.toast.caption!,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: _toastCaption,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isError && widget.toast.onRetry != null) ...[
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.center,
                    child: _RetryPill(
                      onTap: () {
                        widget.toast.onRetry!();
                        widget.onDismiss();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final dismissible = Dismissible(
      key: ValueKey(widget.toast.id),
      direction: DismissDirection.up,
      onDismissed: (_) => widget.onDismiss(),
      child: card,
    );

    if (!isError) return dismissible;

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final v = _shake.value;
        // 4 oscillations across the 500ms run, peak amplitude 4px.
        final dx = v == 0 ? 0.0 : 4 * math.sin(v * 8 * math.pi);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: dismissible,
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}

class _RetryPill extends StatelessWidget {
  const _RetryPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _retryBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Try again',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _retryFg,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }
}
