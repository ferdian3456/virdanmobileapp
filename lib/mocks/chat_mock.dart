import 'package:flutter/foundation.dart';

@immutable
class MockChatThread {
  const MockChatThread({
    required this.id,
    required this.peerNickname,
    required this.lastMessage,
    required this.timeAgo,
    this.unread = 0,
  });

  final String id;
  final String peerNickname;
  final String lastMessage;
  final String timeAgo;
  final int unread;
}

const mockChatThreads = <MockChatThread>[
  MockChatThread(
    id: 'c1',
    peerNickname: 'kira',
    lastMessage: "Saw your post — that's gorgeous 🌅",
    timeAgo: '2m',
    unread: 2,
  ),
  MockChatThread(
    id: 'c2',
    peerNickname: 'arjuna',
    lastMessage: 'Let me know when the next meetup is',
    timeAgo: '1h',
  ),
  MockChatThread(
    id: 'c3',
    peerNickname: 'nadya',
    lastMessage: 'Sent.',
    timeAgo: 'yesterday',
  ),
];
