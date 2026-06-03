import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../post/domain/post.dart';
import '../../post/presentation/explore_feed_page.dart';
import '../../server/data/server_repository.dart';
import '../data/post_search_provider.dart';
import '../data/recent_search_store.dart';

const _debounceMs = 350;
const _minChars = 2;

/// Search mode for the Explore tab. [onClose] returns to browse mode.
class PostSearchView extends ConsumerStatefulWidget {
  const PostSearchView({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<PostSearchView> createState() => _PostSearchViewState();
}

class _PostSearchViewState extends ConsumerState<PostSearchView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focus.requestFocus();
      final recent = await ref.read(recentSearchStoreProvider).load();
      if (mounted) setState(() => _recent = recent);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  String? get _serverId => ref.read(myServersProvider).activeServerId;

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < _minChars) {
      ref.read(postSearchProvider.notifier).clear();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      final serverId = _serverId;
      if (serverId == null) return;
      ref.read(postSearchProvider.notifier).run(serverId, q);
    });
  }

  void _onScroll() {
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      final serverId = _serverId;
      if (serverId != null) {
        ref.read(postSearchProvider.notifier).loadMore(serverId);
      }
    }
  }

  Future<void> _commit(String raw) async {
    final q = raw.trim();
    if (q.length < _minChars) return;
    final recent = await ref.read(recentSearchStoreProvider).add(q);
    if (mounted) setState(() => _recent = recent);
  }

  void _runRecent(String q) {
    _controller.text = q;
    _controller.selection =
        TextSelection.collapsed(offset: q.length);
    final serverId = _serverId;
    if (serverId != null) {
      ref.read(postSearchProvider.notifier).run(serverId, q);
    }
    _commit(q);
  }

  Future<void> _removeRecent(String q) async {
    final next = await ref.read(recentSearchStoreProvider).removeOne(q);
    if (mounted) setState(() => _recent = next);
  }

  Future<void> _clearAll() async {
    await ref.read(recentSearchStoreProvider).clear();
    if (mounted) setState(() => _recent = const []);
  }

  void _openResult(Post p) {
    final serverId = _serverId;
    if (serverId == null) return;
    _commit(_controller.text);
    final results = ref.read(postSearchProvider).results;
    final index = results.indexWhere((e) => e.id == p.id);
    context.push(
      Routes.exploreFeed(p.id),
      extra: ExploreFeedArgs(
        posts: results,
        startIndex: index < 0 ? 0 : index,
        serverId: serverId,
        nextCursor: ref.read(postSearchProvider).nextCursor,
        hasMore: ref.read(postSearchProvider).hasMore,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postSearchProvider);
    return Column(
      children: [
        _SearchBar(
          controller: _controller,
          focus: _focus,
          onChanged: _onChanged,
          onSubmitted: _commit,
          onClear: () {
            _controller.clear();
            ref.read(postSearchProvider.notifier).clear();
            _focus.requestFocus();
          },
          onCancel: () {
            ref.read(postSearchProvider.notifier).clear();
            widget.onClose();
          },
        ),
        Expanded(
          child: _controller.text.trim().length < _minChars
              ? _RecentList(
                  recent: _recent,
                  onTap: _runRecent,
                  onRemove: _removeRecent,
                  onClearAll: _clearAll,
                )
              : _Results(
                  state: state,
                  scroll: _scroll,
                  onTap: _openResult,
                ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                focusNode: focus,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search posts...',
                  hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      color: AppColors.textTertiary,
                      fontSize: 14),
                  prefixIcon: const Icon(LucideIcons.search,
                      size: 18, color: AppColors.textTertiary),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            color: AppColors.textTertiary,
                            onPressed: onClear,
                            tooltip: 'Clear',
                          ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F3F5),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({
    required this.recent,
    required this.onTap,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<String> recent;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) return const SizedBox.shrink();
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent searches',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              GestureDetector(
                onTap: onClearAll,
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final q in recent)
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F3F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.clock,
                  size: 18, color: AppColors.textSecondary),
            ),
            title: Text(
              q,
              style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 15, color: Color(0xFF0F172A)),
            ),
            trailing: IconButton(
              icon: const Icon(LucideIcons.x, size: 16),
              color: AppColors.textTertiary,
              onPressed: () => onRemove(q),
              tooltip: 'Remove',
            ),
            onTap: () => onTap(q),
          ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.state,
    required this.scroll,
    required this.onTap,
  });

  final PostSearchState state;
  final ScrollController scroll;
  final ValueChanged<Post> onTap;

  @override
  Widget build(BuildContext context) {
    if (state.results.isEmpty) {
      if (state.hasError) {
        return const Center(
          child: Text(
            'Something went wrong. Try again.',
            style:
                TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
          ),
        );
      }
      // Spinner while the request is in flight OR during the debounce window
      // before the first run for this term (avoids an empty-grid flash).
      if (state.isLoading || !state.hasSearched) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Text(
          'No posts found for "${state.query}"',
          style: const TextStyle(
              fontFamily: 'Inter', color: AppColors.textSecondary),
        ),
      );
    }
    return GridView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(2),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: state.results.length + (state.hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == state.results.length) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final p = state.results[i];
        return GestureDetector(
          onTap: () => onTap(p),
          child: p.imageUrl != null && p.imageUrl!.isNotEmpty
              ? Image.network(p.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: AppColors.surface))
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
    );
  }
}
