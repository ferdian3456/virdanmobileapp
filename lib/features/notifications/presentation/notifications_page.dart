import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/util/app_assets.dart';
import '../../../core/util/avatar_color.dart';
import '../../../mocks/notifications_mock.dart';

/// Mirrors Quasar NotificationsPage.vue: centered title header, 2 full-width
/// tab pills (All / Mentions), grouped sections (New / Today / Earlier),
/// row = 40px avatar with kind badge + text (username bold inline) + time
/// on separate line + trailing Follow rect button OR 40px thumbnail.
/// Empty state uses notification.svg.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int _tab = 0;
  late final List<NotificationItem> _items =
      List<NotificationItem>.of(mockNotifications);

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

  void _toggleFollow(NotificationItem item) {
    setState(() => item.isFollowing = !item.isFollowing);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;
    final isEmpty = _filtered.isEmpty;
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
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        _Section(
                          title: 'New',
                          items: groups[NotificationGroup.newer]!,
                          onFollow: _toggleFollow,
                        ),
                        _Section(
                          title: 'Today',
                          items: groups[NotificationGroup.today]!,
                          onFollow: _toggleFollow,
                        ),
                        _Section(
                          title: 'Earlier',
                          items: groups[NotificationGroup.earlier]!,
                          onFollow: _toggleFollow,
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
  const _Section({
    required this.title,
    required this.items,
    required this.onFollow,
  });

  final String title;
  final List<NotificationItem> items;
  final ValueChanged<NotificationItem> onFollow;

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
          ...items.map((n) => _Row(item: n, onFollow: () => onFollow(n))),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onFollow});

  final NotificationItem item;
  final VoidCallback onFollow;

  Color get _badgeColor {
    switch (item.kind) {
      case NotificationKind.like:
        return AppColors.error;
      case NotificationKind.comment:
        return AppColors.primary;
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar + badge
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
                      ? ClipOval(
                          child: Image.network(item.actor.avatarUrl!, fit: BoxFit.cover))
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
          // Text (username + body) inline; time on its own line below.
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
          const SizedBox(width: 12),
          // Trailing — follow button OR thumbnail.
          if (item.showFollowAction)
            _FollowButton(active: item.isFollowing, onTap: onFollow)
          else if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.thumbnailUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 40,
                  height: 40,
                  color: const Color(0xFFF1F3F5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFF1F3F5) : AppColors.primary;
    final fg = active ? const Color(0xFF495057) : Colors.white;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            active ? 'Following' : 'Follow',
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
