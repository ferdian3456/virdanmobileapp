import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../auth/data/auth_repository.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const VAppBar(title: 'Settings', leading: VAppBarLeading.back),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          _Tile(
            icon: LucideIcons.atSign,
            label: 'Change email',
            onTap: () => context.push('/settings/email'),
          ),
          _Tile(
            icon: LucideIcons.lock,
            label: 'Change password',
            onTap: () => context.push('/settings/password'),
          ),
          _Tile(
            icon: LucideIcons.bellRing,
            label: 'Notifications',
            onTap: () => context.push('/settings/notifications'),
          ),
          _Tile(
            icon: LucideIcons.shieldCheck,
            label: 'Privacy & security',
            onTap: () => context.push('/settings/privacy'),
          ),
          const _SectionHeader('Support'),
          _Tile(
            icon: LucideIcons.circleHelp,
            label: 'Help center',
            onTap: () => context.push('/settings/help'),
          ),
          _Tile(
            icon: LucideIcons.fileText,
            label: 'Terms of service',
            onTap: () => context.push('/settings/terms'),
          ),
          _Tile(
            icon: LucideIcons.scroll,
            label: 'Privacy policy',
            onTap: () => context.push('/settings/privacy-policy'),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await ref.read(authRepositoryProvider.notifier).logout();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'Log out',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.micro.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, size: 22, color: AppColors.textPrimary),
        title: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textTertiary),
        onTap: onTap,
      ),
    );
  }
}
