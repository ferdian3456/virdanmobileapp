import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_app_bar.dart';
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
    setState(() => _posting = true);
    try {
      final comment = await ref.read(postApiProvider).postComment(widget.postId, content);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _input.clear();
      });
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(title: 'Comments', leading: VAppBarLeading.back),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading && _comments.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No comments yet. Be the first to comment.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: _comments.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _CommentTile(comment: _comments[i]),
                        ),
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final initial = comment.authorNickname.isNotEmpty
        ? comment.authorNickname.characters.first.toUpperCase()
        : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: comment.authorAvatarUrl != null && comment.authorAvatarUrl!.isNotEmpty
                ? Image.network(
                    comment.authorAvatarUrl!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallback(initial, comment.authorNickname),
                  )
                : _fallback(initial, comment.authorNickname),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.body
                    .copyWith(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                children: [
                  TextSpan(
                    text: '${comment.authorNickname} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: comment.content),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(String initial, String seed) {
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          IconButton(
            icon: loading
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2),
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
