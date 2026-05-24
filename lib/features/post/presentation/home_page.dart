import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/feedback/v_skeleton.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../server/data/server_repository.dart';
import '../../server/domain/server.dart';
import '../data/server_feed_provider.dart';
import 'widgets/post_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(myServersProvider.notifier).fetch();
      final id = ref.read(myServersProvider).activeServerId;
      if (id != null && mounted) {
        ref.read(serverFeedProvider.notifier).loadFor(id);
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(serverFeedProvider.notifier).loadMore();
    }
  }

  Future<void> _refreshFeed() async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(serverFeedProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(
        ref,
        e,
        onRetry: () => ref.read(serverFeedProvider.notifier).refresh(),
      );
    }
  }

  Future<void> _toggleLike(String postId) async {
    try {
      await ref.read(serverFeedProvider.notifier).toggleLike(postId);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    }
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
                title: Text(s.name, style: AppTextStyles.bodyStrong),
                trailing: s.id == activeId
                    ? const Icon(LucideIcons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(myServersProvider.notifier).setActive(s.id);
                  ref.read(serverFeedProvider.notifier).loadFor(s.id);
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
    final activeId = active?.id;

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
            Expanded(
              child: activeId == null
                  ? const _NoServerState()
                  : _FeedBody(
                      scroll: _scroll,
                      onRefresh: _refreshFeed,
                      onLikeTap: _toggleLike,
                    ),
            ),
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
              // TODO(Phase 6 mock): chat list.
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

class _FeedBody extends ConsumerWidget {
  const _FeedBody({
    required this.scroll,
    required this.onRefresh,
    required this.onLikeTap,
  });

  final ScrollController scroll;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onLikeTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(serverFeedProvider);

    if (feed.isLoading && feed.posts.isEmpty) {
      return const _FeedSkeleton();
    }
    if (feed.hasError && feed.posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.wifiOff, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Failed to load posts',
                style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.lg),
              VButton(label: 'Try again', onPressed: onRefresh),
            ],
          ),
        ),
      );
    }
    if (feed.posts.isEmpty) {
      return RefreshIndicator.adaptive(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(LucideIcons.image, size: 56, color: AppColors.textTertiary),
                    SizedBox(height: AppSpacing.lg),
                    Text(
                      'No posts yet',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Be the first to post in this server!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scroll,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: feed.posts.length + (feed.hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == feed.posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            );
          }
          final post = feed.posts[i];
          return PostCard(
            post: post,
            onLikeTap: () => onLikeTap(post.id),
            onCommentTap: () {
              // TODO(Phase 4): push comments page.
              ref
                  .read(toastControllerProvider.notifier)
                  .info(title: 'Comments page lands in Phase 4');
            },
          );
        },
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: List.generate(3, (_) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const VSkeleton.circle(size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          VSkeleton(width: 120, height: 12),
                          SizedBox(height: 4),
                          VSkeleton(width: 80, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const AspectRatio(
                aspectRatio: 1,
                child: VSkeleton(height: double.infinity, radius: 0),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: VSkeleton(width: 180, height: 14),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _NoServerState extends StatelessWidget {
  const _NoServerState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(LucideIcons.users, size: 56, color: AppColors.textTertiary),
            SizedBox(height: AppSpacing.lg),
            Text(
              'No servers yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Create or join a server to see posts here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
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
