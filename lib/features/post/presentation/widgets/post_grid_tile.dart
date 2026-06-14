import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/post.dart';

/// Square grid tile for a post: image, video thumbnail with a play badge, or a
/// caption fallback for text-only posts. Shared by every profile/feed grid so
/// video thumbnails render consistently across pages.
class PostGridTile extends StatelessWidget {
  const PostGridTile({super.key, required this.post, this.onTap});

  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final hasVideoThumb =
        post.isVideo && post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty;

    Widget media;
    if (hasImage) {
      media = Image.network(
        post.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _Fallback(),
      );
    } else if (hasVideoThumb) {
      media = Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            post.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _Fallback(),
          ),
          const Positioned(top: 8, right: 8, child: _PlayBadge()),
        ],
      );
    } else {
      media = _CaptionTile(caption: post.caption);
    }

    return GestureDetector(onTap: onTap, child: media);
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
    );
  }
}

class _CaptionTile extends StatelessWidget {
  const _CaptionTile({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(8),
      child: Text(
        caption,
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
}

class _Fallback extends StatelessWidget {
  const _Fallback();

  @override
  Widget build(BuildContext context) {
    return Container(color: AppColors.surface);
  }
}
