import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum VAvatarSize { xs, sm, md, lg, xl }

/// Round user/server avatar. Falls back to a colored initial when [url] is
/// null/empty or fails to load.
class VAvatar extends StatelessWidget {
  const VAvatar({
    super.key,
    this.url,
    required this.fallbackInitial,
    this.size = VAvatarSize.md,
    this.background,
    this.foreground,
  });

  final String? url;
  final String fallbackInitial;
  final VAvatarSize size;
  final Color? background;
  final Color? foreground;

  double get _diameter {
    switch (size) {
      case VAvatarSize.xs:
        return 24;
      case VAvatarSize.sm:
        return 32;
      case VAvatarSize.md:
        return 40;
      case VAvatarSize.lg:
        return 56;
      case VAvatarSize.xl:
        return 96;
    }
  }

  double get _fontSize {
    switch (size) {
      case VAvatarSize.xs:
        return 10;
      case VAvatarSize.sm:
        return 13;
      case VAvatarSize.md:
        return 16;
      case VAvatarSize.lg:
        return 22;
      case VAvatarSize.xl:
        return 36;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = background ?? AppColors.primarySoft;
    final fg = foreground ?? AppColors.primary;
    final initial = fallbackInitial.isEmpty
        ? '?'
        : fallbackInitial.characters.first.toUpperCase();

    final placeholder = Container(
      width: _diameter,
      height: _diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        initial,
        style: AppTextStyles.body.copyWith(
          color: fg,
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipOval(
      child: Image.network(
        url!,
        width: _diameter,
        height: _diameter,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder;
        },
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}
