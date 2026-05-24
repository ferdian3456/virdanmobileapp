import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Bottom-tab layout for /app/*. Tab list + state preservation wired in Phase
/// 6 polish (StatefulShellRoute). Phase 0 stub: just renders child with safe
/// area.
class MainLayout extends StatelessWidget {
  const MainLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: child),
    );
  }
}
