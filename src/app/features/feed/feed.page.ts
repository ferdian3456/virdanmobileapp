import {
  Component,
  CUSTOM_ELEMENTS_SCHEMA,
  AfterViewInit,
  ViewChild,
  ViewChildren,
  QueryList,
  ElementRef,
  signal,
  inject
} from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { Router } from '@angular/router';
import {
  IonContent,
  IonIcon,
  IonInfiniteScroll,
  IonInfiniteScrollContent
} from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import {
  heartOutline,
  heart,
  chatbubbleOutline,
  arrowBackOutline,
  ellipsisHorizontal,
  personOutline
} from 'ionicons/icons';
import { ApiService } from '../../core/services/api';
import { Post, PostsResponse } from '../../core/models/post.model';

@Component({
  selector: 'app-feed',
  templateUrl: './feed.page.html',
  styleUrls: ['./feed.page.scss'],
  standalone: true,
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  imports: [
    IonContent,
    IonIcon,
    CommonModule,
    IonInfiniteScroll,
    IonInfiniteScrollContent
  ]
})
export class FeedPage implements AfterViewInit {
  @ViewChild(IonContent) private content!: IonContent;
  @ViewChildren('postItem') private postItems!: QueryList<ElementRef>;

  posts = signal<Post[]>([]);
  hasMore = true;

  private tappedIndex = 0;
  private nextCursor = '';
  private serverIds: string[] = [];
  private currentServerIndex = 0;

  private location = inject(Location);
  public router = inject(Router);
  private api = inject(ApiService);

  constructor() {
    addIcons({ heartOutline, heart, chatbubbleOutline, arrowBackOutline, ellipsisHorizontal, personOutline });

    // State harus diambil di constructor karena getCurrentNavigation() hanya tersedia saat navigasi berlangsung
    const state = this.router.getCurrentNavigation()?.extras.state;
    if (state) {
      const initialPosts = (state['posts'] as Post[]).map(p => ({
        ...p,
        liked: (p as any).isLiked ?? (p as any).liked ?? false
      }));
      this.posts.set(initialPosts);
      this.tappedIndex = state['tappedIndex'] ?? 0;
      this.nextCursor = state['nextCursor'] ?? '';
      this.serverIds = state['serverIds'] ?? [];
      this.currentServerIndex = state['currentServerIndex'] ?? 0;
      this.hasMore = state['hasMore'] ?? false;
    }
  }

  ngAfterViewInit() {
    if (this.tappedIndex > 0) {
      setTimeout(() => {
        const items = this.postItems.toArray();
        if (items[this.tappedIndex]) {
          const el = items[this.tappedIndex].nativeElement as HTMLElement;
          const headerHeight = 80;
          const scrollY = Math.max(0, el.offsetTop - headerHeight);
          this.content.scrollToPoint(0, scrollY, 0);
        }
      }, 80);
    }
  }

  goBack() {
    this.location.back();
  }

  loadMore(event: any) {
    if (!this.hasMore) {
      event.target.complete();
      return;
    }
    this.loadNextServerPosts(this.nextCursor, event);
  }

  private loadNextServerPosts(cursor: string = '', event?: any) {
    if (this.currentServerIndex >= this.serverIds.length) {
      this.hasMore = false;
      event?.target.complete();
      return;
    }

    const serverId = this.serverIds[this.currentServerIndex];
    let url = `servers/${serverId}/posts?limit=12`;
    if (cursor) url += `&cursor=${cursor}`;

    this.api.get<PostsResponse>(url).subscribe({
      next: (res) => {
        const newPosts = res.data.map(p => ({
          ...p,
          liked: (p as any).isLiked ?? false
        }));
        this.posts.update(current => [...current, ...newPosts]);
        this.nextCursor = res.page.nextCursor;

        if (!res.page.nextCursor) {
          this.currentServerIndex++;
          this.nextCursor = '';
        }

        this.hasMore =
          this.currentServerIndex < this.serverIds.length || !!res.page.nextCursor;
        event?.target.complete();
      },
      error: () => {
        event?.target.complete();
      }
    });
  }

  toggleLike(post: Post) {
    const wasLiked = post.liked;
    const url = `posts/${post.postId}/likes`;
    const req = wasLiked ? this.api.delete(url) : this.api.post(url, {});

    req.subscribe({
      next: (res: any) => {
        post.liked = !wasLiked;
        post.likeCount = res.likeCount;
      },
      error: () => {}
    });
  }

  openComments(post: Post) {
    this.router.navigate(['/app/comments'], {
      queryParams: { postId: post.postId }
    });
  }
}