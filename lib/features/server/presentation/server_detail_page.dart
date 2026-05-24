import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/v_skeleton.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../../post/data/post_api.dart';
import '../../post/domain/post.dart';
import '../data/server_detail_api.dart';

class ServerDetailPage extends ConsumerStatefulWidget {
  const ServerDetailPage({super.key, required this.serverId});

  final String serverId;

  @override
  ConsumerState<ServerDetailPage> createState() => _ServerDetailPageState();
}

class _ServerDetailPageState extends ConsumerState<ServerDetailPage> {
  ServerDetail? _server;
  bool _loadingServer = false;
  List<Post> _posts = const [];
  bool _loadingPosts = false;
  String? _nextCursor;
  bool _hasMore = true;
  int _activeTab = 0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServer();
      _loadPosts(reset: true);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingPosts) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _loadPosts(reset: false);
    }
  }

  Future<void> _loadServer() async {
    setState(() => _loadingServer = true);
    try {
      final detail = await ref.read(serverDetailApiProvider).getById(widget.serverId);
      if (!mounted) return;
      setState(() => _server = detail);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e, onRetry: _loadServer);
    } finally {
      if (mounted) setState(() => _loadingServer = false);
    }
  }

  Future<void> _loadPosts({required bool reset}) async {
    if (reset) {
      setState(() {
        _loadingPosts = true;
        _posts = const [];
        _nextCursor = null;
        _hasMore = true;
      });
    } else {
      if (!_hasMore || _loadingPosts) return;
      setState(() => _loadingPosts = true);
    }
    try {
      final page = await ref.read(postApiProvider).listForServer(
            serverId: widget.serverId,
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
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  bool get _isOwner {
    final userId = switch (ref.read(authRepositoryProvider)) {
      AsyncData(value: AuthAuthenticated(:final user)) => user.id,
      _ => null,
    };
    if (userId == null || _server?.createdBy == null) return false;
    return _server!.createdBy == userId;
  }

  @override
  Widget build(BuildContext context) {
    final server = _server;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              title: server?.name ?? 'Server',
              showSettings: _isOwner,
              onSettings: () {
                context.push('/server/${widget.serverId}/settings');
              },
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _loadingServer && server == null
                  ? const _ServerHeaderSkeleton()
                  : server == null
                      ? const Center(child: Text('Server not found.'))
                      : CustomScrollView(
                          controller: _scroll,
                          slivers: [
                            SliverToBoxAdapter(child: _Banner(server: server)),
                            SliverToBoxAdapter(child: _Info(server: server)),
                            SliverToBoxAdapter(
                              child: _Tabs(
                                active: _activeTab,
                                onTap: (i) => setState(() => _activeTab = i),
                              ),
                            ),
                            if (_activeTab == 0) ..._postsSlivers() else _membersStub(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _postsSlivers() {
    if (_loadingPosts && _posts.isEmpty) {
      return const [SliverToBoxAdapter(child: _PostGridSkeleton())];
    }
    if (_posts.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No posts in this server yet.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: _posts.length,
          itemBuilder: (_, i) {
            final post = _posts[i];
            return GestureDetector(
              onTap: () => context.push('/posts/${post.id}'),
              child: post.imageUrl != null && post.imageUrl!.isNotEmpty
                  ? Image.network(
                      post.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.surface,
                        child: const Center(
                          child: Icon(LucideIcons.imageOff, color: AppColors.textTertiary),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        post.caption,
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
      if (_loadingPosts && _posts.isNotEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _membersStub() {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Members view coming soon.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.showSettings,
    required this.onSettings,
    required this.onBack,
  });

  final String title;
  final bool showSettings;
  final VoidCallback onSettings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 24),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyStrong,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showSettings)
            IconButton(
              icon: const Icon(LucideIcons.settings, size: 22),
              onPressed: onSettings,
              tooltip: 'Server settings',
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.server});

  final ServerDetail server;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.primary,
            image: server.bannerUrl != null && server.bannerUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(server.bannerUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
            gradient: server.bannerUrl == null
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  )
                : null,
          ),
        ),
        Positioned(
          left: 20,
          bottom: -32,
          child: _ServerAvatar(server: server, size: 80),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ServerAvatar extends StatelessWidget {
  const _ServerAvatar({required this.server, required this.size});

  final ServerDetail server;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = server.shortName.isNotEmpty
        ? server.shortName.characters.first.toUpperCase()
        : server.name.characters.first.toUpperCase();
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColorFor(
          server.shortName.isNotEmpty ? server.shortName : server.name,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
    if (server.avatarUrl == null || server.avatarUrl!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Image.network(
          server.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.server});

  final ServerDetail server;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            server.name,
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '@${server.shortName}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('·', style: TextStyle(color: AppColors.textTertiary)),
              ),
              Text(
                server.categoryName ?? 'Uncategorized',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('·', style: TextStyle(color: AppColors.textTertiary)),
              ),
              Text(
                '${formatCount(server.memberCount)} members',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          if (server.description != null && server.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              server.description!,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.active, required this.onTap});

  final int active;
  final ValueChanged<int> onTap;

  static const _labels = ['Posts', 'Members'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final isActive = active == i;
          return Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    _labels[i],
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ServerHeaderSkeleton extends StatelessWidget {
  const _ServerHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          VSkeleton(height: 140, radius: 0),
          SizedBox(height: 16),
          VSkeleton(width: 160, height: 24),
          SizedBox(height: 8),
          VSkeleton(width: 220, height: 12),
          SizedBox(height: 16),
          VSkeleton(height: 14),
          SizedBox(height: 8),
          VSkeleton(height: 14, width: 240),
        ],
      ),
    );
  }
}

class _PostGridSkeleton extends StatelessWidget {
  const _PostGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
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
