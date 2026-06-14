import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  Future<void> _onLeaveTap(Server server) async {
    String role;
    try {
      role = await ref.read(serverMembersApiProvider).getMyRole(server.id);
    } catch (e) {
      if (mounted) showApiErrorToast(ref, e);
      return;
    }
    if (!mounted) return;

    if (role == 'Owner') {
      final go = await _showOwnerLeaveDialog(server.name);
      if (go == true && mounted) {
        context.push(Routes.settingsServerMembers(server.id));
      }
      return;
    }

    final confirmed = await _showLeaveDialog(server.name);
    if (confirmed != true || !mounted) return;

    setState(() => _leaving.add(server.id));
    try {
      await ref.read(serverMembersApiProvider).leaveServer(server.id);
      if (!mounted) return;
      await ref.read(myServersProvider.notifier).fetch();
      ref.read(toastControllerProvider.notifier).success(title: 'Left ${server.name}.');
    } catch (e) {
      if (mounted) showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _leaving.remove(server.id));
    }
  }

  Future<bool?> _showLeaveDialog(String name) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog.adaptive(
          title: Text('Leave $name?'),
          content: const Text('You will stop receiving posts from this server.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Leave server'),
            ),
          ],
        ),
      );

  Future<bool?> _showOwnerLeaveDialog(String name) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog.adaptive(
          title: Text('Leave $name?'),
          content: const Text(
            'You own this server. Transfer ownership to a member first, then you can leave.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Transfer ownership'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(myServersProvider).servers;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(title: 'Servers', leading: VAppBarLeading.back),
      body: servers.isEmpty
          ? const Center(
              child: Text(
                'You have not joined any server.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : ListView.separated(
              itemCount: servers.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 72, endIndent: 16),
              itemBuilder: (_, i) {
                final s = servers[i];
                return _ServerRow(
                  server: s,
                  leaving: _leaving.contains(s.id),
                  onLeaveTap: () => _onLeaveTap(s),
                  onRowTap: () => context.push(Routes.settingsServerMembers(s.id)),
                );
              },
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _ServerAvatar(name: server.name, avatarUrl: server.avatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
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
                  if (role.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    _RoleChip(role: role),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (leaving)
              const SizedBox(
                width: 52,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: onLeaveTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url, width: 44, height: 44, fit: BoxFit.cover),
      );
    }
    final color = avatarColorFor(name);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
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
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
      case 'Admin':
        bg = const Color(0xFFE3F2FD);
        fg = AppColors.primary;
      default:
        bg = const Color(0xFFF1F3F5);
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
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
