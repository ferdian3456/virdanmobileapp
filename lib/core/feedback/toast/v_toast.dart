import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'toast_controller.dart';

class VToast extends StatelessWidget {
  const VToast({
    super.key,
    required this.toast,
    required this.onDismiss,
  });

  final ToastModel toast;
  final VoidCallback onDismiss;

  _ToastStyle get _style {
    switch (toast.type) {
      case ToastType.success:
        return const _ToastStyle(
          icon: LucideIcons.circleCheck,
          background: Color(0xFFE6F6EA),
          foreground: AppColors.success,
          border: Color(0xFF9FD9AE),
        );
      case ToastType.error:
        return const _ToastStyle(
          icon: LucideIcons.circleX,
          background: Color(0xFFFBE7E9),
          foreground: AppColors.error,
          border: Color(0xFFEBA0A8),
        );
      case ToastType.warning:
        return const _ToastStyle(
          icon: LucideIcons.triangleAlert,
          background: Color(0xFFFFF6E0),
          foreground: Color(0xFFAD7B00),
          border: Color(0xFFE8C865),
        );
      case ToastType.info:
        return const _ToastStyle(
          icon: LucideIcons.info,
          background: Color(0xFFE3F2F5),
          foreground: AppColors.info,
          border: Color(0xFF9FCFD8),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Dismissible(
      key: ValueKey(toast.id),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onDismiss,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: style.border),
              boxShadow: AppElevation.card,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(style.icon, color: style.foreground, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        toast.title,
                        style: AppTextStyles.bodyStrong.copyWith(color: style.foreground),
                      ),
                      if (toast.caption != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          toast.caption!,
                          style: AppTextStyles.caption.copyWith(color: style.foreground),
                        ),
                      ],
                    ],
                  ),
                ),
                if (toast.onRetry != null)
                  TextButton(
                    onPressed: () {
                      toast.onRetry!();
                      onDismiss();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: style.foreground,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    ),
                    child: Text(
                      'Coba lagi',
                      style: AppTextStyles.captionStrong.copyWith(color: style.foreground),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastStyle {
  const _ToastStyle({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;
}
