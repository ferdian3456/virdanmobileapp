import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum VProgressRingMode { inline, overlay }

/// Determinate progress indicator. Used for measurable uploads/multi-step ops.
class VProgressRing extends StatelessWidget {
  const VProgressRing({
    super.key,
    required this.progress,
    this.mode = VProgressRingMode.inline,
    this.label,
    this.size = 56,
  }) : assert(progress >= 0 && progress <= 1);

  final double progress;
  final VProgressRingMode mode;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ring = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: AppColors.surface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: AppTextStyles.captionStrong,
          ),
        ],
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ring,
        if (label != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            label!,
            style: AppTextStyles.caption.copyWith(
              color: mode == VProgressRingMode.overlay ? Colors.white : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (mode == VProgressRingMode.inline) {
      return content;
    }

    return ColoredBox(
      color: const Color(0x66000000),
      child: Center(child: content),
    );
  }
}
