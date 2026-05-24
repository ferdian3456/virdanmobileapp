import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/util/avatar_color.dart';
import '../../domain/post.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLikeTap,
    required this.onCommentTap,
  });

  final Post post;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(post: post),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.surface,
                  child: Center(
                    child: Icon(LucideIcons.imageOff, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          _Actions(
            isLiked: post.isLiked,
            onLikeTap: onLikeTap,
            onCommentTap: onCommentTap,
          ),
          if (post.likeCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                '${formatCount(post.likeCount)} likes',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.35,
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
          if (post.commentCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: GestureDetector(
                onTap: onCommentTap,
                child: Text(
                  'View ${post.commentCount} comments',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final initial = post.authorNickname.isNotEmpty
        ? post.authorNickname.characters.first.toUpperCase()
        : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          ClipOval(
            child: post.authorAvatarUrl != null && post.authorAvatarUrl!.isNotEmpty
                ? Image.network(
                    post.authorAvatarUrl!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _avatarFallback(initial),
                  )
                : _avatarFallback(initial),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              post.authorNickname,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.ellipsis, size: 20),
            onPressed: () {},
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColorFor(post.authorNickname),
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

class _Actions extends StatelessWidget {
  const _Actions({
    required this.isLiked,
    required this.onLikeTap,
    required this.onCommentTap,
  });

  final bool isLiked;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              LucideIcons.heart,
              size: 26,
              color: isLiked ? AppColors.error : AppColors.textPrimary,
            ),
            onPressed: onLikeTap,
          ),
          IconButton(
            icon: const Icon(LucideIcons.messageCircle, size: 26),
            onPressed: onCommentTap,
          ),
          IconButton(
            icon: const Icon(LucideIcons.send, size: 26),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
