import { Component, CUSTOM_ELEMENTS_SCHEMA, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { IonContent, IonIcon, IonInfiniteScroll, IonInfiniteScrollContent } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { searchOutline, closeCircle, arrowBackOutline } from 'ionicons/icons';
import { ApiService } from '../../core/services/api';
import { Post, PostsResponse } from '../../core/models/post.model';
import { FormsModule } from '@angular/forms';

interface ServerListResponse {
  data: { id: string }[];
  page: { nextCursor: string };
}

@Component({
  selector: 'app-explore',
  templateUrl: './explore.page.html',
  styleUrls: ['./explore.page.scss'],
  standalone: true,
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  imports: [IonContent, IonIcon, CommonModule, FormsModule, IonInfiniteScroll, IonInfiniteScrollContent]
})
export class ExplorePage implements OnInit {
  posts = signal<Post[]>([]);
  serverIds: string[] = [];
  currentServerIndex = 0;
  nextCursor = '';
  hasMore = true;
  loading = true;
  hasServers = signal(true);
  isSearching = signal(false);
  searchQuery = signal('');
  searchResults = signal<Post[]>([]);

  constructor(public router: Router, private api: ApiService) {
    addIcons({ arrowBackOutline, searchOutline, closeCircle });
  }

  ngOnInit() {
    this.loadServers();
  }

  onSearchFocus() {
    this.isSearching.set(true);
  }

  onSearchBlur() {
    if (!this.searchQuery()) {
      this.isSearching.set(false);
    }
  }

  onSearchClear() {
    this.searchQuery.set('');
    this.searchResults.set([]);
    this.isSearching.set(false);
  }

  onSearchInput(value: string) {
    this.searchQuery.set(value);
    if (value.trim()) {
      const filtered = this.posts().filter(p =>
        p.ownerName.toLowerCase().includes(value.toLowerCase()) ||
        p.caption.toLowerCase().includes(value.toLowerCase())
      );
      this.searchResults.set(filtered);
    } else {
      this.searchResults.set([]);
    }
  }

  loadServers() {
    this.api.get<ServerListResponse>('servers/me').subscribe({
      next: (res) => {
        this.serverIds = res.data.map(s => s.id);
        if (this.serverIds.length === 0) {
          this.hasServers.set(false);
          this.loading = false;
          return;
        }
        this.loadNextServerPosts();
      },
      error: () => { this.loading = false; }
    });
  }

  loadNextServerPosts(cursor: string = '') {
    if (this.currentServerIndex >= this.serverIds.length) {
      this.hasMore = false;
      this.loading = false;
      return;
    }

    const serverId = this.serverIds[this.currentServerIndex];
    let url = `servers/${serverId}/posts?limit=12`;
    if (cursor) url += `&cursor=${cursor}`;

    this.api.get<PostsResponse>(url).subscribe({
      next: (res) => {
        // Map isLiked ke liked agar konsisten dengan feed page
        const newPosts = res.data.map(p => ({ ...p, liked: (p as any).isLiked ?? false }));
        this.posts.update(current => [...current, ...newPosts]);
        this.nextCursor = res.page.nextCursor;

        if (!res.page.nextCursor) {
          this.currentServerIndex++;
          this.nextCursor = '';
        }

        this.hasMore = this.currentServerIndex < this.serverIds.length || !!res.page.nextCursor;
        this.loading = false;
      },
      error: () => { this.loading = false; }
    });
  }

  loadMore(event: any) {
    if (!this.hasMore) {
      event.target.complete();
      return;
    }
    this.loadNextServerPosts(this.nextCursor);
    setTimeout(() => event.target.complete(), 1000);
  }

  // Navigasi ke feed dengan context penuh - pass semua posts + index yang di-tap
  navigateToFeed(post: Post, index: number) {
    this.router.navigate(['/app/feed'], {
      state: {
        posts: this.posts(),
        tappedIndex: index,
        nextCursor: this.nextCursor,
        serverIds: this.serverIds,
        currentServerIndex: this.currentServerIndex,
        hasMore: this.hasMore
      }
    });
  }

  // Untuk search results: cari index asli di posts array agar feed context tetap lengkap
  navigateToFeedFromSearch(post: Post) {
    const index = this.posts().findIndex(p => p.postId === post.postId);
    this.navigateToFeed(post, index !== -1 ? index : 0);
  }
}