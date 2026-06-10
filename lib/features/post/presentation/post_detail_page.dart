import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../data/post_api.dart';
import '../data/server_feed_provider.dart';
import '../domain/post.dart';
import 'widgets/post_card.dart';
import 'widgets/post_options_sheet.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  Post? _post;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final post = await ref.read(postApiProvider).getById(widget.postId);
      if (!mounted) return;
      setState(() => _post = post);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e, onRetry: _load);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    final p = _post;
    if (p == null) return;
    final before = p;
    setState(() {
      _post = p.copyWith(
        isLiked: !p.isLiked,
        likeCount: p.isLiked ? p.likeCount - 1 : p.likeCount + 1,
      );
    });
    try {
      if (before.isLiked) {
        await ref.read(postApiProvider).unlike(p.id);
      } else {
        await ref.read(postApiProvider).like(p.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _post = before);
      showApiErrorToast(ref, e);
    }
  }

  Future<void> _toggleSave() async {
    final p = _post;
    if (p == null) return;
    final before = p;
    setState(() => _post = p.copyWith(isSaved: !p.isSaved));
    try {
      if (before.isSaved) {
        await ref.read(postApiProvider).unsave(p.id);
      } else {
        await ref.read(postApiProvider).save(p.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _post = before);
      showApiErrorToast(ref, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = switch (ref.read(authRepositoryProvider)) {
      AsyncData(value: AuthAuthenticated(:final user)) => user.id,
      _ => null,
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(title: 'Post', leading: VAppBarLeading.back),
      body: SafeArea(
        child: _loading && _post == null
            ? const Center(child: CircularProgressIndicator())
            : _post == null
                ? const Center(child: Text('Post not found'))
                : ListView(
                    children: [
                      PostCard(
                        post: _post!,
                        onLikeTap: _toggleLike,
                        onSaveTap: _toggleSave,
                        onCommentTap: () => context.push('/posts/${_post!.id}/comments'),
                        onAuthorTap: () => _post!.authorId == currentUserId
                            ? context.go(Routes.appProfile)
                            : context.push(
                                Routes.userProfile(_post!.serverId, _post!.authorId)),
                        onMoreTap: _post!.authorId == currentUserId
                            ? () => showPostOptions(
                                  context: context,
                                  ref: ref,
                                  post: _post!,
                                  onEdited: (u) => setState(() => _post = u),
                                  onDeleted: () {
                                    ref
                                        .read(serverFeedProvider.notifier)
                                        .removePost(_post!.id);
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go(Routes.appHome);
                                    }
                                  },
                                )
                            : null,
                      ),
                    ],
                  ),
      ),
    );
  }
}
