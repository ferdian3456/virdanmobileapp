import { Component, CUSTOM_ELEMENTS_SCHEMA, OnInit, signal, inject } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { IonContent, IonIcon } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import {
  heartOutline,
  heart,
  chatbubbleOutline,
  paperPlaneOutline,
  bookmarkOutline,
  ellipsisHorizontal,
  arrowBackOutline,
  reloadOutline
} from 'ionicons/icons';
import { ApiService } from '../../core/services/api';
import { Post } from '../../core/models/post.model';

@Component({
  selector: 'app-post-detail',
  templateUrl: './post-detail.page.html',
  styleUrl: './post-detail.page.scss',
  standalone: true,
  host: { class: 'ion-page' },
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
  imports: [IonContent,CommonModule]
})
export class PostDetailPage implements OnInit {
  post = signal<Post | null>(null);
  loading = true;

  private route = inject(ActivatedRoute);
  private location = inject(Location);
  public router = inject(Router);
  private api = inject(ApiService);

  constructor() {
    addIcons({ heartOutline, heart, chatbubbleOutline, paperPlaneOutline, bookmarkOutline, ellipsisHorizontal, arrowBackOutline, reloadOutline });
  }

  ngOnInit() {
    const postId = this.route.snapshot.paramMap.get('postId');
    if (postId) {
      this.loadPost(postId);
    }
  }

  loadPost(postId: string) {
    this.loading = true;
    this.api.get<Post>(`posts/${postId}`).subscribe({
      next: (res) => {
        this.post.set({ ...res, liked: res.isLiked ?? false });
        this.loading = false;
      },
      error: () => {
        this.loading = false;
      }
    });
  }

  goBack() {
    this.location.back();
  }

  toggleLike() {
    const p = this.post();
    if (!p) return;

    const wasLiked = p.liked;
    const url = `posts/${p.postId}/likes`;
    const req = wasLiked ? this.api.delete(url) : this.api.post(url, {});

    req.subscribe({
      next: (res: any) => {
        this.post.set({ ...p, liked: !wasLiked, likeCount: res.likeCount });
      },
      error: () => {}
    });
  }

  openComments() {
    const p = this.post();
    if (!p) return;
    this.router.navigate(['/app/comments'], {
      queryParams: { postId: p.postId }
    });
  }
}
