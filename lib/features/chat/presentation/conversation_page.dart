import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/util/relative_time.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../data/chat_api.dart';
import '../data/chat_ws.dart';
import '../domain/chat_models.dart';

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({
    super.key,
    required this.conversationId,
    this.peerUserId,
    this.peerNickname,
    this.peerAvatarUrl,
    this.peerIsOnline = false,
  });

  final String conversationId;
  final String? peerUserId;
  final String? peerNickname;
  final String? peerAvatarUrl;
  final bool peerIsOnline;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();

  List<DmMessageItem> _messages = const [];
  String? _nextCursor;
  bool _loadingInitial = false;
  bool _loadingOlder = false;
  bool _sending = false;
  bool _peerTyping = false;
  late bool _peerOnline;
  Timer? _typingTimer;
  Timer? _typingDebounce;
  StreamSubscription<WsEvent>? _wsSub;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _peerOnline = widget.peerIsOnline;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUser();
      _load();
      _subscribeWs();
      _markRead();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _typingDebounce?.cancel();
    _wsSub?.cancel();
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initUser() {
    final auth = ref.read(authRepositoryProvider).asData?.value;
    if (auth is AuthAuthenticated) {
      _currentUserId = auth.user.id;
    }
  }

  Future<void> _load() async {
    setState(() => _loadingInitial = true);
    try {
      final page = await ref.read(chatApiProvider).listMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        // Backend returns DESC (newest first) — store as-is for reverse ListView
        _messages = page.data;
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e, onRetry: _load);
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _nextCursor == null || _nextCursor!.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await ref.read(chatApiProvider).listMessages(
            widget.conversationId,
            cursor: _nextCursor,
          );
      if (!mounted) return;
      setState(() {
        // Append older messages at the end — reverse ListView shows them at top
        _messages = [..._messages, ...page.data];
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      // Silent: load-more failure is non-critical
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _onScroll() {
    // Reverse ListView: maxScrollExtent = scrolled all the way to top (oldest messages)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadOlder();
    }
  }

  void _subscribeWs() {
    _wsSub = ref.read(chatWsServiceProvider).events.listen((event) {
      if (!mounted) return;
      switch (event.type) {
        case WsEventType.messageNew:
          final payload = event.payload;
          if (payload['conversationId'] == widget.conversationId) {
            try {
              final msg = DmMessageItem.fromJson(payload);
              setState(() {
                // Prepend to front — newest at index 0 for reverse ListView
                _messages = [msg, ..._messages];
              });
              _markRead(lastReadMessageId: msg.id);
            } catch (_) {}
          }
        case WsEventType.typing:
          final convoId = event.payload['conversationId'] as String?;
          final userId = event.payload['userId'] as String?;
          final isTyping = event.payload['isTyping'] as bool? ?? false;
          if (convoId == widget.conversationId && userId != _currentUserId) {
            setState(() => _peerTyping = isTyping);
            if (isTyping) {
              _typingTimer?.cancel();
              _typingTimer = Timer(const Duration(seconds: 4), () {
                if (mounted) setState(() => _peerTyping = false);
              });
            }
          }
        case WsEventType.presence:
          final userId = event.payload['userId'] as String?;
          final online = event.payload['online'] as bool? ?? false;
          if (userId != null && userId == widget.peerUserId) {
            setState(() => _peerOnline = online);
          }
        case WsEventType.read:
          break;
        case WsEventType.unknown:
          break;
      }
    });
  }

  Future<void> _markRead({String? lastReadMessageId}) async {
    try {
      await ref.read(chatApiProvider).markRead(
            widget.conversationId,
            lastReadMessageId: lastReadMessageId,
          );
    } catch (_) {}
  }

  void _onTypingChanged() {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(chatWsServiceProvider).sendTyping(
            widget.conversationId,
            isTyping: _input.text.isNotEmpty,
          );
    });
  }

  Future<void> _send() async {
    final content = _input.text.trim();
    if (content.isEmpty || _sending) return;

    final clientId = generateClientMessageId();
    setState(() => _sending = true);

    // Optimistic send: stop typing signal
    ref.read(chatWsServiceProvider).sendTyping(widget.conversationId, isTyping: false);

    try {
      final msg = await ref.read(chatApiProvider).sendMessage(
            widget.conversationId,
            content: content,
            clientMessageId: clientId,
          );
      if (!mounted) return;
      _input.clear();
      setState(() {
        // Prepend at front (newest bottom in reverse ListView)
        // Avoid duplicate if WS already pushed it
        final alreadyAdded = _messages.any((m) => m.id == msg.id);
        if (!alreadyAdded) {
          _messages = [msg, ..._messages];
        }
      });
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peerNickname = widget.peerNickname ?? 'Chat';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: VAppBar(
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                _Avatar(
                  seed: peerNickname,
                  avatarUrl: widget.peerAvatarUrl,
                  size: 30,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _peerOnline ? const Color(0xFF28A745) : const Color(0xFFADB5BD),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerNickname,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_peerOnline)
                    const Text(
                      'Online',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF28A745),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loadingInitial
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No messages yet. Say hello!',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _messages.length +
                              (_loadingOlder ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _messages.length) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            final msg = _messages[i];
                            final isMine = msg.senderId == _currentUserId;
                            return _MessageBubble(
                              message: msg,
                              isMine: isMine,
                            );
                          },
                        ),
            ),
            if (_peerTyping)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.peerNickname ?? 'Peer'} is typing...',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            _Composer(
              controller: _input,
              loading: _sending,
              onSend: _send,
              onChanged: (_) => _onTypingChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final DmMessageItem message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  height: 1.4,
                  color: isMine ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              formatRelativeTime(message.createdAt.toIso8601String()),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed, this.avatarUrl, required this.size});

  final String seed;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = seed.isNotEmpty ? seed.characters.first.toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColorFor(seed),
        shape: BoxShape.circle,
      ),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Initial(initial: initial, size: size),
              ),
            )
          : _Initial(initial: initial, size: size),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: size * 0.45,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.loading,
    required this.onSend,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Ketik pesan...',
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textTertiary,
                  fontSize: 15,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: loading ? null : onSend,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.send, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
