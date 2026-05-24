import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/feedback/v_skeleton.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../server/data/server_api.dart';
import '../../server/domain/server.dart';

class OnboardingServerChoicePage extends ConsumerStatefulWidget {
  const OnboardingServerChoicePage({super.key});

  @override
  ConsumerState<OnboardingServerChoicePage> createState() => _OnboardingServerChoicePageState();
}

class _OnboardingServerChoicePageState extends ConsumerState<OnboardingServerChoicePage> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  List<ServerCategory> _categories = const [];
  bool _categoriesLoading = false;
  int? _activeCategoryId;

  List<DiscoveryServer> _servers = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _nextCursor;
  String? _joiningId;
  String _query = '';

  static const _chipSkeletonWidths = [56.0, 72.0, 60.0, 80.0, 64.0, 68.0];
  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
      _loadServers(reset: true);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _nextCursor == null) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _loadServers(reset: false);
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final cats = await ref.read(serverApiProvider).categories();
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (_) {
      // Silent — chips simply won't render.
    } finally {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Future<void> _loadServers({required bool reset}) async {
    if (reset) {
      if (_loading) return;
      setState(() {
        _loading = true;
        _nextCursor = null;
        _servers = [];
      });
    } else {
      if (_loadingMore || _nextCursor == null) return;
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref.read(serverApiProvider).discover(
            categoryId: _activeCategoryId,
            cursor: reset ? null : _nextCursor,
            limit: _limit,
          );
      if (!mounted) return;
      setState(() {
        _servers = reset ? page.data : [..._servers, ...page.data];
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
      // Freeze pagination on error so the scroll listener doesn't hammer
      // the failing endpoint.
      setState(() => _nextCursor = null);
      showApiErrorToast(ref, e, onRetry: () => _loadServers(reset: true));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _setCategory(int? id) {
    if (_activeCategoryId == id) return;
    setState(() => _activeCategoryId = id);
    _loadServers(reset: true);
  }

  Future<void> _join(DiscoveryServer srv) async {
    if (_joiningId != null) return;
    // TODO(VIR-90 Phase 3): per-server profile creation step before join.
    // For now bounce through direct join; will be replaced by a profile
    // flow page once that's built.
    setState(() => _joiningId = srv.id);
    try {
      await ref.read(serverApiProvider).join(srv.id);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(
            title: 'Joined ${srv.name}',
          );
      // TODO: refresh myServers + navigate to /app/home.
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _joiningId = null);
    }
  }

  void _onCreate() {
    context.push(Routes.onboardingCreateServer);
  }

  List<DiscoveryServer> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _servers;
    return _servers.where((s) {
      return s.name.toLowerCase().contains(q) ||
          (s.description ?? '').toLowerCase().contains(q);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(child: _Hero()),
            SliverToBoxAdapter(child: _CreateCard(onTap: _onCreate)),
            const SliverToBoxAdapter(child: _OrJoinDivider()),
            SliverToBoxAdapter(
              child: _SearchBox(controller: _searchCtrl),
            ),
            SliverToBoxAdapter(
              child: _CategoryStrip(
                categories: _categories,
                loading: _categoriesLoading,
                activeId: _activeCategoryId,
                onTap: _setCategory,
                skeletonWidths: _chipSkeletonWidths,
              ),
            ),
            if (_loading && _servers.isEmpty)
              const SliverToBoxAdapter(child: _ServerListSkeleton())
            else if (_filtered.isEmpty)
              const SliverToBoxAdapter(child: _EmptyState())
            else
              SliverList.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final srv = _filtered[i];
                  return _ServerRow(
                    server: srv,
                    joining: _joiningId == srv.id,
                    onJoin: () => _join(srv),
                  );
                },
              ),
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                height: 1.1,
                letterSpacing: -0.7,
              ),
              children: const [
                TextSpan(text: 'Get Started\n'),
                TextSpan(
                  text: 'Find Your Community',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your own server or join an existing community — pick what suits your interests.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40007BFF),
                  offset: Offset(0, 8),
                  blurRadius: 22,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'GOT A COMMUNITY?',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.88,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Create Your Server',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.18,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Start a new community and invite your friends',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xD9FFFFFF),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x2EFFFFFF),
                    ),
                    child: const Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrJoinDivider extends StatelessWidget {
  const _OrJoinDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.divider, height: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'OR JOIN A COMMUNITY',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.88,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.divider, height: 1)),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search servers…',
            hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textTertiary),
            filled: true,
            fillColor: const Color(0xFFF1F3F5),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.loading,
    required this.activeId,
    required this.onTap,
    required this.skeletonWidths,
  });

  final List<ServerCategory> categories;
  final bool loading;
  final int? activeId;
  final ValueChanged<int?> onTap;
  final List<double> skeletonWidths;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _Chip(label: 'All', active: activeId == null, onTap: () => onTap(null)),
          const SizedBox(width: AppSpacing.sm),
          if (loading)
            ...skeletonWidths.map(
              (w) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: VSkeleton(width: w, height: 32, radius: 999),
              ),
            )
          else
            ...categories.map(
              (c) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _Chip(
                  label: c.categoryName,
                  active: activeId == c.id,
                  onTap: () => onTap(c.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: active ? AppColors.primary : const Color(0xFFE9ECEF)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : const Color(0xFF495057),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({required this.server, required this.joining, required this.onJoin});

  final DiscoveryServer server;
  final bool joining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final seed = server.shortName.isNotEmpty ? server.shortName : server.name;
    final initial = seed.isEmpty ? '?' : seed.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
      ),
      child: Row(
        children: [
          _Avatar(seed: seed, initial: initial, url: server.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  server.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  server.description?.isNotEmpty == true
                      ? server.description!
                      : 'No description provided',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.users, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      formatCount(server.memberCount),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _JoinButton(
            isMember: server.isMember,
            loading: joining,
            onPressed: server.isMember || joining ? null : onJoin,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed, required this.initial, this.url});

  final String seed;
  final String initial;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColorFor(seed),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.36,
        ),
      ),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipOval(
      child: Image.network(
        url!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({
    required this.isMember,
    required this.loading,
    required this.onPressed,
  });

  final bool isMember;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isMember ? 'Joined' : (loading ? '…' : 'Join');
    final bg = isMember ? Colors.transparent : AppColors.primary;
    final fg = isMember ? AppColors.textSecondary : Colors.white;
    final border = isMember ? const Color(0xFFDEE2E6) : AppColors.primary;
    return Opacity(
      opacity: onPressed == null && !isMember ? 0.6 : 1.0,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerListSkeleton extends StatelessWidget {
  const _ServerListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(6, (_) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const VSkeleton.circle(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      VSkeleton(height: 12, width: 120),
                      SizedBox(height: 6),
                      VSkeleton(height: 10, width: 180),
                      SizedBox(height: 6),
                      VSkeleton(height: 10, width: 60),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const VSkeleton(width: 64, height: 32, radius: 999),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.searchX, size: 56, color: AppColors.textTertiary),
            SizedBox(height: AppSpacing.lg),
            Text(
              'No servers match your search.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
