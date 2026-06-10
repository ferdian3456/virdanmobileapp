import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/util/avatar_color.dart';
import '../../../mocks/chat_mock.dart';

/// Mirrors Quasar ChatPage.vue: header (back + Messages), search input,
/// filter chips (All / Unread / Requests with counts), thread rows
/// (avatar + name + lastMessage + time + unread dot + typing indicator),
/// mock disclaimer footer.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _search = TextEditingController();
  ChatFilter _filter = ChatFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ChatThread> get _visible {
    final q = _query.trim().toLowerCase();
    var list = mockChatThreads.toList();
    if (_filter == ChatFilter.unread) {
      list = list.where((t) => t.unread).toList();
    } else if (_filter == ChatFilter.requests) {
      list = list.where((t) => t.isRequest).toList();
    }
    if (q.isEmpty) return list;
    return list
        .where((t) =>
            t.username.toLowerCase().contains(q) ||
            (t.fullname ?? '').toLowerCase().contains(q) ||
            t.lastMessage.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = mockChatThreads.where((t) => t.unread).length;
    final requestCount = mockChatThreads.where((t) => t.isRequest).length;
    final visible = _visible;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.canPop() ? context.pop() : context.go('/app/home')),
            _Search(controller: _search),
            _FilterStrip(
              active: _filter,
              unreadCount: unreadCount,
              requestCount: requestCount,
              onTap: (f) => setState(() => _filter = f),
            ),
            Expanded(
<<<<<<< Updated upstream
              child: visible.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No conversations yet.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: visible.length,
                      itemBuilder: (_, i) => _ThreadRow(thread: visible[i]),
                    ),
=======
              child: activeServerId == null
                  ? const _EmptyNoServer()
                  : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : visible.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No conversations yet.',
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
>>>>>>> Stashed changes
            ),
            const _MockNote(),
          ],
        ),
      ),
    );
  }
}

<<<<<<< Updated upstream
=======
class _EmptyNoServer extends StatelessWidget {
  const _EmptyNoServer();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Join a server first to start a conversation.',
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

>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
            hintText: 'Search messages…',
=======
            hintText: 'Search messages...',
>>>>>>> Stashed changes
            hintStyle: const TextStyle(
                fontFamily: 'Inter', color: AppColors.textTertiary, fontSize: 14),
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
    required this.requestCount,
    required this.onTap,
  });

  final ChatFilter active;
  final int unreadCount;
  final int requestCount;
  final ValueChanged<ChatFilter> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: 'All',
            count: 0,
            active: active == ChatFilter.all,
            onTap: () => onTap(ChatFilter.all),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Unread',
            count: unreadCount,
            active: active == ChatFilter.unread,
            onTap: () => onTap(ChatFilter.unread),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Requests',
            count: requestCount,
            active: active == ChatFilter.requests,
            onTap: () => onTap(ChatFilter.requests),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: active ? Colors.white.withValues(alpha: 0.2) : AppColors.primary,
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
  const _ThreadRow({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final initial = thread.username.characters.first.toUpperCase();
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: avatarColorFor(thread.username),
                shape: BoxShape.circle,
              ),
              child: thread.avatarUrl != null && thread.avatarUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(thread.avatarUrl!, fit: BoxFit.cover))
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.fullname ?? thread.username,
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
                        thread.timeLabel,
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
<<<<<<< Updated upstream
                          thread.typing ? 'typing…' : thread.lastMessage,
=======
                          isTyping
                              ? 'typing...'
                              : (c.lastMessagePreview ?? ''),
>>>>>>> Stashed changes
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: thread.typing
                                ? AppColors.primary
                                : (thread.unread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary),
                            fontWeight:
                                thread.unread ? FontWeight.w600 : FontWeight.w400,
                            fontStyle: thread.typing ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                      if (thread.unread)
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

class _MockNote extends StatelessWidget {
  const _MockNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: const Color(0xFFF8F9FA),
      child: const SafeArea(
        top: false,
        child: Text(
          "Messages backend isn't built yet — these conversations are placeholder data.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
