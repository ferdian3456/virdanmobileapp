import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../data/server_detail_api.dart';
import '../data/server_members_api.dart';
import '../data/server_repository.dart';
import '../domain/server.dart';
import '../domain/server_member.dart';
import 'widgets/member_action_sheet.dart';

class ServerMembersPage extends ConsumerStatefulWidget {
  const ServerMembersPage({
    super.key,
    required this.serverId,
    this.transferMode = false,
  });

  final String serverId;
  final bool transferMode;

  @override
  ConsumerState<ServerMembersPage> createState() => _ServerMembersPageState();
}

class _ServerMembersPageState extends ConsumerState<ServerMembersPage> {
  ServerDetail? _detail;
  List<ServerMember> _members = [];
  String? _nextCursor;
  bool _loading = true;
  String _myRole = '';
  bool _transferring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    debugPrint('[ServerMembersPage] _load() serverId="${widget.serverId}"');
    if (widget.serverId.isEmpty) {
      debugPrint('[ServerMembersPage] ABORT: serverId is empty');
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ref.read(serverDetailApiProvider).getById(widget.serverId),
        ref.read(serverMembersApiProvider).getMembers(widget.serverId, limit: 20),
        ref.read(serverMembersApiProvider).getMyRole(widget.serverId),
      ]);
      if (!mounted) return;
      final page = results[1] as CursorPage<ServerMember>;
      setState(() {
        _detail = results[0] as ServerDetail;
        _members = page.data;
        _nextCursor = page.nextCursor;
        _myRole = results[2] as String;
      });
    } catch (e) {
      if (mounted) showApiErrorToast(ref, e, onRetry: _load);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null) return;
    try {
      final page = await ref
          .read(serverMembersApiProvider)
          .getMembers(widget.serverId, cursor: cursor, limit: 50);
      if (!mounted) return;
      setState(() {
        _members = [..._members, ...page.data];
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      if (mounted) showApiErrorToast(ref, e);
    }
  }

  String? get _currentUserId {
    return switch (ref.read(authRepositoryProvider)) {
      AsyncData(value: AuthAuthenticated(:final user)) => user.id,
      _ => null,
    };
  }

  bool _canActOn(ServerMember target) {
    final uid = _currentUserId;
    if (uid == null || target.userId == uid || target.isOwner) return false;
    if (_myRole == 'Owner') return true;
    if (_myRole == 'Admin' && target.isMember) return true;
    return false;
  }

  Future<void> _onMoreTap(ServerMember target) async {
    final uid = _currentUserId;
    if (uid == null) return;
    final changed = await showMemberActionSheet(
      context: context,
      ref: ref,
      serverId: widget.serverId,
      target: target,
      viewerRole: _myRole,
      currentUserId: uid,
    );
    if (changed && mounted) {
      _load();
      // Refresh the joined-servers list so the servers page / settings reflect
      // the new member count and roles (kick, promote, demote).
      ref.read(myServersProvider.notifier).fetch(force: true);
    }
  }

  Future<void> _onTransferTap(ServerMember target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text('Transfer ownership to ${target.nickname}?'),
        content: const Text(
          'You will become Admin. The server will continue under new ownership.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Transfer & Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _transferring = true);
    try {
      await ref
          .read(serverMembersApiProvider)
          .transferOwnership(widget.serverId, target.userId);
      await ref.read(serverMembersApiProvider).leaveServer(widget.serverId);
      if (!mounted) return;
      // We are no longer a member. Capture the providers, then leave this page
      // before refreshing: refetching server detail/role in place would 403, and
      // the router's myServers refresh listener would rebuild this page into a
      // "not a member" error state. Navigate out, then refresh the servers list.
      final serverName = _detail?.name ?? 'the server';
      final toast = ref.read(toastControllerProvider.notifier);
      final myServers = ref.read(myServersProvider.notifier);
      context.go(Routes.settingsServers);
      toast.success(
        title: 'Ownership transferred. You have left $serverName.',
      );
      await myServers.fetch(force: true);
    } catch (e) {
      if (mounted) {
        setState(() => _transferring = false);
        showApiErrorToast(ref, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUserId;
    final owners = _members.where((m) => m.isOwner).toList();
    final admins = _members.where((m) => m.isAdmin).toList();
    final members = _members.where((m) => m.isMember).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(
        title: 'Server Detail',
        leading: VAppBarLeading.back,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator.adaptive(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _ServerHeader(
                      detail: _detail,
                      myRole: _myRole,
                      onEdit: _myRole == 'Owner'
                          ? () => context.push(Routes.serverSettings(widget.serverId))
                          : null,
                    ),
                  ),

                  if (widget.transferMode)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.arrowRightLeft,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Tap a member to transfer ownership and leave.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_transferring)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary),
                              ),
                          ],
                        ),
                      ),
                    ),

                  if (owners.isNotEmpty) ...[
                    _sectionHeader('OWNER'),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final m = owners[i];
                          return _MemberRow(
                            member: m,
                            isCurrentUser: m.userId == uid,
                            showMoreBtn: false,
                            transferMode: widget.transferMode,
                            onMoreTap: null,
                            onTap: null,
                          );
                        },
                        childCount: owners.length,
                      ),
                    ),
                  ],

                  if (admins.isNotEmpty) ...[
                    _sectionHeader('ADMINS — ${admins.length}'),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final m = admins[i];
                          final canAct = _canActOn(m);
                          final isSelf = m.userId == uid;
                          return _MemberRow(
                            member: m,
                            isCurrentUser: isSelf,
                            showMoreBtn: !widget.transferMode && canAct,
                            transferMode: widget.transferMode,
                            onMoreTap: canAct ? () => _onMoreTap(m) : null,
                            onTap: (widget.transferMode && !isSelf)
                                ? () => _onTransferTap(m)
                                : null,
                          );
                        },
                        childCount: admins.length,
                      ),
                    ),
                  ],

                  if (members.isNotEmpty) ...[
                    _sectionHeader('MEMBERS — ${members.length}'),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final m = members[i];
                          final canAct = _canActOn(m);
                          final isSelf = m.userId == uid;
                          return _MemberRow(
                            member: m,
                            isCurrentUser: isSelf,
                            showMoreBtn: !widget.transferMode && canAct,
                            transferMode: widget.transferMode,
                            onMoreTap: canAct ? () => _onMoreTap(m) : null,
                            onTap: (widget.transferMode && !isSelf)
                                ? () => _onTransferTap(m)
                                : null,
                          );
                        },
                        childCount: members.length,
                      ),
                    ),
                  ],

                  if (_nextCursor != null)
                    SliverToBoxAdapter(
                      child: TextButton(
                        onPressed: _loadMore,
                        child: const Text('Load more members'),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _ServerHeader extends StatelessWidget {
  const _ServerHeader({this.detail, required this.myRole, this.onEdit});

  final ServerDetail? detail;
  final String myRole;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final bannerUrl = d?.bannerUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Banner — rounded card with horizontal margin (avatar overlaps it).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: bannerUrl != null && bannerUrl.isNotEmpty
                      ? Image.network(bannerUrl, fit: BoxFit.cover)
                      : const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF0056CC), Color(0xFF007BFF)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: SizedBox.expand(),
                        ),
                ),
              ),
            ),
            // Avatar overlapping banner
            Positioned(
              bottom: -28,
              child: _ServerAvatar(
                name: d?.name ?? '',
                avatarUrl: d?.avatarUrl,
              ),
            ),
            // Edit-server shortcut (owner only).
            if (onEdit != null)
              Positioned(
                top: 8,
                right: 24,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEdit,
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(LucideIcons.settings,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 36), // space for avatar overlap

        // Server name + verified
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              d?.name ?? '',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(LucideIcons.badgeCheck,
                size: 18, color: AppColors.primary),
          ],
        ),
        const SizedBox(height: 6),

        // Role chip + member count
        if (d != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoleChip(role: myRole),
              const SizedBox(width: 8),
              const Text(
                '·',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${d.memberCount} member${d.memberCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

        const SizedBox(height: 16),

        // Info banner (owner/admin only)
        if (myRole == 'Owner' || myRole == 'Admin')
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(LucideIcons.shieldCheck,
                      size: 15, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    myRole == 'Owner'
                        ? 'You can promote members to admin, demote admins, and remove anyone.'
                        : 'You can remove members from this server.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE9ECEF)),
      ],
    );
  }
}

