import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../data/server_members_api.dart';
import '../data/server_repository.dart';
import '../domain/server.dart';

class ServersPage extends ConsumerStatefulWidget {
  const ServersPage({super.key});

  @override
  ConsumerState<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends ConsumerState<ServersPage> {
  final Set<String> _leaving = {};

  Future<void> _refresh() async {
    try {
      await ref.read(myServersProvider.notifier).fetch(force: true);
    } catch (e) {
      if (mounted) showApiErrorToast(ref, e);
    }
  }

  Future<void> _onLeaveTap(Server server) async {
    String role;
    try {
      role = await ref.read(serverMembersApiProvider).getMyRole(server.id);
    } catch (e) {
      if (mounted) showApiErrorToast(ref, e);
      return;
    }
    if (!mounted) return;

    final isOwner = role == 'Owner';
    final alone = server.memberCount <= 1;

    // Owner with other members: must transfer ownership first. Send them to the
    // member picker in transfer mode (tap a member -> transfer + leave).
    if (isOwner && !alone) {
      final go = await _showLeaveSheet(server.name, isOwner: true, ownerAlone: false);
      if (go == true && mounted) {
        // Await the picker so the list reflects the transfer/leave on return.
        await context.push(Routes.settingsServerMembers(server.id, transfer: true));
        if (mounted) await ref.read(myServersProvider.notifier).fetch(force: true);
      }
      return;
    }

    // Non-owner leave, or sole-owner leave (the backend deletes the now-empty
    // server in that case).
    final confirmed = await _showLeaveSheet(
      server.name,
      isOwner: isOwner,
      ownerAlone: isOwner && alone,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _leaving.add(server.id));
    try {
      await ref.read(serverMembersApiProvider).leaveServer(server.id);
      if (!mounted) return;
      await ref.read(myServersProvider.notifier).fetch(force: true);
      ref.read(toastControllerProvider.notifier).success(
            title: isOwner && alone ? '${server.name} deleted.' : 'Left ${server.name}.',
          );
    } catch (e) {
      if (mounted) showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _leaving.remove(server.id));
    }
  }

  Future<bool?> _showLeaveSheet(
    String name, {
    required bool isOwner,
    bool ownerAlone = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.logOut, size: 26, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              Text(
                'Leave $name?',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                ownerAlone
                    ? "You're the only member. Leaving permanently deletes this server and all of its posts."
                    : isOwner
                        ? 'You own this server. Leaving will prompt you to transfer ownership first.'
                        : "You'll stop receiving posts and need to rejoin to access it again.",
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    ownerAlone ? 'Delete server' : 'Leave server',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(myServersProvider).servers;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(title: 'Servers', leading: VAppBarLeading.back),
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        child: servers.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(
                  child: Text(
                    'You have not joined any server.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: servers.length + 1,
              separatorBuilder: (_, i) => i == 0
                  ? const SizedBox.shrink()
                  : const Divider(height: 1, color: Color(0xFFF1F3F5)),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Text(
                      'Communities you\'ve joined. Tap a server to manage members, or leave anytime.',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  );
                }
                final s = servers[i - 1];
                return _ServerRow(
                  server: s,
                  leaving: _leaving.contains(s.id),
                  onLeaveTap: () => _onLeaveTap(s),
                  onRowTap: () => context.push(Routes.settingsServerMembers(s.id)),
                );
              },
            ),
      ),
    );
  }
}

class _ServerRow extends ConsumerWidget {
  const _ServerRow({
    required this.server,
    required this.leaving,
    required this.onLeaveTap,
    required this.onRowTap,
  });

  final Server server;
  final bool leaving;
  final VoidCallback onLeaveTap;
  final VoidCallback onRowTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(myRoleInServerProvider(server.id));
    final role = roleAsync.asData?.value ?? '';
    return InkWell(
      onTap: onRowTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _ServerAvatar(name: server.name, avatarUrl: server.avatarUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          server.name,
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
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.badgeCheck,
                          size: 15, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (role.isNotEmpty) ...[
                        _RoleChip(role: role),
                        const SizedBox(width: 6),
                        const Text(
                          '·',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        '${server.memberCount} member${server.memberCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (leaving)
              const SizedBox(
                width: 64,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              OutlinedButton(
                onPressed: onLeaveTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Leave'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServerAvatar extends StatelessWidget {
  const _ServerAvatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(url, width: 48, height: 48, fit: BoxFit.cover),
      );
    }
    final color = avatarColorFor(name);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (role) {
      case 'Owner':
        bg = AppColors.primary;
        fg = Colors.white;
      case 'Admin':
        bg = Colors.transparent;
        fg = const Color(0xFFD97706);
      default:
        bg = Colors.transparent;
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
