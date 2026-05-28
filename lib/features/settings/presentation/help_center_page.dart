import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/v_app_bar.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const VAppBar(title: 'Help center', leading: VAppBarLeading.back),
      body: ListView(
        children: const [
          _Tile(icon: LucideIcons.circleHelp, label: 'Getting started'),
          _Tile(icon: LucideIcons.users, label: 'Managing servers'),
          _Tile(icon: LucideIcons.shield, label: 'Account & security'),
          _Tile(icon: LucideIcons.messageSquareWarning, label: 'Report content'),
          _Tile(icon: LucideIcons.mail, label: 'Contact support'),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label});

  final IconData icon;
  final String label;

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
        onTap: () {},
      ),
    );
  }
}
