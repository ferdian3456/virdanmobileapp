import 'package:flutter/foundation.dart';

enum NotificationKind { follow, like, comment, reply, mention }

enum NotificationGroup { newer, today, earlier }

@immutable
class NotificationActor {
  const NotificationActor({required this.username, this.avatarUrl});

  final String username;
  final String? avatarUrl;
}

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.kind,
    required this.group,
    required this.actor,
    required this.text,
    required this.timeLabel,
    this.serverId,
    this.postId,
    this.thumbnailUrl,
    this.isRead = false,
    this.isFollowing = false,
    this.showFollowAction = false,
  });

  final String id;
  final NotificationKind kind;
  final NotificationGroup group;
  final NotificationActor actor;
  final String text;
  final String timeLabel;
  final String? serverId;
  final String? postId; // deep-link target on tap
  final String? thumbnailUrl;
  bool isRead; // mutable: set true after mark-read so we don't re-call the API
  bool isFollowing;
  final bool showFollowAction;
}

final mockNotifications = <NotificationItem>[
  NotificationItem(
    id: 'n-1',
    kind: NotificationKind.follow,
    group: NotificationGroup.newer,
    actor: const NotificationActor(username: 'john_doe'),
    text: 'started following you.',
    timeLabel: '2m',
    showFollowAction: true,
    isFollowing: false,
  ),
  NotificationItem(
    id: 'n-2',
    kind: NotificationKind.like,
    group: NotificationGroup.newer,
    actor: const NotificationActor(username: 'sarah_design'),
    text: 'liked your post.',
    timeLabel: '5m',
    thumbnailUrl: 'https://picsum.photos/seed/notif1/80/80',
  ),
  NotificationItem(
    id: 'n-3',
    kind: NotificationKind.comment,
    group: NotificationGroup.today,
    actor: const NotificationActor(username: 'mike_studio'),
    text: 'commented: "Love this color palette!"',
    timeLabel: '2h',
    thumbnailUrl: 'https://picsum.photos/seed/notif2/80/80',
  ),
  NotificationItem(
    id: 'n-4',
    kind: NotificationKind.like,
    group: NotificationGroup.today,
    actor: const NotificationActor(username: 'amy_art'),
    text: 'and 42 others liked your post.',
    timeLabel: '5h',
    thumbnailUrl: 'https://picsum.photos/seed/notif3/80/80',
  ),
  NotificationItem(
    id: 'n-5',
    kind: NotificationKind.mention,
    group: NotificationGroup.earlier,
    actor: const NotificationActor(username: 'creative_agency'),
    text: 'mentioned you in a comment.',
    timeLabel: '1d',
    thumbnailUrl: 'https://picsum.photos/seed/notif4/80/80',
  ),
  NotificationItem(
    id: 'n-6',
    kind: NotificationKind.follow,
    group: NotificationGroup.earlier,
    actor: const NotificationActor(username: 'lisa_travels'),
    text: 'started following you.',
    timeLabel: '2d',
    showFollowAction: true,
    isFollowing: true,
  ),
];
