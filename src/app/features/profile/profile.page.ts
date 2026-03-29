import { Component, CUSTOM_ELEMENTS_SCHEMA, OnInit, signal, computed, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { IonContent, IonIcon, IonInfiniteScroll, IonInfiniteScrollContent } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { gridOutline, videocamOutline, bookmarkOutline, menuOutline, chevronDownOutline, reloadOutline, imagesOutline } from 'ionicons/icons';
import { ApiService } from '../../core/services/api';
import { StateService } from '../../core/services/state.service';

interface UserProfile {
  id: string;
  username: string;
  fullname: string;
  email: string;
  avatarImage: string | null;
  bio: string | null;
  createDatetime: string;
  updateDatetime: string;
}

interface ProfilePost {
  postId: string;
  postImageUrl: string;
  createDatetime: string;
}

interface ProfilePostsResponse {
  data: ProfilePost[];
  page: { nextCursor: string };
}

@Component({
  selector: 'app-profile',
  templateUrl: './profile.page.html',
  styleUrl: './profile.page.scss',
  standalone: true,
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  imports: [IonContent, IonIcon, CommonModule, IonInfiniteScroll, IonInfiniteScrollContent]
})
export class ProfilePage implements OnInit {
  user = signal<UserProfile | null>(null);
  posts = signal<ProfilePost[]>([]);
  nextCursor = '';
  hasMore = true;
  loadingProfile = true;
  loadingPosts = false;

  postCount = computed(() => this.posts().length);

  public router = inject(Router);
  private api = inject(ApiService);
  private stateService = inject(StateService);

  constructor() {
    addIcons({ gridOutline, videocamOutline, bookmarkOutline, menuOutline, chevronDownOutline, reloadOutline, imagesOutline });
  }

  ngOnInit() {
    this.loadProfile();
  }

  loadProfile() {
    this.loadingProfile = true;
    this.api.get<UserProfile>('users/me').subscribe({
      next: (res) => {
        this.user.set(res);
        this.loadingProfile = false;
        this.loadPosts();
      },
      error: () => {
        this.loadingProfile = false;
      }
    });
  }

  loadPosts(cursor: string = '') {
    const serverId = this.stateService.activeServerId();
    if (!serverId) return;

    if (this.loadingPosts) return;
    this.loadingPosts = true;

    let url = `servers/${serverId}/posts/me`;
    if (cursor) url += `?cursor=${cursor}`;

    this.api.get<ProfilePostsResponse>(url).subscribe({
      next: (res) => {
        this.posts.update(current => [...current, ...res.data]);
        this.nextCursor = res.page.nextCursor;
        this.hasMore = !!res.page.nextCursor;
        this.loadingPosts = false;
      },
      error: () => {
        this.loadingPosts = false;
      }
    });
  }

  loadMore(event: any) {
    if (!this.hasMore) {
      event.target.complete();
      return;
    }

    const serverId = this.stateService.activeServerId();
    if (!serverId) {
      event.target.complete();
      return;
    }

    this.api.get<ProfilePostsResponse>(`servers/${serverId}/posts/me?cursor=${this.nextCursor}`).subscribe({
      next: (res) => {
        this.posts.update(current => [...current, ...res.data]);
        this.nextCursor = res.page.nextCursor;
        this.hasMore = !!res.page.nextCursor;
        event.target.complete();
      },
      error: () => {
        event.target.complete();
      }
    });
  }

  getUserInitial(): string {
    const u = this.user();
    if (!u) return '';
    return u.fullname?.[0]?.toUpperCase() ?? u.username?.[0]?.toUpperCase() ?? '';
  }
}
