import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum VAppBarLeading { back, close, none }

/// Project AppBar wrapper and single source of truth for secondary-page
/// headers: a chevron-left back button on the left and a centered title.
/// Use over a raw Material AppBar so leading icon, title style, and the bottom
/// divider stay identical across every page.
class VAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading = VAppBarLeading.back,
    this.onLeadingTap,
    this.actions,
    this.centerTitle = true,
    this.showBorder = true,
    this.backgroundColor,
  }) : assert(title == null || titleWidget == null,
            'Provide either title or titleWidget, not both.');

  final String? title;
  final Widget? titleWidget;
  final VAppBarLeading leading;
  final VoidCallback? onLeadingTap;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showBorder;
  final Color? backgroundColor;

  static const _height = 56.0;
  // Matches IconButton's interactive size so a centered title stays visually
  // centered when there are no actions to balance the leading slot.
  static const _sideSlot = 48.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  Widget? _buildLeading(BuildContext context) {
    switch (leading) {
      case VAppBarLeading.none:
        return null;
      case VAppBarLeading.back:
        return IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          tooltip: 'Back',
          onPressed: onLeadingTap ?? () => Navigator.maybeOf(context)?.maybePop(),
        );
      case VAppBarLeading.close:
        return IconButton(
          icon: const Icon(LucideIcons.x),
          tooltip: 'Close',
          onPressed: onLeadingTap ?? () => Navigator.maybeOf(context)?.maybePop(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadingWidget = _buildLeading(context);
    final Widget? trailingWidget = actions != null
        ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
        : (leadingWidget != null ? const SizedBox(width: _sideSlot) : null);

    return Material(
      color: backgroundColor ?? AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: _height,
          decoration: showBorder
              ? const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                )
              : null,
          child: NavigationToolbar(
            leading: leadingWidget,
            middle: titleWidget ??
                (title != null
                    ? Text(
                        title!,
                        style: AppTextStyles.bodyStrong.copyWith(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      )
                    : null),
            trailing: trailingWidget,
            centerMiddle: centerTitle,
            middleSpacing: AppSpacing.sm,
          ),
        ),
      ),
    );
  }
}
