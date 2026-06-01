import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../data/post_api.dart';
import '../domain/post.dart';
import 'widgets/post_card.dart';

/// Payload handed from the explore grid: the posts already fetched for the
/// active server, the tapped post's index, and the cursor to continue from.
/// Passed via go_router `extra`; absent on a cold deep-link.
class ExploreFeedArgs {
  const ExploreFeedArgs({
    required this.posts,
    required this.startIndex,
    required this.serverId,
    this.nextCursor,
    this.hasMore = true,
  });

  final List<Post> posts;
  final int startIndex;
  final String serverId;
  final String? nextCursor;
  final bool hasMore;
}

/// IG-style feed opened from the explore grid. Anchored to the tapped post,
/// scrollable up (newer posts already in memory) and down (older posts paged
/// in via the existing cursor). Reuses the list the grid already loaded, so
/// no refetch is needed for what is already on screen.
class ExploreFeedPage extends ConsumerStatefulWidget {
  const ExploreFeedPage({super.key, required this.postId, this.args});

  final String postId;
  final ExploreFeedArgs? args;

  @override
  ConsumerState<ExploreFeedPage> createState() => _ExploreFeedPageState();
}

class _ExploreFeedPageState extends ConsumerState<ExploreFeedPage> {
  List<Post> _posts = const [];
  String? _serverId;
  String? _nextCursor;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _loadingSingle = false;
  int _initialIndex = 0;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args != null && args.posts.isNotEmpty) {
      _posts = List.of(args.posts);
      _serverId = args.serverId;
      _nextCursor = args.nextCursor;
      _hasMore = args.hasMore && args.nextCursor != null;
      _initialIndex =
          (args.startIndex >= 0 && args.startIndex < _posts.length) ? args.startIndex : 0;
    } else {
      // Cold deep-link: no in-memory feed, fall back to the single post.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSingle());
    }
  }

  Future<void> _loadSingle() async {
    setState(() => _loadingSingle = true);
    try {
      final post = await ref.read(postApiProvider).getById(widget.postId);
      if (!mounted) return;
      setState(() {
        _posts = [post];
        _hasMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e, onRetry: _loadSingle);
    } finally {
      if (mounted) setState(() => _loadingSingle = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _serverId == null || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(postApiProvider).listForServer(
            serverId: _serverId!,
            cursor: _nextCursor,
          );
      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...page.data];
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasMore = false);
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Optimistic like/unlike with rollback on failure (mirrors ServerFeed).
  Future<void> _toggleLike(String postId) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final before = _posts[idx];
    final next = before.copyWith(
      isLiked: !before.isLiked,
      likeCount: before.isLiked ? before.likeCount - 1 : before.likeCount + 1,
    );
    setState(() => _posts = [..._posts]..[idx] = next);
    try {
      if (before.isLiked) {
        await ref.read(postApiProvider).unlike(postId);
      } else {
        await ref.read(postApiProvider).like(postId);
      }
    } catch (e) {
      if (!mounted) return;
      final j = _posts.indexWhere((p) => p.id == postId);
      if (j != -1) setState(() => _posts = [..._posts]..[j] = before);
      showApiErrorToast(ref, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(title: 'Explore'),
      body: SafeArea(
        child: _posts.isEmpty
            ? Center(
                child: _loadingSingle
                    ? const CircularProgressIndicator()
                    : const Text('Post not found'),
              )
            : ScrollablePositionedList.builder(
                initialScrollIndex: _initialIndex,
                itemCount: _posts.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _posts.length) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _loadMore());
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
                  final p = _posts[i];
                  return PostCard(
                    post: p,
                    onLikeTap: () => _toggleLike(p.id),
                    onCommentTap: () => context.push('/posts/${p.id}/comments'),
                    onAuthorTap: () =>
                        context.push(Routes.userProfile(p.serverId, p.authorId)),
                  );
                },
              ),
      ),
    );
  }
}
