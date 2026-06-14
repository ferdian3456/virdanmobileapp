import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/v_skeleton.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/app_assets.dart';
import '../../../core/widgets/v_button.dart';
import '../../post/data/post_api.dart';
import '../../post/domain/post.dart';
import '../../post/presentation/explore_feed_page.dart';
import '../../server/data/server_repository.dart';
import 'post_search_view.dart';

/// Matches Quasar ExplorePage.vue: search bar + 3-column post grid from the
/// active server's feed. Empty state uses social.svg.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final _scroll = ScrollController();
  List<Post> _posts = const [];
  bool _loading = false;
  String? _nextCursor;
  bool _hasMore = true;
  bool _searchMode = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(myServersProvider.notifier).fetch();
      if (mounted) _load(reset: true);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || !_hasMore) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) _load(reset: false);
  }

  Future<void> _load({required bool reset}) async {
    final serverId = ref.read(myServersProvider).activeServerId;
    if (serverId == null) {
      setState(() {
        _posts = const [];
        _hasMore = false;
      });
      return;
    }
    if (reset) {
      setState(() {
        _posts = const [];
        _nextCursor = null;
        _hasMore = true;
      });
    } else if (!_hasMore || _nextCursor == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final page = await ref.read(postApiProvider).listForServer(
            serverId: serverId,
            cursor: reset ? null : _nextCursor,
          );
      if (!mounted) return;
      setState(() {
        _posts = reset ? page.data : [..._posts, ...page.data];
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasMore = false);
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFeed(Post p) {
    final serverId = ref.read(myServersProvider).activeServerId;
    if (serverId == null) return;
    final index = _posts.indexWhere((e) => e.id == p.id);
    context.push(
      Routes.exploreFeed(p.id),
      extra: ExploreFeedArgs(
        posts: _posts,
        startIndex: index < 0 ? 0 : index,
        serverId: serverId,
        nextCursor: _nextCursor,
        hasMore: _hasMore,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _searchMode
            ? PostSearchView(onClose: () => setState(() => _searchMode = false))
            : _buildBrowse(),
      ),
    );
  }

  Widget _buildBrowse() {
    final showSkeleton = _loading && _posts.isEmpty;
    return Column(
      children: [
        _SearchBarButton(onTap: () => setState(() => _searchMode = true)),
        Expanded(
          child: showSkeleton
              ? const _GridSkeleton()
              : _posts.isEmpty
                  ? _EmptyState(onCreate: () => context.go(Routes.appCreate))
                  : GridView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(2),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: _posts.length + (_hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _posts.length) {
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final p = _posts[i];
                        final hasImage = p.imageUrl != null && p.imageUrl!.isNotEmpty;
                        final hasVideoThumb = p.isVideo && p.thumbnailUrl != null && p.thumbnailUrl!.isNotEmpty;

                        Widget mediaWidget;
                        if (hasImage) {
                          mediaWidget = Image.network(
                            p.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(color: AppColors.surface),
                          );
                        } else if (hasVideoThumb) {
                          mediaWidget = Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                p.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(color: AppColors.surface),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          mediaWidget = Container(
                            color: AppColors.surface,
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              p.caption,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          );
                        }

                        return GestureDetector(
                          onTap: () => _openFeed(p),
                          child: mediaWidget,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _SearchBarButton extends StatelessWidget {
  const _SearchBarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(LucideIcons.search, size: 18, color: AppColors.textTertiary),
              SizedBox(width: 8),
              Text(
                'Search posts...',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.illustrationSocial, width: 240),
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
              'Be the first to share something in your servers.',
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

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 12,
      itemBuilder: (_, _) => const VSkeleton(height: 120, radius: 0),
    );
  }
}
