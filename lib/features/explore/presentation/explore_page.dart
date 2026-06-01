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

/// Matches Quasar ExplorePage.vue: search bar + 3-column post grid from the
/// active server's feed. Empty state uses social.svg.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<Post> _posts = const [];
  bool _loading = false;
  String? _nextCursor;
  bool _hasMore = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text));
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(myServersProvider.notifier).fetch();
      if (mounted) _load(reset: true);
    });
  }

  @override
  void dispose() {
    _search.dispose();
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

  List<Post> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _posts;
    return _posts
        .where((p) =>
            p.authorNickname.toLowerCase().contains(q) ||
            p.caption.toLowerCase().contains(q))
        .toList();
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
    final showSkeleton = _loading && _posts.isEmpty;
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Search(controller: _search),
            Expanded(
              child: showSkeleton
                  ? const _GridSkeleton()
                  : filtered.isEmpty
                      ? _EmptyState(
                          onCreate: () => context.go(Routes.appCreate),
                        )
                      : GridView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(2),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                          ),
                          itemCount: filtered.length + (_hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == filtered.length) {
                              return const Center(
                                  child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(strokeWidth: 2)));
                            }
                            final p = filtered[i];
                            return GestureDetector(
                              onTap: () => _openFeed(p),
                              child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                  ? Image.network(p.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                          color: AppColors.surface))
                                  : Container(
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
                                    ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search people, tags, places…',
            hintStyle: const TextStyle(
                fontFamily: 'Inter', color: AppColors.textTertiary, fontSize: 14),
            prefixIcon: const Icon(LucideIcons.search,
                size: 18, color: AppColors.textTertiary),
            filled: true,
            fillColor: const Color(0xFFF1F3F5),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
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