class _ServerAvatar extends StatelessWidget {
  const _ServerAvatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final url = avatarUrl;
    Widget inner;
    if (url != null && url.isNotEmpty) {
      inner = ClipOval(
        child: Image.network(url, width: size, height: size, fit: BoxFit.cover),
      );
    } else {
      inner = CircleAvatar(
        radius: size / 2,
        backgroundColor: avatarColorFor(name),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: ClipOval(child: inner),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (role) {
      case 'Owner':
        bg = AppColors.primary;
        fg = Colors.white;
      case 'Admin':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFD97706);
      default:
        bg = const Color(0xFFF1F3F5);
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isCurrentUser,
    required this.showMoreBtn,
    required this.transferMode,
    this.onMoreTap,
    this.onTap,
  });

  final ServerMember member;
  final bool isCurrentUser;
  final bool showMoreBtn;
  final bool transferMode;
  final VoidCallback? onMoreTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = member.avatarUrl;
    Widget avatar;
    if (url != null && url.isNotEmpty) {
      avatar = CircleAvatar(radius: 20, backgroundImage: NetworkImage(url));
    } else {
      avatar = CircleAvatar(
        radius: 20,
        backgroundColor: avatarColorFor(member.nickname),
        child: Text(
          member.nickname.isNotEmpty ? member.nickname[0].toUpperCase() : '?',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.nickname,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 5),
                        _InlineChip(
                          label: 'YOU',
                          bg: const Color(0xFFF1F3F5),
                          fg: AppColors.textSecondary,
                        ),
                      ],
                      if (member.isOwner) ...[
                        const SizedBox(width: 5),
                        _InlineChip(
                          label: 'OWNER',
                          bg: AppColors.primary,
                          fg: Colors.white,
                        ),
                      ] else if (member.isAdmin) ...[
                        const SizedBox(width: 5),
                        _InlineChip(
                          label: 'ADMIN',
                          bg: const Color(0xFFFFF8E1),
                          fg: const Color(0xFFD97706),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '@${member.username}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (transferMode && !isCurrentUser && !member.isOwner)
              const Icon(LucideIcons.chevronRight,
                  size: 18, color: AppColors.textTertiary)
            else if (showMoreBtn && onMoreTap != null)
              IconButton(
                icon: const Icon(LucideIcons.ellipsis,
                    size: 20, color: AppColors.textSecondary),
                onPressed: onMoreTap,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  const _InlineChip({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
