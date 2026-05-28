import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/v_app_bar.dart';

class PrivacySecurityPage extends StatelessWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const VAppBar(title: 'Privacy & security', leading: VAppBarLeading.back),
      body: ListView(
        children: const [
          _Tile(icon: LucideIcons.userMinus, label: 'Blocked accounts'),
          _Tile(icon: LucideIcons.eyeOff, label: 'Hidden words'),
          _Tile(icon: LucideIcons.shieldAlert, label: 'Report a problem'),
          _Tile(icon: LucideIcons.smartphone, label: 'Active sessions'),
          _Tile(icon: LucideIcons.trash2, label: 'Delete account', destructive: true),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, this.destructive = false});

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(
          icon,
          size: 22,
          color: destructive ? AppColors.error : AppColors.textPrimary,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: destructive ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textTertiary),
        onTap: () {},
      ),
    );
  }
}
