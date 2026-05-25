import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/app_assets.dart';
import '../../../core/util/relative_time.dart';
import '../../../core/widgets/v_button.dart';
import '../../server/data/server_repository.dart';
import '../../server/domain/server.dart';
import '../data/server_feed_provider.dart';
import '../domain/post.dart';

/// Matches Quasar HomePage.vue closely:
/// - No-servers state: community.svg + "No servers yet" + Explore + Create.
/// - No-posts state: posting_photo.svg + "No posts yet" + Create a Post.
/// - Header: uppercase server name + chevron menu + send (DM) icon.
/// - Feed card: 36px avatar, name + relative time, 1:1 image, action row
///   (heart/comment/share + bookmark right), caption rich text.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();
  bool _bootDone = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(myServersProvider.notifier).fetch();
      final id = ref.read(myServersProvider).activeServerId;
      if (id != null && mounted) {
        await ref.read(serverFeedProvider.notifier).loadFor(id);
      }
      if (mounted) setState(() => _bootDone = true);
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

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(serverFeedProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e,
          onRetry: () => ref.read(serverFeedProvider.notifier).refresh());
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
            const Divider(height: 1),
            _MenuItem(
              iconBg: AppColors.primarySoft,
              iconColor: AppColors.primary,
              icon: LucideIcons.plus,
              label: 'Create a server',
              labelColor: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                context.push(Routes.appCreateServer);
              },
            ),
            _MenuItem(
              iconBg: const Color(0xFFF1F3F5),
              iconColor: const Color(0xFF495057),
              icon: LucideIcons.compass,
              label: 'Explore servers',
              labelColor: const Color(0xFF495057),
              onTap: () {
                Navigator.pop(context);
                context.push('/app/explore-servers');
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
    final servers = state.servers;
    final active = state.activeServer;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: !_bootDone && servers.isEmpty
            ? const _FeedSkeleton()
            : servers.isEmpty
                ? _EmptyServersState(
                    onExplore: () => context.push('/app/explore-servers'),
                    onCreate: () => context.push(Routes.appCreateServer),
                  )
                : Column(
                    children: [
                      _HomeHeader(
                        active: active,
                        onTapName: () =>
                            _openServerSwitcher(servers, state.activeServerId),
                        onMessages: () => context.push(Routes.appChat),
                      ),
                      Expanded(child: _FeedBody(
                        scroll: _scroll,
                        onRefresh: _refresh,
                        onLikeTap: _toggleLike,
                        onCreatePost: () => context.go(Routes.appCreate),
                      )),
                    ],
                  ),
      ),
    );
  }
}

class _EmptyServersState extends StatelessWidget {
  const _EmptyServersState({required this.onExplore, required this.onCreate});

  final VoidCallback onExplore;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.illustrationCommunity, width: 240),
            const SizedBox(height: 24),
            const Text(
              'No servers yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.36,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join a community or create your own to start seeing posts here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: VButton(
                label: 'Explore Servers',
                size: VButtonSize.lg,
                fullWidth: true,
                onPressed: onExplore,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: VButton(
                label: 'Create a Server',
                variant: VButtonVariant.outline,
                size: VButtonSize.lg,
                fullWidth: true,
                onPressed: onCreate,
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
    required this.onMessages,
  });

  final Server? active;
  final VoidCallback onTapName;
  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTapName,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        (active?.name ?? 'SELECT SERVER').toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.34,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(LucideIcons.chevronDown,
                        size: 20, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.send, size: 22),
            tooltip: 'Messages',
            onPressed: onMessages,
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
    required this.onCreatePost,
  });

  final ScrollController scroll;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onLikeTap;
  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(serverFeedProvider);
    if (feed.isLoading && feed.posts.isEmpty) return const _FeedSkeleton();
    if (feed.posts.isEmpty) {
      return _EmptyFeedState(onCreate: onCreatePost);
    }
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scroll,
        padding: EdgeInsets.zero,
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
          final p = feed.posts[i];
          return _FeedCard(
            post: p,
            onLike: () => onLikeTap(p.id),
            onComment: () => GoRouter.of(context).push('/posts/${p.id}/comments'),
          );
        },
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.illustrationPostingPhoto, width: 320),
            const SizedBox(height: 24),
            const Text(
              'No posts yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.36,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to share something in this server.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: VButton(
                label: 'Create a Post',
                size: VButtonSize.lg,
                fullWidth: true,
                onPressed: onCreate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.post, required this.onLike, required this.onComment});

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final initial = post.authorNickname.isNotEmpty
        ? post.authorNickname.characters.first.toUpperCase()
        : '?';
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
      ),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                ClipOval(
                  child: post.authorAvatarUrl != null && post.authorAvatarUrl!.isNotEmpty
                      ? Image.network(
                          post.authorAvatarUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _fallback(initial),
                        )
                      : _fallback(initial),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorNickname,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.14,
                        ),
                      ),
                      Text(
                        formatRelativeTime(post.createdAt),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.ellipsis, size: 20),
                  onPressed: () {},
                  tooltip: 'More',
                ),
              ],
            ),
          ),
          // Image
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: ColoredBox(
                color: const Color(0xFFF1F3F5),
                child: Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(LucideIcons.imageOff, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _ActionButton(
                  icon: post.isLiked ? Icons.favorite : LucideIcons.heart,
                  count: post.likeCount,
                  active: post.isLiked,
                  activeColor: AppColors.error,
                  onTap: onLike,
                ),
                _ActionButton(
                  icon: LucideIcons.messageCircle,
                  count: post.commentCount,
                  onTap: onComment,
                ),
                _ActionButton(
                  icon: LucideIcons.send,
                  onTap: () {},
                ),
                const Spacer(),
                _ActionButton(
                  icon: LucideIcons.bookmark,
                  iconSize: 22,
                  onTap: () {},
                ),
              ],
            ),
          ),
          // Caption
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF212529),
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${post.authorNickname} ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: post.caption),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback(String initial) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    this.count = 0,
    this.active = false,
    this.activeColor,
    this.iconSize = 24,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final bool active;
  final Color? activeColor;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? AppColors.error) : const Color(0xFF212529);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: color),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: labelColor,
        ),
      ),
      onTap: onTap,
    );
  }
}
