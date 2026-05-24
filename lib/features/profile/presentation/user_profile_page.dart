import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_app_bar.dart';

/// Read-only view of another user's profile keyed by userId.
/// Phase 5 placeholder — proper hooks land once the BE exposes a public
/// user-by-id endpoint.
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final initial = userId.isNotEmpty ? userId.characters.first.toUpperCase() : '?';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(leading: VAppBarLeading.back),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColorFor(userId),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '@$userId',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Public user profile lands when BE exposes the endpoint.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
