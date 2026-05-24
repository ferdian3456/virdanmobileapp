import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../../server/data/server_repository.dart';
import '../../server/domain/server.dart';

class YourProfilePage extends ConsumerWidget {
  const YourProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = switch (ref.watch(authRepositoryProvider)) {
      AsyncData(value: AuthAuthenticated(:final user)) => user.email,
      _ => '',
    };
    final servers = ref.watch(myServersProvider).servers;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            _ProfileHeader(
              email: email,
              onSettings: () => context.push('/settings'),
            ),
            _Stats(servers: servers.length),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'YOUR IDENTITIES',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            if (servers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'You have no per-server identities yet.\nJoin a server to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: servers.length,
                itemBuilder: (_, i) => _IdentityTile(server: servers[i]),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.email, required this.onSettings});

  final String email;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 16),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatarColorFor(email),
              shape: BoxShape.circle,
            ),
            child: Text(
              email.isNotEmpty ? email.characters.first.toUpperCase() : '?',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 4),
                Text(
                  'You can have a different nickname per server.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings, size: 22),
            onPressed: onSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.servers});

  final int servers;

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, String label) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          cell('$servers', 'Servers'),
          cell('0', 'Posts'),
          cell('0', 'Following'),
        ],
      ),
    );
  }
}

class _IdentityTile extends StatelessWidget {
  const _IdentityTile({required this.server});

  final Server server;

  @override
  Widget build(BuildContext context) {
    final initial = (server.shortName.isNotEmpty ? server.shortName : server.name)
        .characters
        .first
        .toUpperCase();
    return InkWell(
      onTap: () => GoRouter.of(context).push('/server/${server.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatarColorFor(server.shortName.isNotEmpty ? server.shortName : server.name),
              borderRadius: BorderRadius.circular(14),
            ),
            child: server.avatarUrl != null && server.avatarUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(server.avatarUrl!, fit: BoxFit.cover),
                  )
                : Text(
                    initial,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            server.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

