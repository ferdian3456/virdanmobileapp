import 'package:flutter/foundation.dart';

enum ChatFilter { all, unread, requests }

@immutable
class ChatThread {
  const ChatThread({
    required this.id,
    required this.username,
    required this.lastMessage,
    required this.timeLabel,
    this.fullname,
    this.avatarUrl,
    this.unread = false,
    this.typing = false,
    this.isRequest = false,
  });

  final String id;
  final String username;
  final String? fullname;
  final String? avatarUrl;
  final String lastMessage;
  final String timeLabel;
  final bool unread;
  final bool typing;
  final bool isRequest;
}

const mockChatThreads = <ChatThread>[
  ChatThread(
    id: 'th-1',
    username: 'jane_doe',
    fullname: 'Jane Doe',
    lastMessage: 'Sounds good — let me check.',
    timeLabel: '2m',
    unread: true,
    typing: true,
  ),
  ChatThread(
    id: 'th-2',
    username: 'mike_studio',
    fullname: 'Mike Studio',
    lastMessage: 'Sent the brief over, take a look',
    timeLabel: '1h',
    unread: true,
  ),
  ChatThread(
    id: 'th-3',
    username: 'amy_art',
    fullname: 'Amy Art',
    lastMessage: 'Yes! Can do tomorrow morning.',
    timeLabel: '4h',
  ),
  ChatThread(
    id: 'th-4',
    username: 'creative_agency',
    fullname: 'Creative Agency',
    lastMessage: 'We loved the latest piece.',
    timeLabel: 'Yesterday',
  ),
  ChatThread(
    id: 'th-5',
    username: 'lisa_travels',
    fullname: 'Lisa Travels',
    lastMessage: 'Hi! I saw your post and…',
    timeLabel: '2d',
    isRequest: true,
  ),
];
