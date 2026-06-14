import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
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
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ref.read(serverDetailApiProvider).getById(widget.serverId),
        ref.read(serverMembersApiProvider).getMembers(widget.serverId, limit: 50),
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
    if (changed && mounted) _load();
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
      await ref.read(myServersProvider.notifier).fetch();
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(
            title: 'Ownership transferred. You have left ${_detail?.name ?? 'the server'}.',
          );
      if (context.canPop()) context.pop();
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
      appBar: VAppBar(
        title: _detail?.name ?? 'Members',
        leading: VAppBarLeading.back,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator.adaptive(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _ServerHeader(detail: _detail, myRole: _myRole),
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
                    _sectionHeader('ADMINS  —  ${admins.length}'),
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
                    _sectionHeader('MEMBERS  —  ${members.length}'),
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
  const _ServerHeader({this.detail, required this.myRole});

  final ServerDetail? detail;
  final String myRole;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 100,
          width: double.infinity,
          child: d?.bannerUrl != null
              ? Image.network(d!.bannerUrl!, fit: BoxFit.cover)
              : DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF007BFF), Color(0xFF0056CC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d?.name ?? '',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (d != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${myRole.toUpperCase()} · ${d.memberCount} member${d.memberCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (myRole == 'Owner' || myRole == 'Admin') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shield,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          myRole == 'Owner'
                              ? 'As owner, you can manage members and transfer ownership.'
                              : 'As admin, you can remove members from this server.',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
      ],
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
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F3F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
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
