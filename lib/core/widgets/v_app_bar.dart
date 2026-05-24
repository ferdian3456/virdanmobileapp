import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum VAppBarLeading { back, close, none }

/// Project AppBar wrapper. Use over raw Material AppBar so leading icon style
/// (lucide arrow vs X) and bottom divider stay consistent across pages.
class VAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading = VAppBarLeading.back,
    this.onLeadingTap,
    this.actions,
    this.centerTitle = false,
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

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  Widget? _buildLeading(BuildContext context) {
    switch (leading) {
      case VAppBarLeading.none:
        return null;
      case VAppBarLeading.back:
        return IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
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
            leading: _buildLeading(context),
            middle: titleWidget ??
                (title != null
                    ? Text(
                        title!,
                        style: AppTextStyles.h3,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null),
            trailing: actions == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  ),
            centerMiddle: centerTitle,
            middleSpacing: AppSpacing.sm,
          ),
        ),
      ),
    );
  }
}
