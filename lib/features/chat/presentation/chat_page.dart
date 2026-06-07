import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/util/relative_time.dart';
import '../../server/data/server_repository.dart';
import '../data/chat_api.dart';
import '../data/chat_ws.dart';
import '../domain/chat_models.dart';

enum _ChatFilter { all, unread }

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _search = TextEditingController();
  _ChatFilter _filter = _ChatFilter.all;
  String _query = '';
  List<DmConversationItem> _conversations = const [];
  bool _loading = false;
  final Map<String, bool> _typingMap = {};
  final Map<String, Timer> _typingTimers = {};
  final Map<String, bool> _onlineMap = {};
  StreamSubscription<WsEvent>? _wsSub;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _subscribeWs();
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _search.dispose();
    super.dispose();
  }

  void _subscribeWs() {
    _wsSub = ref.read(chatWsServiceProvider).events.listen((event) {
      if (!mounted) return;
      switch (event.type) {
        case WsEventType.messageNew:
          _load();
        case WsEventType.presence:
          final userId = event.payload['userId'] as String?;
          final online = event.payload['online'] as bool? ?? false;
          if (userId != null) setState(() => _onlineMap[userId] = online);
        case WsEventType.typing:
          final convoId = event.payload['conversationId'] as String?;
          final isTyping = event.payload['isTyping'] as bool? ?? false;
          if (convoId == null) return;
          setState(() => _typingMap[convoId] = isTyping);
          _typingTimers[convoId]?.cancel();
          if (isTyping) {
            _typingTimers[convoId] = Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _typingMap[convoId] = false);
            });
          }
        default:
          break;
      }
    });
  }

  Future<void> _load() async {
    final serverId = ref.read(myServersProvider).activeServerId;
    if (serverId == null) return;

    setState(() => _loading = true);
    try {
      final page =
          await ref.read(chatApiProvider).listConversations(serverId);
      if (!mounted) return;
      setState(() => _conversations = page.data);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e, onRetry: _load);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DmConversationItem> get _visible {
    final q = _query.trim().toLowerCase();
    var list = _conversations.toList();
    if (_filter == _ChatFilter.unread) {
      list = list.where((c) => c.unreadCount > 0).toList();
    }
    if (q.isEmpty) return list;
    return list
        .where((c) =>
            c.peer.nickname.toLowerCase().contains(q) ||
            c.peer.username.toLowerCase().contains(q) ||
            (c.lastMessagePreview ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _openConversation(DmConversationItem c) async {
    await context.push(
      Routes.chatConversation(c.id),
      extra: ChatConversationArgs(
        peerUserId: c.peerUserId,
        peerNickname: c.peer.nickname,
        peerAvatarUrl: c.peer.avatarUrl,
        peerIsOnline: _onlineMap[c.peerUserId] ?? c.isOnline,
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final activeServerId = ref.watch(
      myServersProvider.select((s) => s.activeServerId),
    );
    final unreadCount = _conversations.where((c) => c.unreadCount > 0).length;
    final visible = _visible;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/app/home'),
            ),
            _Search(controller: _search),
            _FilterStrip(
              active: _filter,
              unreadCount: unreadCount,
              onTap: (f) => setState(() => _filter = f),
            ),
            Expanded(
              child: activeServerId == null
                  ? const _EmptyNoServer()
                  : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : visible.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Belum ada percakapan.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(top: 8),
                                itemCount: visible.length,
                                itemBuilder: (_, i) => _ThreadRow(
                                  conversation: visible[i],
                                  isTyping: _typingMap[visible[i].id] ?? false,
                                  isOnline: _onlineMap[visible[i].peerUserId] ?? visible[i].isOnline,
                                  onTap: () => _openConversation(visible[i]),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNoServer extends StatelessWidget {
  const _EmptyNoServer();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Bergabung ke server terlebih dahulu untuk memulai percakapan.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textSecondary,
          ),
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
            child: Text(
              'Messages',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.17,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Cari pesan...',
            hintStyle: const TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textTertiary,
                fontSize: 14),
            prefixIcon: const Icon(LucideIcons.search,
                size: 18, color: AppColors.textTertiary),
            filled: true,
            fillColor: const Color(0xFFF1F3F5),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.active,
    required this.unreadCount,
    required this.onTap,
  });

  final _ChatFilter active;
  final int unreadCount;
  final ValueChanged<_ChatFilter> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: 'Semua',
            count: 0,
            active: active == _ChatFilter.all,
            onTap: () => onTap(_ChatFilter.all),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Belum Dibaca',
            count: unreadCount,
            active: active == _ChatFilter.unread,
            onTap: () => onTap(_ChatFilter.unread),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: active ? AppColors.primary : const Color(0xFFE9ECEF)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white : const Color(0xFF495057),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({
    required this.conversation,
    required this.isTyping,
    required this.isOnline,
    required this.onTap,
  });

  final DmConversationItem conversation;
  final bool isTyping;
  final bool isOnline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final peer = c.peer;
    final initial = peer.nickname.isNotEmpty
        ? peer.nickname.characters.first.toUpperCase()
        : '?';
    final timeLabel = c.lastMessageAt != null
        ? formatRelativeTime(c.lastMessageAt!.toIso8601String())
        : '';
    final unread = c.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarColorFor(peer.username),
                    shape: BoxShape.circle,
                  ),
                  child: peer.avatarUrl != null && peer.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(peer.avatarUrl!,
                              width: 56, height: 56, fit: BoxFit.cover))
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
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF28A745) : const Color(0xFFADB5BD),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          peer.nickname,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isTyping
                              ? 'mengetik...'
                              : (c.lastMessagePreview ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontStyle: isTyping
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: isTyping
                                ? AppColors.primary
                                : (unread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary),
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
