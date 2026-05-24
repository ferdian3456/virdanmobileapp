import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class VEmptyState extends StatelessWidget {
  const VEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.cta,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? cta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (cta != null) ...[
              const SizedBox(height: AppSpacing.xl),
              cta!,
            ],
          ],
        ),
      ),
    );
  }
}
