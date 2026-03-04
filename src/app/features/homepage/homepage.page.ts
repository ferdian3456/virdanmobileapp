import { Component, CUSTOM_ELEMENTS_SCHEMA, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IonContent, IonIcon, IonInfiniteScroll, IonInfiniteScrollContent } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { heartOutline, heart, chatbubbleOutline, paperPlaneOutline, bookmarkOutline, ellipsisHorizontal } from 'ionicons/icons';
import { ApiService } from '../../core/services/api';
import { Post, PostsResponse } from '../../core/models/post.model';
import { Router } from '@angular/router';

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
  posts: Post[] = [];
  nextCursor: string = '';
  loading = false;
  hasMore = true;
  serverId = '6d48867a-ffa5-4fac-87fe-498796149392';

  constructor(public router: Router, private api: ApiService) {
    addIcons({ heartOutline, heart, chatbubbleOutline, paperPlaneOutline, bookmarkOutline, ellipsisHorizontal });
  }

  ngOnInit() {
    this.loadPosts();
  }

  loadPosts(cursor: string = '') {
    this.loading = true;
    let url = `servers/${this.serverId}/posts`;
    if (cursor) url += `?cursor=${cursor}`;

    this.api.get<PostsResponse>(url).subscribe({
      next: (res) => {
        const newPosts = res.data.map(p => ({
          ...p,
          liked: false
        }));
        this.posts = [...this.posts, ...newPosts];
        this.nextCursor = res.page.nextCursor;
        this.hasMore = !!res.page.nextCursor;
        this.loading = false;
      },
      error: () => {
        this.loading = false;
      }
    });
  }

  loadMore(event: any) {
    if (!this.hasMore) {
      event.target.complete();
      return;
    }
    this.loadPosts(this.nextCursor);
    event.target.complete();
  }

  toggleLike(post: any) {
    post.liked = !post.liked;
    post.likeCount += post.liked ? 1 : -1;
  }
}