export type NotificationKind = 'follow' | 'like' | 'comment' | 'mention';
export type NotificationGroup = 'new' | 'today' | 'earlier';

export interface NotificationItem {
  id: string;
  kind: NotificationKind;
  group: NotificationGroup;
  actor: {
    username: string;
    avatarUrl: string | null;
  };
  text: string;
  timeLabel: string;
  thumbnailUrl?: string | null;
  isFollowing?: boolean;
  showFollowAction?: boolean;
}

export const NOTIFICATIONS: NotificationItem[] = [
  {
    id: 'n-1',
    kind: 'follow',
    group: 'new',
    actor: { username: 'john_doe', avatarUrl: null },
    text: 'started following you.',
    timeLabel: '2m',
    showFollowAction: true,
    isFollowing: false,
  },
  {
    id: 'n-2',
    kind: 'like',
    group: 'new',
    actor: { username: 'sarah_design', avatarUrl: null },
    text: 'liked your post.',
    timeLabel: '5m',
    thumbnailUrl: 'https://picsum.photos/seed/notif1/80/80',
  },
  {
    id: 'n-3',
    kind: 'comment',
    group: 'today',
    actor: { username: 'mike_studio', avatarUrl: null },
    text: 'commented: "Love this color palette!"',
    timeLabel: '2h',
    thumbnailUrl: 'https://picsum.photos/seed/notif2/80/80',
  },
  {
    id: 'n-4',
    kind: 'like',
    group: 'today',
    actor: { username: 'amy_art', avatarUrl: null },
    text: 'and 42 others liked your post.',
    timeLabel: '5h',
    thumbnailUrl: 'https://picsum.photos/seed/notif3/80/80',
  },
  {
    id: 'n-5',
    kind: 'mention',
    group: 'earlier',
    actor: { username: 'creative_agency', avatarUrl: null },
    text: 'mentioned you in a comment.',
    timeLabel: '1d',
    thumbnailUrl: 'https://picsum.photos/seed/notif4/80/80',
  },
  {
    id: 'n-6',
    kind: 'follow',
    group: 'earlier',
    actor: { username: 'lisa_travels', avatarUrl: null },
    text: 'started following you.',
    timeLabel: '2d',
    showFollowAction: true,
    isFollowing: true,
  },
];
