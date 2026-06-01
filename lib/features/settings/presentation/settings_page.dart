import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/http/dio_client.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/avatar_color.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../../profile/data/profile_api.dart';
import '../../server/data/server_repository.dart';

/// Mirrors Quasar SettingsPage.vue: per-server identity summary header,
/// 4 grouped sections (ACCOUNT / PREFERENCES / NOTIFICATIONS / ABOUT &
/// SUPPORT) with row icon + label + optional value/badge + chevron,
/// outlined-red "Sign Out" CTA at bottom.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  ServerMemberProfile? _profile;
  bool _loggingOut = false;
  bool _testingNotification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final sid = ref.read(myServersProvider).activeServerId;
    if (sid == null) return;
    try {
      final p = await ref.read(profileApiProvider).meForServer(sid);
      if (!mounted) return;
      setState(() => _profile = p);
    } catch (_) {
      // Silent — header gracefully degrades to email.
    }
  }

  Future<void> _testNotification() async {
    if (_testingNotification) return;
    setState(() => _testingNotification = true);
    try {
      await ref.read(apiDioProvider).post('/notifications/test-send');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent. Check your device.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send test notification.')),
      );
    } finally {
      if (mounted) setState(() => _testingNotification = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await ref.read(authRepositoryProvider.notifier).logout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = switch (ref.watch(authRepositoryProvider)) {
      AsyncData(value: AuthAuthenticated(:final user)) => user.email,
      _ => '',
    };
    final profile = _profile;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.canPop() ? context.pop() : context.go('/app/home')),
            Expanded(
              child: ListView(
                children: [
                  _ProfileSummary(
                    nickname: profile?.nickname ?? email,
                    username: profile?.username,
                    avatarUrl: profile?.avatarUrl,
                  ),
                  _Section(title: 'ACCOUNT', children: [
                    _Row(
                      icon: LucideIcons.user,
                      label: 'Edit Profile',
                      onTap: () => context.push(Routes.appEditProfile),
                    ),
                    _Row(
                      icon: LucideIcons.mail,
                      label: 'Change Email',
                      onTap: () => context.push(Routes.settingsEmail),
                    ),
                    _Row(
                      icon: LucideIcons.lock,
                      label: 'Change Password',
                      onTap: () => context.push(Routes.settingsPassword),
                    ),
                    _Row(
                      icon: LucideIcons.shield,
                      label: 'Privacy & Security',
                      onTap: () => context.push(Routes.settingsPrivacy),
                    ),
                    _Row(
                      icon: LucideIcons.ban,
                      label: 'Blocked Users',
                      badge: '3',
                      disabled: true,
                    ),
                  ]),
                  _Section(title: 'PREFERENCES', children: const [
                    _Row(
                      icon: LucideIcons.globe,
                      label: 'Language',
                      value: 'English',
                      disabled: true,
                    ),
                    _Row(
                      icon: LucideIcons.sun,
                      label: 'Theme',
                      value: 'Light',
                      disabled: true,
                    ),
                  ]),
                  _Section(title: 'NOTIFICATIONS', children: [
                    _Row(
                      icon: LucideIcons.bell,
                      label: 'Notification Settings',
                      onTap: () => context.push(Routes.settingsNotifications),
                    ),
                    _Row(
                      icon: LucideIcons.send,
                      label: _testingNotification ? 'Sending…' : 'Test Notification',
                      onTap: _testingNotification ? null : _testNotification,
                    ),
                  ]),
                  _Section(title: 'ABOUT & SUPPORT', children: [
                    _Row(
                      icon: LucideIcons.circleHelp,
                      label: 'Help Center',
                      onTap: () => context.push(Routes.settingsHelp),
                    ),
                    _Row(
                      icon: LucideIcons.fileText,
                      label: 'Terms of Service',
                      onTap: () => context.push(Routes.settingsTerms),
                    ),
                    _Row(
                      icon: LucideIcons.shieldCheck,
                      label: 'Privacy Policy',
                      onTap: () => context.push(Routes.settingsPrivacyPolicy),
                    ),
                  ]),
                  _LogoutSection(loggingOut: _loggingOut, onTap: _logout),
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
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 24),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Settings',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.17,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.nickname,
    required this.username,
    required this.avatarUrl,
  });

  final String nickname;
  final String? username;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = nickname.isNotEmpty ? nickname.characters.first.toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
      ),
      child: Row(
        children: [
          ClipOval(
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? Image.network(
                    avatarUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallback(initial),
                  )
                : _fallback(initial),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (username != null && username!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(String initial) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColorFor(nickname),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.88,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.badge,
    this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? badge;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = (disabled || onTap == null) ? null : onTap;
    return InkWell(
      onTap: effectiveOnTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Opacity(
              opacity: disabled ? 0.7 : 1,
              child: SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: Icon(icon, size: 20, color: const Color(0xFF495057)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.15,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  value!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else if (badge != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Opacity(
              opacity: disabled ? 0.7 : 1,
              child: const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutSection extends StatelessWidget {
  const _LogoutSection({required this.loggingOut, required this.onTap});

  final bool loggingOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Left-aligned row matching the other settings items; neutral (non-red)
    // colors. The logOut icon still signals the action.
    return Column(
      children: [
        const SizedBox(height: 16),
        InkWell(
          onTap: loggingOut ? null : onTap,
          child: Opacity(
            opacity: loggingOut ? 0.6 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: Icon(LucideIcons.logOut, size: 20, color: Color(0xFF495057)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    loggingOut ? 'Signing out…' : 'Sign Out',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
