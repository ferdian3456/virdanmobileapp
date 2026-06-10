import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/util/relative_time.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../../server/data/server_repository.dart';
import '../data/post_api.dart';
import '../domain/post.dart';

class CommentsPage extends ConsumerStatefulWidget {
  const CommentsPage({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends ConsumerState<CommentsPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  List<Comment> _comments = const [];
  bool _loading = false;
  bool _posting = false;
  Comment? _replyingTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await ref.read(postApiProvider).comments(widget.postId);
      if (!mounted) return;
      setState(() => _comments = page.data);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e, onRetry: _load);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _post() async {
    final content = _input.text.trim();
    if (content.isEmpty || _posting) return;
    final parent = _replyingTo;
    setState(() => _posting = true);
    try {
      final comment = await ref.read(postApiProvider).postComment(
            widget.postId,
            content,
            parentId: parent?.id,
          );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _input.clear();
        _replyingTo = null;
      });
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _startReply(Comment c) {
    setState(() => _replyingTo = c);
    _focus.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _openAuthor(Comment c) {
    final serverId = ref.read(myServersProvider).activeServerId;
    if (serverId == null) return;
    final currentUserId = switch (ref.read(authRepositoryProvider)) {
      AsyncData(value: AuthAuthenticated(:final user)) => user.id,
      _ => null,
    };
    if (c.authorId == currentUserId) {
      context.go(Routes.appProfile);
    } else {
      context.push(Routes.userProfile(serverId, c.authorId));
    }
  }

  List<_TreeNode> _buildTree() {
    final byId = <String, _TreeNode>{};
    for (final c in _comments) {
      byId[c.id] = _TreeNode(c);
    }
    final roots = <_TreeNode>[];
    for (final node in byId.values) {
      final pid = node.comment.parentId;
      if (pid != null && byId.containsKey(pid)) {
        byId[pid]!.replies.add(node);
      } else {
        roots.add(node);
      }
    }
    return roots;
  }

  @override
  Widget build(BuildContext context) {
    final roots = _buildTree();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VAppBar(
        title: 'Comments',
        leading: VAppBarLeading.back,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading && _comments.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : roots.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No comments yet. Be the first to share your thoughts.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: roots.length,
                          itemBuilder: (_, i) => _CommentNode(
                            node: roots[i],
                            depth: 0,
                            onReply: _startReply,
                            onAuthorTap: _openAuthor,
                          ),
                        ),
            ),
            if (_replyingTo != null)
              _ReplyHint(
                authorName: _replyingTo!.authorNickname,
                onCancel: _cancelReply,
              ),
            _Composer(
              controller: _input,
              focusNode: _focus,
              loading: _posting,
              onSend: _post,
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeNode {
  _TreeNode(this.comment);
  final Comment comment;
  final List<_TreeNode> replies = [];
}

class _CommentNode extends StatelessWidget {
  const _CommentNode({
    required this.node,
    required this.depth,
    required this.onReply,
    required this.onAuthorTap,
  });

  final _TreeNode node;
  final int depth;
  final ValueChanged<Comment> onReply;
  final ValueChanged<Comment> onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final c = node.comment;
    final initial = c.authorNickname.isNotEmpty
        ? c.authorNickname.characters.first.toUpperCase()
        : '?';
    final leftPad = 16.0 + (depth > 0 ? 44.0 : 0.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(leftPad, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => onAuthorTap(c),
                child: ClipOval(
                  child: c.authorAvatarUrl != null && c.authorAvatarUrl!.isNotEmpty
                      ? Image.network(
                          c.authorAvatarUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _avatarFallback(initial, c.authorNickname),
                        )
                      : _avatarFallback(initial, c.authorNickname),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: '${c.authorNickname} ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: c.content),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatRelativeTime(c.createdAt),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        InkWell(
                          onTap: () => onReply(c),
                          child: const Text(
                            'Reply',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final reply in node.replies)
          _CommentNode(
            node: reply,
            depth: depth + 1,
            onReply: onReply,
            onAuthorTap: onAuthorTap,
          ),
      ],
    );
  }

  Widget _avatarFallback(String initial, String seed) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColorFor(seed),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ReplyHint extends StatelessWidget {
  const _ReplyHint({required this.authorName, required this.onCancel});

  final String authorName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primarySoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.primary,
                ),
                children: [
                  const TextSpan(text: 'Replying to '),
                  TextSpan(
                    text: authorName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onCancel,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(LucideIcons.x, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          IconButton(
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.send, color: AppColors.primary),
            onPressed: loading ? null : onSend,
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}
