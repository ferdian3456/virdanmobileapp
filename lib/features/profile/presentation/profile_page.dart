import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/v_skeleton.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../../post/data/post_api.dart';
import '../../post/domain/post.dart';
import '../../server/data/server_repository.dart';
import '../data/profile_api.dart';

/// `/app/profile` — IG-style identity card for the active server, plus the
/// user's posts in that server (grid). Settings entry sits in the top bar.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  ServerMemberProfile? _profile;
  bool _loadingProfile = false;
  List<Post> _posts = const [];
  bool _loadingPosts = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final serverId = ref.read(myServersProvider).activeServerId;
    if (serverId == null) return;
    setState(() {
      _loadingProfile = true;
      _loadingPosts = true;
    });
    try {
      final p = await ref.read(profileApiProvider).meForServer(serverId);
      if (!mounted) return;
      setState(() => _profile = p);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
    try {
      final page = await ref.read(postApiProvider).postsForMe(
            serverId: serverId,
            limit: 30,
          );
      if (!mounted) return;
      setState(() => _posts = page.data);
    } catch (_) {
      // Silent; grid simply empty.
    } finally {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = switch (ref.watch(authRepositoryProvider)) {
      AsyncData(value: AuthAuthenticated(:final user)) => user.email,
      _ => '',
    };
    final profile = _profile;
    final username = profile?.username ?? profile?.nickname ?? email;
    final nickname = profile?.nickname ?? email;
    final initial = (profile?.nickname.isNotEmpty == true
            ? profile!.nickname
            : (email.isNotEmpty ? email : '?'))
        .characters
        .first
        .toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                title: username,
                onSettings: () async {
                  await context.push(Routes.settings);
                  if (mounted) _load();
                },
              ),
            ),
            if (_loadingProfile && profile == null)
              const SliverToBoxAdapter(child: _ProfileHeaderSkeleton())
            else
              SliverToBoxAdapter(
                child: _IdentityBlock(
                  nickname: nickname,
                  username: profile?.username,
                  bio: profile?.bio,
                  avatarUrl: profile?.avatarUrl,
                  initial: initial,
                  onEdit: () async {
                    await context.push(Routes.appEditProfile);
                    if (mounted) _load();
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: _TabStrip(
                active: _tab,
                onTap: (i) => setState(() => _tab = i),
              ),
            ),
            if (_tab == 0)
              if (_loadingPosts && _posts.isEmpty)
                const SliverToBoxAdapter(child: _GridSkeleton())
              else if (_posts.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyGrid(),
                )
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
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    );
                  },
                )
            else
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Coming soon.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onSettings});

  final String title;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.menu, size: 22),
            onPressed: onSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.nickname,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.initial,
    required this.onEdit,
  });

  final String nickname;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String initial;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.active, required this.onTap});

  final int active;
  final ValueChanged<int> onTap;

  static const _icons = [LucideIcons.grid3x3, LucideIcons.bookmark];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: List.generate(_icons.length, (i) {
          final isActive = i == active;
          return Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? AppColors.textPrimary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Icon(
                  _icons[i],
                  size: 22,
                  color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EmptyGrid extends StatelessWidget {
  const _EmptyGrid();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(LucideIcons.image, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text(
              'No posts yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Share your first post to fill up your profile grid.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton();

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
