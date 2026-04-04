import { Component, CUSTOM_ELEMENTS_SCHEMA, OnInit, signal, computed, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { IonContent, IonIcon, IonInfiniteScroll, IonInfiniteScrollContent } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { heartOutline, peopleOutline, heart, chatbubbleOutline, paperPlaneOutline, bookmarkOutline, ellipsisHorizontal, reloadOutline, imagesOutline, chevronDownOutline, checkmarkOutline, addOutline, searchOutline } from 'ionicons/icons';
import { ApiService } from '../../core/services/api';
import { StateService } from '../../core/services/state.service';
import { Post, PostsResponse } from '../../core/models/post.model';

interface Server {
  id: string;
  name: string;
  shortName: string;
  avatarImageUrl: string;
}

interface ServerListResponse {
  data: Server[];
  page: { nextCursor: string };
}

@Component({
  selector: 'app-homepage',
  templateUrl: './homepage.page.html',
  styleUrls: ['./homepage.page.scss'],
  standalone: true,
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  imports: [IonContent, IonIcon, CommonModule, IonInfiniteScroll, IonInfiniteScrollContent]
})
export class HomepagePage implements OnInit {
  servers = signal<Server[]>([]);
  activeServerId = signal<string>('');
  posts = signal<Post[]>([]);
  nextCursor = '';
  hasMore = true;
  loadingServers = true;
  loadingPosts = false;
  showServerDropdown = false;


  hasServers = computed(() => this.servers().length > 0);

  public router = inject(Router);
  private api = inject(ApiService);
  private stateService = inject(StateService);

  constructor() {
    addIcons({reloadOutline,chevronDownOutline,paperPlaneOutline,checkmarkOutline,addOutline,searchOutline,ellipsisHorizontal,chatbubbleOutline,bookmarkOutline,heartOutline,imagesOutline,peopleOutline,heart});
  }

  activeServerName = computed(() => 
    this.servers().find(s => s.id === this.activeServerId())?.name ?? ''
  );

  selectServer(serverId: string) {
    this.switchServer(serverId);
    this.showServerDropdown = false;
  }

  ngOnInit() {
    this.loadServers();
  }

  loadServers() {
    this.loadingServers = true;
    this.api.get<ServerListResponse>('servers/me').subscribe({
      next: (res) => {
        this.servers.set(res.data);
        if (res.data.length > 0) {
          this.activeServerId.set(res.data[0].id);
          this.stateService.setActiveServer(res.data[0].id);
          this.loadPosts();
        }
        this.loadingServers = false;
      },
      error: () => {
        this.loadingServers = false;
      }
    });
  }

  switchServer(serverId: string) {
    if (this.activeServerId() === serverId) return;
    this.activeServerId.set(serverId);
    this.stateService.updateActiveServer(serverId);
    this.posts.set([]);
    this.nextCursor = '';
    this.hasMore = true;
    this.loadPosts();
  }

  loadPosts(cursor: string = '') {
    if (this.loadingPosts) return;
    this.loadingPosts = true;

    let url = `servers/${this.activeServerId()}/posts`;
    if (cursor) url += `?cursor=${cursor}`;

    // url += `?limit=2`;

    this.api.get<PostsResponse>(url).subscribe({
      next: (res) => {
        const newPosts = res.data.map(p => ({ ...p, liked: p.isLiked ?? false }));
        this.posts.update(current => [...current, ...newPosts]);
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

    let url = `servers/${this.activeServerId()}/posts?cursor=${this.nextCursor}`;
    // url += `&limit=2`;
    this.api.get<PostsResponse>(url).subscribe({
      next: (res) => {
        const newPosts = res.data.map(p => ({ ...p, liked: p.isLiked ?? false }));
        this.posts.update(current => [...current, ...newPosts]);
        this.nextCursor = res.page.nextCursor;
        this.hasMore = !!res.page.nextCursor;
        event.target.complete();
      },
      error: () => {
        event.target.complete();
      }
    });
  }

  toggleLike(post: Post) {
    const wasLiked = post.liked;

    const url = `posts/${post.postId}/likes`;
    const req = wasLiked ? this.api.delete(url) : this.api.post(url, {});

    req.subscribe({
      next: (res: any) => {
        // Update UI setelah API sukses
        post.liked = !wasLiked;
        post.likeCount = res.likeCount;
      },
      error: () => {
        // Tampilkan error (opsional: bisa tambah toast)
        console.error('Failed to toggle like');
      }
    });
  }

  openComments(post: Post) {
    this.router.navigate(['/app/comments'], {
      queryParams: { postId: post.postId }
    });
  }
}