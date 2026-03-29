import { Component, CUSTOM_ELEMENTS_SCHEMA, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { IonContent, IonIcon } from '@ionic/angular/standalone';
import { heart, chatbubble, at } from 'ionicons/icons';
import { addIcons } from 'ionicons';
import { ApiService } from '../../core/services/api';

export interface Notification {
  id: string;
  type: 'like' | 'comment' | 'mention';
  actorName: string;
  actorImageUrl?: string;
  postImageUrl?: string;
  message: string;
  timeAgo: string;
  read: boolean;
}

interface ServerListResponse {
  data: { id: string }[];
  page: { nextCursor: string };
}

@Component({
  selector: 'app-notification',
  templateUrl: './notification.page.html',
  styleUrls: ['./notification.page.scss'],
  standalone: true,
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  imports: [IonContent, IonIcon, CommonModule]
})
export class NotificationPage implements OnInit {
  activeTab = signal<'all' | 'mentions'>('all');
  hasServers = signal(false);

  // newNotifications: Notification[] = [
  //   {
  //     id: '1',
  //     type: 'like',
  //     actorName: 'sarah_design',
  //     timeAgo: '2m',
  //     message: 'liked your post.',
  //     read: false,
  //     postImageUrl: ''
  //   }
  // ];

  // todayNotifications: Notification[] = [
  //   {
  //     id: '2',
  //     type: 'comment',
  //     actorName: 'mike_studio',
  //     timeAgo: '2h',
  //     message: 'commented: "Love this!"',
  //     read: false,
  //     postImageUrl: ''
  //   },
  //   {
  //     id: '3',
  //     type: 'like',
  //     actorName: 'amy_art',
  //     timeAgo: '5h',
  //     message: 'and 42 others liked your post.',
  //     read: false,
  //     postImageUrl: ''
  //   }
  // ];

  // earlierNotifications: Notification[] = [
  //   {
  //     id: '4',
  //     type: 'mention',
  //     actorName: 'creative_agency',
  //     timeAgo: '1d',
  //     message: 'mentioned you in a comment.',
  //     read: true,
  //     postImageUrl: ''
  //   }
  // ];

  newNotifications: Notification[] = [];
  todayNotifications: Notification[] = [];
  earlierNotifications: Notification[] = [];

  constructor(public router: Router, private api: ApiService) {
    addIcons({ heart, chatbubble, at });
  }

  ngOnInit() {
    this.api.get<ServerListResponse>('servers/me').subscribe({
      next: (res) => {
        this.hasServers.set(res.data.length > 0);
      },
      error: () => {
        this.hasServers.set(false);
      }
    });
  }

  get filteredNew() {
    return this.activeTab() === 'mentions'
      ? this.newNotifications.filter(n => n.type === 'mention')
      : this.newNotifications;
  }

  get filteredToday() {
    return this.activeTab() === 'mentions'
      ? this.todayNotifications.filter(n => n.type === 'mention')
      : this.todayNotifications;
  }

  get filteredEarlier() {
    return this.activeTab() === 'mentions'
      ? this.earlierNotifications.filter(n => n.type === 'mention')
      : this.earlierNotifications;
  }

  getTypeIcon(type: string): string {
    switch (type) {
      case 'like': return 'heart';
      case 'comment': return 'chatbubble';
      case 'mention': return 'at';
      default: return '';
    }
  }

  getTypeColor(type: string): string {
    switch (type) {
      case 'like': return 'bg-red-500 text-white';
      case 'comment': return 'bg-[#007BFF] text-white';
      case 'mention': return 'bg-green-500 text-white';
      default: return 'bg-gray-400';
    }
  }
}