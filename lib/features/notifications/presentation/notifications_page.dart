import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/notifications/notification_api.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/app_assets.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/util/relative_time.dart';
import '../../../mocks/notifications_mock.dart';

/// Real notification feed (replaces the mock). Fetches GET /api/notifications, maps the raw
/// payload to the existing NotificationItem UI model, marks read on tap (only when unread), and
/// deep-links to the related post.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _tab = 0;
  final List<NotificationItem> _items = [];
  String? _nextCursor;
  bool _loading = false;
  bool _hasMore = true;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (!refresh && !_hasMore) return;

    setState(() => _loading = true);
    try {
      final cursor = refresh ? null : _nextCursor;
      final data = await ref.read(notificationApiProvider).getNotifications(cursor: cursor);

      final rawItems = (data['data'] as List? ?? const []).cast<Map<String, dynamic>>();
      final page = data['page'] as Map<String, dynamic>?;
      final nextCursor = page?['nextCursor'] as String?;

      final mapped = rawItems.map(_mapItem).toList();

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _items
            ..clear()
            ..addAll(mapped);
        } else {
          _items.addAll(mapped);
        }
        _nextCursor = nextCursor;
        _hasMore = nextCursor != null && nextCursor.isNotEmpty;
      });
    } catch (_) {
      // Graceful — keep what we have.
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _initialLoaded = true;
        });
      }
    }
  }

  NotificationItem _mapItem(Map<String, dynamic> raw) {
    final type = raw['type'] as String? ?? '';
    final createdAtIso = raw['createdAt'] as String?;
    final createdAt = createdAtIso != null ? DateTime.tryParse(createdAtIso) : null;

    return NotificationItem(
      id: raw['id'] as String? ?? '',
      kind: _kindFromType(type),
      group: _groupFromDate(createdAt),
      actor: NotificationActor(
        username: raw['actorUsername'] as String? ?? '',
        avatarUrl: raw['actorAvatarUrl'] as String?,
      ),
      text: _textFromType(type),
      timeLabel: formatRelativeTime(createdAtIso),
      serverId: raw['serverId'] as String?,
      postId: raw['postId'] as String?,
      isRead: raw['readAt'] != null,
    );
  }

  NotificationKind _kindFromType(String type) {
    switch (type) {
      case 'like':
        return NotificationKind.like;
      case 'comment':
        return NotificationKind.comment;
      case 'reply':
        return NotificationKind.reply;
      case 'mention':
        return NotificationKind.mention;
      default:
        return NotificationKind.like;
    }
  }

  NotificationGroup _groupFromDate(DateTime? date) {
    if (date == null) return NotificationGroup.earlier;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 1) return NotificationGroup.newer;
    if (diff.inHours < 24 && now.day == date.day) return NotificationGroup.today;
    return NotificationGroup.earlier;
  }

  String _textFromType(String type) {
    switch (type) {
      case 'like':
        return 'menyukai postinganmu.';
      case 'comment':
        return 'mengomentari postinganmu.';
      case 'reply':
        return 'membalas komentarmu.';
      case 'mention':
        return 'menyebut kamu.';
      default:
        return 'berinteraksi denganmu.';
    }
  }

  Future<void> _onTap(NotificationItem item) async {
    // Only call the API when still unread — avoids redundant requests.
    if (!item.isRead) {
      setState(() => item.isRead = true);
      try {
        await ref.read(notificationApiProvider).markRead(item.id);
        ref.invalidate(unreadCountProvider);
      } catch (_) {
        // Roll back the optimistic flag on failure.
        if (mounted) setState(() => item.isRead = false);
      }
    }
    if (item.postId != null && item.postId!.isNotEmpty && mounted) {
      context.push(Routes.postDetail(item.postId!));
    }
  }

  List<NotificationItem> get _filtered {
    if (_tab == 1) {
      return _items.where((n) => n.kind == NotificationKind.mention).toList();
    }
    return _items;
  }

  Map<NotificationGroup, List<NotificationItem>> get _grouped {
    final out = <NotificationGroup, List<NotificationItem>>{
      NotificationGroup.newer: [],
      NotificationGroup.today: [],
      NotificationGroup.earlier: [],
    };
    for (final n in _filtered) {
      out[n.group]!.add(n);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;
    final isEmpty = _filtered.isEmpty && _initialLoaded && !_loading;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(),
            _Tabs(active: _tab, onTap: (i) => setState(() => _tab = i)),
            Expanded(
              child: isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: () => _load(refresh: true),
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          _Section(title: 'New', items: groups[NotificationGroup.newer]!, onTap: _onTap),
                          _Section(title: 'Today', items: groups[NotificationGroup.today]!, onTap: _onTap),
                          _Section(title: 'Earlier', items: groups[NotificationGroup.earlier]!, onTap: _onTap),
                          if (_hasMore && !_loading && _initialLoaded)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: TextButton(
                                  onPressed: () => _load(),
                                  child: const Text('Muat lebih banyak'),
                                ),
                              ),
                            ),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
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
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
      ),
      child: const Text(
        'Notifications',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.17,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.active, required this.onTap});

  final int active;
  final ValueChanged<int> onTap;

  static const _labels = ['All', 'Mentions'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final selected = i == active;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == _labels.length - 1 ? 0 : 8),
              child: Material(
                color: selected ? AppColors.primarySoft : const Color(0xFFF1F3F5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onTap(i),
                  child: SizedBox(
                    height: 36,
                    child: Center(
                      child: Text(
                        _labels[i],
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.primary : const Color(0xFF495057),
                        ),
                      ),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items, required this.onTap});

  final String title;
  final List<NotificationItem> items;
  final ValueChanged<NotificationItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.15,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          ...items.map((n) => _Row(item: n, onTap: () => onTap(n))),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  Color get _badgeColor {
    switch (item.kind) {
      case NotificationKind.like:
        return AppColors.error;
      case NotificationKind.comment:
        return AppColors.primary;
      case NotificationKind.reply:
        return const Color(0xFF7C3AED);
      case NotificationKind.mention:
        return const Color(0xFF10B981);
      case NotificationKind.follow:
        return AppColors.primary;
    }
  }

  IconData get _kindIcon {
    switch (item.kind) {
      case NotificationKind.like:
        return LucideIcons.heart;
      case NotificationKind.comment:
        return LucideIcons.messageCircle;
      case NotificationKind.reply:
        return LucideIcons.cornerDownRight;
      case NotificationKind.mention:
        return LucideIcons.atSign;
      case NotificationKind.follow:
        return LucideIcons.userPlus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = item.actor.username.isNotEmpty
        ? item.actor.username.characters.first.toUpperCase()
        : '?';
    return InkWell(
      onTap: onTap,
      child: Container(
        // Subtle unread highlight.
        color: item.isRead ? Colors.transparent : AppColors.primarySoft.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: avatarColorFor(item.actor.username),
                      shape: BoxShape.circle,
                    ),
                    child: item.actor.avatarUrl != null && item.actor.avatarUrl!.isNotEmpty
                        ? ClipOval(child: Image.network(item.actor.avatarUrl!, fit: BoxFit.cover))
                        : Text(
                            initial,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(_kindIcon, size: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF212529),
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: item.actor.username,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' ${item.text}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.timeLabel,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFFADB5BD),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.illustrationNotification, width: 240),
            const SizedBox(height: 24),
            const Text(
              'No notifications yet',
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
              "When someone likes or comments on your post, you'll see it here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF6C757D),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
