import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../server/data/server_repository.dart';
import '../../server/domain/server.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myServersProvider.notifier).fetch();
    });
  }

  void _logout() {
    ref.read(authRepositoryProvider.notifier).logout();
  }

  void _openServerSwitcher(List<Server> servers, String? activeId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in servers)
              ListTile(
                leading: _AvatarTile(server: s),
                title: Text(
                  s.name,
                  style: AppTextStyles.bodyStrong,
                ),
                trailing: s.id == activeId
                    ? const Icon(LucideIcons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(myServersProvider.notifier).setActive(s.id);
                  Navigator.pop(context);
                },
              ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(LucideIcons.plus, color: AppColors.primary),
              ),
              title: const Text(
                'Create a server',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.appCreateServer);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(LucideIcons.compass, color: AppColors.primary),
              ),
              title: const Text(
                'Explore servers',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                context.go(Routes.appExplore);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myServersProvider);
    final active = state.activeServer;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeHeader(
              active: active,
              onTapName: () => _openServerSwitcher(state.servers, state.activeServerId),
              onLogout: _logout,
            ),
            const Expanded(child: _EmptyFeed()),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.active,
    required this.onTapName,
    required this.onLogout,
  });

  final Server? active;
  final VoidCallback onTapName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTapName,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      (active?.name ?? 'SELECT SERVER').toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.16,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.send, size: 24),
            tooltip: 'Direct messages',
            onPressed: () {
              // TODO(Phase 6): chat page (mock).
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut, size: 22, color: AppColors.textSecondary),
            tooltip: 'Logout',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class _EmptyFeed extends ConsumerWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.image, size: 56, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No posts yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Be the first to post in this server!\nPost composer lands in Phase 4.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            VButton(
              label: 'Create post',
              onPressed: () {
                ref.read(toastControllerProvider.notifier).info(
                      title: 'Post composer arrives in Phase 4',
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({required this.server});

  final Server server;

  @override
  Widget build(BuildContext context) {
    final initial = (server.shortName.isNotEmpty ? server.shortName : server.name)
        .characters
        .first
        .toUpperCase();
    if (server.avatarUrl != null && server.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          server.avatarUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(initial),
        ),
      );
    }
    return _placeholder(initial);
  }

  Widget _placeholder(String initial) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColorFor(server.shortName.isNotEmpty ? server.shortName : server.name),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
