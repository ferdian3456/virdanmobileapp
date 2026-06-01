import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/notifications/notification_api.dart';
import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../features/server/data/server_repository.dart';

/// Shell for /app/*. Renders a bottom tab bar; selected index is derived from
/// the current route. `StatefulShellRoute` migration is deferred to Phase 6.
class MainLayout extends ConsumerWidget {
  const MainLayout({super.key, required this.child});

  final Widget child;

  static const _tabs = <_TabItem>[
    _TabItem(label: 'Home', route: Routes.appHome, icon: LucideIcons.house),
    _TabItem(label: 'Explore', route: Routes.appExplore, icon: LucideIcons.search),
    _TabItem(label: 'Create', route: Routes.appCreate, icon: LucideIcons.circlePlus),
    _TabItem(label: 'Activity', route: Routes.appNotifications, icon: LucideIcons.heart),
    _TabItem(label: 'Profile', route: Routes.appProfile, icon: LucideIcons.circleUser),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    var currentIndex = _tabs.indexWhere((t) => location.startsWith(t.route));
    if (currentIndex < 0) currentIndex = 0;

    final activeServerId = ref.watch(myServersProvider.select((s) => s.activeServerId));
    final unreadCount = activeServerId == null
        ? 0
        : (ref.watch(unreadCountProvider(activeServerId)).asData?.value ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final active = i == currentIndex;
                final isActivity = tab.route == Routes.appNotifications;
                final icon = Icon(
                  tab.icon,
                  size: 28,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                );
                return Expanded(
                  child: InkResponse(
                    onTap: () {
                      // Refresh the unread count when entering the Activity tab.
                      if (isActivity) ref.invalidate(unreadCountProvider);
                      context.go(tab.route);
                    },
                    radius: 36,
                    child: Center(
                      child: isActivity && unreadCount > 0
                          ? Badge(
                              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                              child: icon,
                            )
                          : icon,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, required this.route, required this.icon});

  final String label;
  final String route;
  final IconData icon;
}
