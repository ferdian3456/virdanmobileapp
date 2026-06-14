import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/show_api_error_toast.dart';
import '../../../../core/feedback/toast/toast_controller.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/util/avatar_color.dart';
import '../../data/server_members_api.dart';
import '../../domain/server_member.dart';

/// Shows the appropriate action bottom sheet for a member row.
/// Returns true if any mutation occurred (caller should reload list).
Future<bool> showMemberActionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String serverId,
  required ServerMember target,
  required String viewerRole,
  required String currentUserId,
}) async {
  assert(target.userId != currentUserId);
  if (target.isAdmin && viewerRole == 'Owner') {
    return _showAdminSheet(context, ref, serverId, target);
  }
  if (target.isMember) {
    return _showMemberSheet(context, ref, serverId, target, viewerRole);
  }
  return false;
}

Future<bool> _showAdminSheet(
  BuildContext context,
  WidgetRef ref,
  String serverId,
  ServerMember target,
) async {
  var changed = false;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(member: target, role: 'Admin'),
          _SheetRow(
            icon: LucideIcons.crown,
            label: 'Make Owner',
            color: AppColors.primary,
            onTap: () async {
              Navigator.pop(ctx);
              final confirmed = await _confirmDialog(
                context,
                title: 'Transfer ownership to ${target.nickname}?',
                message: 'You will become Admin. This cannot be undone.',
                actionLabel: 'Transfer',
              );
              if (!confirmed || !context.mounted) return;
              try {
                await ref
                    .read(serverMembersApiProvider)
                    .transferOwnership(serverId, target.userId);
                ref
                    .read(toastControllerProvider.notifier)
                    .success(title: 'Ownership transferred to ${target.nickname}.');
                changed = true;
              } catch (e) {
                if (context.mounted) showApiErrorToast(ref, e);
              }
            },
          ),
          _SheetRow(
            icon: LucideIcons.shieldOff,
            label: 'Remove admin role',
            color: const Color(0xFF0F172A),
            onTap: () async {
              Navigator.pop(ctx);
              final confirmed = await _confirmDialog(
                context,
                title: 'Remove admin role?',
                message: '${target.nickname} will become a regular member.',
                actionLabel: 'Remove',
              );
              if (!confirmed || !context.mounted) return;
              try {
                await ref
                    .read(serverMembersApiProvider)
                    .updateRole(serverId, target.userId, 'Member');
                ref
                    .read(toastControllerProvider.notifier)
                    .success(title: 'Admin role removed from ${target.nickname}.');
                changed = true;
              } catch (e) {
                if (context.mounted) showApiErrorToast(ref, e);
              }
            },
          ),
          _SheetRow(
            icon: LucideIcons.user,
            label: 'View profile',
            color: const Color(0xFF0F172A),
            onTap: () {
              Navigator.pop(ctx);
              context.push(Routes.userProfile(serverId, target.userId));
            },
          ),
          _SheetRow(
            icon: LucideIcons.userX,
            label: 'Remove from server',
            color: AppColors.error,
            onTap: () async {
              Navigator.pop(ctx);
              final confirmed = await _confirmDialog(
                context,
                title: 'Remove ${target.nickname}?',
                message: '${target.nickname} will lose access to this server.',
                actionLabel: 'Remove',
              );
              if (!confirmed || !context.mounted) return;
              try {
                await ref.read(serverMembersApiProvider).kickMember(serverId, target.userId);
                ref
                    .read(toastControllerProvider.notifier)
                    .success(title: '${target.nickname} removed from server.');
                changed = true;
              } catch (e) {
                if (context.mounted) showApiErrorToast(ref, e);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  return changed;
}

Future<bool> _showMemberSheet(
  BuildContext context,
  WidgetRef ref,
  String serverId,
  ServerMember target,
  String viewerRole,
) async {
  var changed = false;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(member: target, role: 'Member'),
          if (viewerRole == 'Owner')
            _SheetRow(
              icon: LucideIcons.shield,
              label: 'Promote to Admin',
              color: AppColors.primary,
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmDialog(
                  context,
                  title: 'Promote ${target.nickname} to Admin?',
                  message: 'Admins can remove members from this server.',
                  actionLabel: 'Promote',
                );
                if (!confirmed || !context.mounted) return;
                try {
                  await ref
                      .read(serverMembersApiProvider)
                      .updateRole(serverId, target.userId, 'Admin');
                  ref
                      .read(toastControllerProvider.notifier)
                      .success(title: '${target.nickname} is now Admin.');
                  changed = true;
                } catch (e) {
                  if (context.mounted) showApiErrorToast(ref, e);
                }
              },
            ),
          _SheetRow(
            icon: LucideIcons.user,
            label: 'View profile',
            color: const Color(0xFF0F172A),
            onTap: () {
              Navigator.pop(ctx);
              context.push(Routes.userProfile(serverId, target.userId));
            },
          ),
          _SheetRow(
            icon: LucideIcons.userX,
            label: 'Remove from server',
            color: AppColors.error,
            onTap: () async {
              Navigator.pop(ctx);
              final confirmed = await _confirmDialog(
                context,
                title: 'Remove ${target.nickname}?',
                message: '${target.nickname} will lose access to this server.',
                actionLabel: 'Remove',
              );
              if (!confirmed || !context.mounted) return;
              try {
                await ref.read(serverMembersApiProvider).kickMember(serverId, target.userId);
                ref
                    .read(toastControllerProvider.notifier)
                    .success(title: '${target.nickname} removed from server.');
                changed = true;
              } catch (e) {
                if (context.mounted) showApiErrorToast(ref, e);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  return changed;
}

Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.member, required this.role});

  final ServerMember member;
  final String role;

  @override
  Widget build(BuildContext context) {
    final url = member.avatarUrl;
    Widget avatar;
    if (url != null && url.isNotEmpty) {
      avatar = CircleAvatar(radius: 20, backgroundImage: NetworkImage(url));
    } else {
      avatar = CircleAvatar(
        radius: 20,
        backgroundColor: avatarColorFor(member.nickname),
        child: Text(
          member.nickname.isNotEmpty ? member.nickname[0].toUpperCase() : '?',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    Color chipBg;
    Color chipFg;
    switch (role) {
      case 'Admin':
        chipBg = const Color(0xFFFFF8E1);
        chipFg = const Color(0xFFD97706);
      default:
        chipBg = const Color(0xFFF1F3F5);
        chipFg = AppColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.nickname,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: chipFg,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '@${member.username}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
