import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum VButtonVariant { primary, secondary, ghost, destructive, outline }

enum VButtonSize { sm, md, lg }

class VButton extends StatelessWidget {
  const VButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = VButtonVariant.primary,
    this.size = VButtonSize.md,
    this.loading = false,
    this.loadingLabel,
    this.leading,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final VButtonVariant variant;
  final VButtonSize size;
  final bool loading;
  final String? loadingLabel;
  final Widget? leading;
  final bool fullWidth;

  bool get _disabled => onPressed == null || loading;

  double get _height {
    switch (size) {
      case VButtonSize.sm:
        return 36;
      case VButtonSize.md:
        return 44;
      case VButtonSize.lg:
        return 48;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case VButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md);
      case VButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.lg);
      case VButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.xl);
    }
  }

  double get _fontSize {
    switch (size) {
      case VButtonSize.sm:
        return 14;
      case VButtonSize.md:
        return 15;
      case VButtonSize.lg:
        return 16;
    }
  }

  _ButtonStyle get _style {
    switch (variant) {
      case VButtonVariant.primary:
        return const _ButtonStyle(
          background: AppColors.primary,
          foreground: AppColors.textOnPrimary,
        );
      case VButtonVariant.secondary:
        return const _ButtonStyle(
          background: AppColors.surface,
          foreground: AppColors.primary,
          border: AppColors.border,
        );
      case VButtonVariant.ghost:
        return const _ButtonStyle(
          background: Colors.transparent,
          foreground: AppColors.primary,
        );
      case VButtonVariant.destructive:
        return const _ButtonStyle(
          background: AppColors.error,
          foreground: AppColors.textOnPrimary,
        );
      case VButtonVariant.outline:
        return const _ButtonStyle(
          background: Colors.transparent,
          foreground: AppColors.primary,
          border: AppColors.primary,
          borderWidth: 1.5,
        );
    }
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final effectiveOpacity = _disabled ? 0.4 : 1.0;
    final radius = BorderRadius.circular(AppRadius.lg);

    final child = loading
        ? _LoadingContent(
            label: loadingLabel ?? label,
            foreground: style.foreground,
            fontSize: _fontSize,
          )
        : _LabelContent(
            label: label,
            leading: leading,
            foreground: style.foreground,
            fontSize: _fontSize,
          );

    final button = Opacity(
      opacity: effectiveOpacity,
      child: Material(
        color: style.background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: _disabled ? null : _handleTap,
          child: Container(
            height: _height,
            padding: _padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: style.border != null
                  ? Border.all(color: style.border!, width: style.borderWidth)
                  : null,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _ButtonStyle {
  const _ButtonStyle({
    required this.background,
    required this.foreground,
    this.border,
    this.borderWidth = 1,
  });

  final Color background;
  final Color foreground;
  final Color? border;
  final double borderWidth;
}

class _LabelContent extends StatelessWidget {
  const _LabelContent({
    required this.label,
    required this.leading,
    required this.foreground,
    required this.fontSize,
  });

  final String label;
  final Widget? leading;
  final Color foreground;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          IconTheme(
            data: IconThemeData(color: foreground, size: fontSize + 2),
            child: leading!,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          label,
          style: AppTextStyles.button.copyWith(color: foreground, fontSize: fontSize),
        ),
      ],
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent({
    required this.label,
    required this.foreground,
    required this.fontSize,
  });

  final String label;
  final Color foreground;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(foreground),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTextStyles.button.copyWith(color: foreground, fontSize: fontSize),
        ),
      ],
    );
  }
}
