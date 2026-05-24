import 'package:flutter/foundation.dart';

@immutable
class MockNotification {
  const MockNotification({
    required this.id,
    required this.actorNickname,
    required this.action,
    required this.target,
    required this.timeAgo,
    this.imageUrl,
  });

  final String id;
  final String actorNickname;
  final String action;
  final String target;
  final String timeAgo;
  final String? imageUrl;
}

const mockNotifications = <MockNotification>[
  MockNotification(
    id: 'n1',
    actorNickname: 'kira',
    action: 'liked your post',
    target: 'in Photographers',
    timeAgo: '2m',
  ),
  MockNotification(
    id: 'n2',
    actorNickname: 'arjuna',
    action: 'commented:',
    target: '"That golden hour shot is unreal."',
    timeAgo: '14m',
  ),
  MockNotification(
    id: 'n3',
    actorNickname: 'nadya',
    action: 'started following you',
    target: '',
    timeAgo: '1h',
  ),
  MockNotification(
    id: 'n4',
    actorNickname: 'reza',
    action: 'mentioned you in',
    target: 'Devs ID',
    timeAgo: '3h',
  ),
  MockNotification(
    id: 'n5',
    actorNickname: 'putri',
    action: 'invited you to join',
    target: 'Indie Gamers',
    timeAgo: 'yesterday',
  ),
];
