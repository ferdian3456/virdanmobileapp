import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../../mocks/notifications_mock.dart';

/// Phase 6 mock (BE-09 — backend notifications endpoint pending).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Activity'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: ListView.separated(
        itemCount: mockNotifications.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (_, i) {
          final n = mockNotifications[i];
          final initial = n.actorNickname.isNotEmpty
              ? n.actorNickname.characters.first.toUpperCase()
              : '?';
          return ListTile(
            leading: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: avatarColorFor(n.actorNickname),
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            title: RichText(
              text: TextSpan(
                style: AppTextStyles.body
                    .copyWith(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                children: [
                  TextSpan(
                    text: '${n.actorNickname} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: n.action),
                  if (n.target.isNotEmpty) ...[
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: n.target,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
            subtitle: Text(
              n.timeAgo,
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
            trailing: const Icon(LucideIcons.heart,
                size: 18, color: AppColors.textTertiary),
          );
        },
      ),
    );
  }
}
