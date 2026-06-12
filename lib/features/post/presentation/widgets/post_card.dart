import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/util/relative_time.dart';
import '../../domain/post.dart';

/// Canonical post card shared by the home feed, explore feed, and post detail.
/// IG-style: header (avatar + author + relative time), 1:1 image, action row
/// with inline like/comment counts plus a bookmark on the right, then caption.
/// [onAuthorTap] navigates to the author's per-server profile when provided.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onSaveTap,
    this.onAuthorTap,
    this.onMoreTap,
  });

  final Post post;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onSaveTap;
  final VoidCallback? onAuthorTap;

  /// Opens the post options sheet (edit/delete). Provided only when the
  /// current user owns the post; otherwise the overflow button is hidden.
  final VoidCallback? onMoreTap;

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
                GestureDetector(
                  onTap: onAuthorTap,
                  child: ClipOval(
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onAuthorTap,
                    behavior: HitTestBehavior.opaque,
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
                ),
                if (onMoreTap != null)
                  IconButton(
                    icon: const Icon(LucideIcons.ellipsis, size: 20),
                    onPressed: onMoreTap,
                    tooltip: 'More',
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
          // Media (image or video thumbnail)
          PostMediaWidget(post: post),
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
                  onTap: onLikeTap,
                ),
                _ActionButton(
                  icon: LucideIcons.messageCircle,
                  count: post.commentCount,
                  onTap: onCommentTap,
                ),
                _ActionButton(
                  icon: LucideIcons.send,
                  onTap: () {},
                ),
                const Spacer(),
                _ActionButton(
                  icon: post.isSaved ? Icons.bookmark : LucideIcons.bookmark,
                  iconSize: 22,
                  active: post.isSaved,
                  activeColor: const Color(0xFF0F172A),
                  onTap: onSaveTap,
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

class PostMediaWidget extends StatefulWidget {
  const PostMediaWidget({super.key, required this.post});

  final Post post;

  @override
  State<PostMediaWidget> createState() => _PostMediaWidgetState();
}

class _PostMediaWidgetState extends State<PostMediaWidget> {
  bool _playVideo = false;

  @override
  Widget build(BuildContext context) {
    final ratio = widget.post.mediaAspectRatio;
    final clampedRatio = ratio?.clamp(4 / 5, 1.91) ?? (4 / 5);

    if (widget.post.isVideo) {
      if (_playVideo && widget.post.videoUrl != null) {
        return FeedVideoPlayer(
          videoUrl: widget.post.videoUrl!,
          aspectRatio: clampedRatio,
          thumbnailUrl: widget.post.thumbnailUrl,
        );
      }

      final thumbUrl = widget.post.thumbnailUrl;
      if (ratio == null) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _playVideo = true;
            });
          },
          child: Container(
            color: const Color(0xFFF1F3F5),
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (thumbUrl != null && thumbUrl.isNotEmpty)
                  Image.network(
                    thumbUrl,
                    fit: BoxFit.fitWidth,
                    width: double.infinity,
                    errorBuilder: (_, _, _) => const Center(
                      child: SizedBox(
                        height: 200,
                        child: Icon(LucideIcons.imageOff, color: AppColors.textTertiary),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 200),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return GestureDetector(
        onTap: () {
          setState(() {
            _playVideo = true;
          });
        },
        child: AspectRatio(
          aspectRatio: clampedRatio,
          child: ColoredBox(
            color: const Color(0xFFF1F3F5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumbUrl != null && thumbUrl.isNotEmpty)
                  Image.network(
                    thumbUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(LucideIcons.imageOff, color: AppColors.textTertiary),
                    ),
                  ),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final imgUrl = widget.post.imageUrl;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (ratio == null) {
        return Container(
          color: const Color(0xFFF1F3F5),
          width: double.infinity,
          child: Image.network(
            imgUrl,
            fit: BoxFit.fitWidth,
            width: double.infinity,
            errorBuilder: (_, _, _) => const Center(
              child: SizedBox(
                height: 200,
                child: Icon(LucideIcons.imageOff, color: AppColors.textTertiary),
              ),
            ),
          ),
        );
      }

      return AspectRatio(
        aspectRatio: clampedRatio,
        child: ColoredBox(
          color: const Color(0xFFF1F3F5),
          child: Image.network(
            imgUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(LucideIcons.imageOff, color: AppColors.textTertiary),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class FeedVideoPlayer extends StatefulWidget {
  const FeedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.aspectRatio,
    this.thumbnailUrl,
  });

  final String videoUrl;
  final double aspectRatio;
  final String? thumbnailUrl;

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.play();
          _controller.setLooping(true);
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: _buildPlayerContent(),
    );
  }

  Widget _buildPlayerContent() {
    if (_hasError) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(LucideIcons.videoOff, color: Colors.white, size: 36),
        ),
      );
    }

    if (!_initialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
            Image.network(
              widget.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
            )
          else
            const ColoredBox(color: Colors.black),
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          VideoPlayer(_controller),
          if (!_controller.value.isPlaying)
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
              ),
            ),
        ],
      ),
    );
  }
}
