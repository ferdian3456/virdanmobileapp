import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/v_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';

/// Phase 5 placeholder. Full profile (per-server identity grid, posts) ships
/// in Phase 5.
class YourProfilePage extends ConsumerWidget {
  const YourProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = switch (ref.watch(authRepositoryProvider)) {
      AsyncData(value: AuthAuthenticated(:final user)) => user.email,
      _ => '',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.circleUser, size: 80, color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                email,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Per-server identity grid lands in Phase 5.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              VButton(
                label: 'Logout',
                variant: VButtonVariant.destructive,
                onPressed: () => ref.read(authRepositoryProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
