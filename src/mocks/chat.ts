export type ChatFilter = 'all' | 'unread' | 'requests';

export interface ChatThread {
  id: string;
  username: string;
  fullname?: string;
  avatarUrl: string | null;
  lastMessage: string;
  timeLabel: string;
  unread: boolean;
  typing?: boolean;
  isRequest?: boolean;
}

export const CHAT_THREADS: ChatThread[] = [
  {
    id: 'th-1',
    username: 'jane_doe',
    fullname: 'Jane Doe',
    avatarUrl: null,
    lastMessage: 'Sounds good — let me check.',
    timeLabel: '2m',
    unread: true,
    typing: true,
  },
  {
    id: 'th-2',
    username: 'mike_studio',
    fullname: 'Mike Studio',
    avatarUrl: null,
    lastMessage: 'Sent the brief over, take a look 👀',
    timeLabel: '1h',
    unread: true,
  },
  {
    id: 'th-3',
    username: 'amy_art',
    fullname: 'Amy Art',
    avatarUrl: null,
    lastMessage: 'Yes! Can do tomorrow morning.',
    timeLabel: '4h',
    unread: false,
  },
  {
    id: 'th-4',
    username: 'creative_agency',
    fullname: 'Creative Agency',
    avatarUrl: null,
    lastMessage: 'We loved the latest piece.',
    timeLabel: 'Yesterday',
    unread: false,
  },
  {
    id: 'th-5',
    username: 'lisa_travels',
    fullname: 'Lisa Travels',
    avatarUrl: null,
    lastMessage: 'Hi! I saw your post and…',
    timeLabel: '2d',
    unread: false,
    isRequest: true,
  },
];
