import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/v_skeleton.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/app_assets.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_button.dart';
import '../data/server_api.dart';
import '../data/server_create_draft.dart';
import '../domain/server.dart';

/// Server discovery, used at `/app/explore-servers` and
/// `/onboarding/explore-servers`. Same data as OnboardingServerChoicePage
/// but with a back-button header and no Create CTA.
class ExploreServersPage extends ConsumerStatefulWidget {
  const ExploreServersPage({super.key});

  @override
  ConsumerState<ExploreServersPage> createState() => _ExploreServersPageState();
}

class _ExploreServersPageState extends ConsumerState<ExploreServersPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  List<ServerCategory> _categories = const [];
  bool _categoriesLoading = false;
  int? _activeCategoryId;
  List<DiscoveryServer> _servers = const [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _nextCursor;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _search.addListener(() => setState(() => _query = _search.text));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
      _loadServers(reset: true);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _nextCursor == null) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) _loadServers(reset: false);
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final cats = await ref.read(serverApiProvider).categories();
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (_) {
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
        _servers = const [];
      });
    } else {
      if (_loadingMore || _nextCursor == null) return;
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref.read(serverApiProvider).discover(
            categoryId: _activeCategoryId,
            cursor: reset ? null : _nextCursor,
          );
      if (!mounted) return;
      setState(() {
        _servers = reset ? page.data : [..._servers, ...page.data];
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
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

  void _join(DiscoveryServer srv) {
    ref.read(joinTargetProvider.notifier).setTarget(
          JoinTarget(
            serverId: srv.id,
            serverName: srv.name,
            serverShortName: srv.shortName,
          ),
        );
    final path = ModalRoute.of(context)?.settings.name?.startsWith('/onboarding') ?? false
        ? '/onboarding/create-server/profile'
        : '/app/create-server/profile';
    context.push(path);
  }

  void _createServer() {
    final isOnboarding =
        ModalRoute.of(context)?.settings.name?.startsWith('/onboarding') ?? false;
    context.push(isOnboarding ? Routes.onboardingCreateServer : Routes.appCreateServer);
  }

  List<DiscoveryServer> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _servers;
    return _servers.where((s) =>
        s.name.toLowerCase().contains(q) ||
        (s.description ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(child: _Hero()),
                  SliverToBoxAdapter(child: _Search(controller: _search)),
                  SliverToBoxAdapter(
                    child: _Chips(
                      categories: _categories,
                      loading: _categoriesLoading,
                      active: _activeCategoryId,
                      onTap: (id) {
                        setState(() => _activeCategoryId = id);
                        _loadServers(reset: true);
                      },
                    ),
                  ),
                  if (_loading && _servers.isEmpty)
                    const SliverToBoxAdapter(child: _ListSkeleton())
                  else if (_filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(onCreate: _createServer),
                    )
                  else
                    SliverList.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final srv = _filtered[i];
                        return _Row(
                          server: srv,
                          joining: false,
                          onJoin: () => _join(srv),
                        );
                      },
                    ),
                  if (_loadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 24),
                onPressed: onBack,
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Join Servers',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                height: 1.15,
                letterSpacing: -0.7,
              ),
              children: [
                TextSpan(text: 'Find '),
                TextSpan(
                  text: 'Your Community',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Discover servers that match your interests — gaming, study, music, tech, and more.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search servers…',
            prefixIcon: const Icon(LucideIcons.search,
                size: 18, color: AppColors.textTertiary),
            filled: true,
            fillColor: const Color(0xFFF1F3F5),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.categories,
    required this.loading,
    required this.active,
    required this.onTap,
  });

  final List<ServerCategory> categories;
  final bool loading;
  final int? active;
  final ValueChanged<int?> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _Chip(label: 'All', active: active == null, onTap: () => onTap(null)),
          const SizedBox(width: 8),
          if (loading)
            ...const [56.0, 72.0, 60.0, 80.0, 64.0].map(
              (w) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: VSkeleton(width: w, height: 32, radius: 999),
              ),
            )
          else
            ...categories.map(
              (c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: c.categoryName,
                  active: active == c.id,
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

class _Row extends StatelessWidget {
  const _Row({required this.server, required this.joining, required this.onJoin});

  final DiscoveryServer server;
  final bool joining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final seed = server.shortName.isNotEmpty ? server.shortName : server.name;
    final initial = seed.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatarColorFor(seed),
              shape: BoxShape.circle,
            ),
            child: server.avatarUrl != null && server.avatarUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(server.avatarUrl!, fit: BoxFit.cover),
                  )
                : Text(
                    initial,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
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
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(LucideIcons.users,
                        size: 12, color: AppColors.textSecondary),
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
          _JoinPill(
            isMember: server.isMember,
            loading: joining,
            onPressed: server.isMember || joining ? null : onJoin,
          ),
        ],
      ),
    );
  }
}

class _JoinPill extends StatelessWidget {
  const _JoinPill({
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
    return Material(
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(AppAssets.illustrationEmpty, width: 220),
            const SizedBox(height: 20),
            const Text(
              'No servers found',
              textAlign: TextAlign.center,
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
              "No community matches this yet. Be the first to create one.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: VButton(
                label: 'Create a Server',
                size: VButtonSize.lg,
                fullWidth: true,
                onPressed: onCreate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

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
