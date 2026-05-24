import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Centered layout used for /auth/* and /onboarding/*.
class BlankLayout extends StatelessWidget {
  const BlankLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}
