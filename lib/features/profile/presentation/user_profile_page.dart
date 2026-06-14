import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/v_skeleton.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/app_assets.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../chat/data/chat_api.dart';
import '../../chat/domain/chat_models.dart';
import '../../post/data/post_api.dart';
import '../../post/domain/post.dart';
import '../data/profile_api.dart';

/// Read-only view of another member's per-server profile: identity block plus
/// their posts grid in this server. No edit or settings affordances — this is
/// not the viewer's own profile. Keyed by (serverId, userId) because identity
/// is per-server (multi-identity Option B).
class UserProfilePage extends ConsumerStatefulWidget {
  const UserProfilePage({super.key, required this.serverId, required this.userId});

  final String serverId;
  final String userId;

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  ServerMemberProfile? _profile;
  bool _loadingProfile = false;
  List<Post> _posts = const [];
  bool _loadingPosts = false;
  bool _startingConversation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _startConversation() async {
    setState(() => _startingConversation = true);
    try {
      final convo = await ref
          .read(chatApiProvider)
          .getOrCreateConversation(widget.serverId, widget.userId);
      if (!mounted) return;
      final profile = _profile;
      await context.push(
        Routes.chatConversation(convo.id),
        extra: ChatConversationArgs(
          peerUserId: widget.userId,
          peerNickname: profile?.nickname ?? convo.peer.nickname,
          peerAvatarUrl: profile?.avatarUrl ?? convo.peer.avatarUrl,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _startingConversation = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loadingProfile = true;
      _loadingPosts = true;
    });
    try {
      final p = await ref.read(profileApiProvider).forUser(widget.serverId, widget.userId);
      if (!mounted) return;
      setState(() => _profile = p);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
    try {
      final page = await ref.read(postApiProvider).postsForUser(
            serverId: widget.serverId,
            userId: widget.userId,
            limit: 20,
          );
      if (!mounted) return;
      setState(() => _posts = page.data);
    } catch (_) {
      // Grid is best-effort; leave it empty on failure.
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final nickname = profile?.nickname ?? '';
    final username = profile?.username;
    final title = (username != null && username.isNotEmpty)
        ? username
        : (nickname.isNotEmpty ? nickname : 'Profile');
    final initial = nickname.isNotEmpty ? nickname.characters.first.toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VAppBar(title: title),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: _load,
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_loadingProfile && profile == null)
              const SliverToBoxAdapter(child: _HeaderSkeleton())
            else
              SliverToBoxAdapter(
                child: _Identity(
                  nickname: nickname,
                  username: username,
                  bio: profile?.bio,
                  avatarUrl: profile?.avatarUrl,
                  initial: initial,
                  onMessage: _startingConversation ? null : _startConversation,
                  messageLoading: _startingConversation,
                ),
              ),
            const SliverToBoxAdapter(child: _GridDivider()),
            if (_loadingPosts && _posts.isEmpty)
              const SliverToBoxAdapter(child: _GridSkeleton())
            else if (_posts.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: _EmptyGrid())
            else
              SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: _posts.length,
                itemBuilder: (_, i) {
                  final p = _posts[i];
                  return GestureDetector(
                    onTap: () => context.push('/posts/${p.id}'),
                    child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                        ? Image.network(p.imageUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(color: AppColors.surface))
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
          ],
        ),
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.nickname,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.initial,
    required this.onMessage,
    required this.messageLoading,
  });

  final String nickname;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String initial;
  final VoidCallback? onMessage;
  final bool messageLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? Image.network(avatarUrl!,
                        width: 84, height: 84, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _avatarFallback())
                    : _avatarFallback(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nickname, style: AppTextStyles.bodyStrong),
                    if (username != null && username!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (bio != null && bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(bio!, style: AppTextStyles.body.copyWith(height: 1.4)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onMessage,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: messageLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Message'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColorFor(nickname),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _GridDivider extends StatelessWidget {
  const _GridDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Center(
        child: Icon(LucideIcons.grid3x3, size: 22, color: AppColors.textPrimary),
      ),
    );
  }
}

class _EmptyGrid extends StatelessWidget {
  const _EmptyGrid();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.illustrationEmptyPostForProfile, width: 200),
            const SizedBox(height: 20),
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
              "This user hasn't posted anything yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          VSkeleton.circle(size: 84),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VSkeleton(width: 140, height: 14),
                SizedBox(height: 8),
                VSkeleton(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 9,
      itemBuilder: (_, _) => const VSkeleton(height: 120, radius: 0),
    );
  }
}
