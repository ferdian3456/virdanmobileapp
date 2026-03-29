import { Component, OnInit, signal, inject, DestroyRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  IonContent, IonIcon, IonInfiniteScroll, IonInfiniteScrollContent,
  IonSpinner, ToastController, ActionSheetController
} from '@ionic/angular/standalone';
import { ActivatedRoute, Router } from '@angular/router';
import { addIcons } from 'ionicons';
import { arrowBackOutline, trashOutline, sendOutline, arrowUndoOutline, closeOutline, paperPlaneOutline, paperPlane, heartOutline, heart } from 'ionicons/icons';
import { ApiService } from '../../core/services/api';
import { Comment, CommentsResponse, Post } from '../../core/models/post.model';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

interface Author {
  id: string;
  name: string;
  username: string;
  avatarImageUrl: string | null;
}

interface CommentWithAuthor {
  id: string;
  authorId: string;
  authorName: string;
  authorAvatar: string | null;
  parentId: string | null;
  content: string;
  createDatetime: string;
  updateDatetime: string;
  // Client-side additions
  timeAgo: string;
  replies?: CommentWithAuthor[];
  likeCount?: number;
  liked?: boolean;
}

@Component({
  selector: 'app-comments',
  templateUrl: './comments.page.html',
  styleUrls: ['./comments.page.scss'],
  standalone: true,
  host: { class: 'ion-page' },
  imports: [
    IonContent,
    IonIcon,
    IonInfiniteScroll,
    IonInfiniteScrollContent,
    IonSpinner,
    CommonModule,
    FormsModule
  ]
})
export class CommentsPage implements OnInit {
  private api = inject(ApiService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private toastCtrl = inject(ToastController);
  private actionSheetCtrl = inject(ActionSheetController);
  private destroyRef = inject(DestroyRef);

  // Avatar colors (matching reference: blue, green, orange)
  private avatarColors = [
    { bg: '#E7F1FF', text: '#007BFF' },  // Blue
    { bg: '#F0FFF4', text: '#28A745' },  // Green
    { bg: '#FFF3E0', text: '#F57C00' },  // Orange
    { bg: '#F3E5F5', text: '#9C27B0' },  // Purple
    { bg: '#FFEBEE', text: '#E53E3E' },  // Red
    { bg: '#E0F2F1', text: '#009688' },  // Teal
    { bg: '#FFF8E1', text: '#FFC107' },  // Yellow
  ];

  comments = signal<CommentWithAuthor[]>([]);
  loading = true;
  loadingMore = false;
  hasMore = true;
  nextCursor = '';
  postId = '';
  commentContent = '';
  submitting = false;
  deletingCommentId = signal<string>('');
  commentCount = signal<number>(0);
  replyingTo = signal<CommentWithAuthor | null>(null);
  post = signal<Post | null>(null);

  constructor() {
    addIcons({
      arrowBackOutline,
      trashOutline,
      sendOutline,
      arrowUndoOutline,
      closeOutline,
      paperPlaneOutline,
      paperPlane,
      heartOutline,
      heart
    });
  }

  // Get consistent avatar color based on username
  getAvatarColor(username: string): { bg: string; text: string } {
    if (!username) return this.avatarColors[0];

    // Simple hash function for username
    let hash = 0;
    for (let i = 0; i < username.length; i++) {
      hash = username.charCodeAt(i) + ((hash << 5) - hash);
    }

    const index = Math.abs(hash) % this.avatarColors.length;
    return this.avatarColors[index];
  }

  // Get avatar initial
  getAvatarInitial(username: string): string {
    return username?.[0]?.toUpperCase() || '?';
  }

  ngOnInit() {
    this.postId = this.route.snapshot.queryParamMap.get('postId') || '';
    if (!this.postId) {
      this.router.navigate(['/app/home']);
      return;
    }

    this.loadPostDetail();
    this.loadComments();
  }

  loadPostDetail() {
    this.api.get<Post>(`posts/${this.postId}`).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: (res) => {
        this.commentCount.set(res.commentCount || 0);
      },
      error: () => {
        // Silently fail, commentCount will remain 0
      }
    });
  }

  loadComments(cursor: string = '') {
    if (cursor) {
      this.loadingMore = true;
    } else {
      this.loading = true;
    }

    let url = `posts/${this.postId}/comments`;
    if (cursor) {
      url += `?cursor=${cursor}`;
    }

    this.api.get<CommentsResponse>(url).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: (res) => {
        const commentsWithAuthors: CommentWithAuthor[] = res.data.map(comment => ({
          ...comment,
          timeAgo: this.formatTimeAgo(comment.createDatetime)
        }));

        // Group comments: main comments with their replies
        const organizedComments = this.organizeComments(commentsWithAuthors);

        if (cursor) {
          this.comments.update(current => [...current, ...organizedComments]);
        } else {
          this.comments.set(organizedComments);
        }

        this.nextCursor = res.page.nextCursor;
        this.hasMore = !!res.page.nextCursor;
        this.loading = false;
        this.loadingMore = false;
      },
      error: async () => {
        this.loading = false;
        this.loadingMore = false;
        await this.showToast('Gagal memuat komentar');
      }
    });
  }

  // Organize flat comment list into nested structure
  private organizeComments(flatComments: CommentWithAuthor[]): CommentWithAuthor[] {
    const commentMap = new Map<string, CommentWithAuthor & { replies?: CommentWithAuthor[] }>();
    const rootComments: (CommentWithAuthor & { replies?: CommentWithAuthor[] })[] = [];

    // First pass: create map and add replies property
    flatComments.forEach(comment => {
      commentMap.set(comment.id, { ...comment, replies: [], likeCount: 0, liked: false });
    });

    // Second pass: build tree structure
    flatComments.forEach(comment => {
      const commentWithReplies = commentMap.get(comment.id)!;
      if (comment.parentId && commentMap.has(comment.parentId)) {
        // This is a reply, add to parent's replies
        const parent = commentMap.get(comment.parentId)!;
        if (parent.replies) {
          parent.replies.push(commentWithReplies);
        }
      } else {
        // This is a root comment
        rootComments.push(commentWithReplies);
      }
    });

    // Return root comments with their nested replies
    return rootComments;
  }

  loadMore(event: any) {
    if (!this.hasMore || this.loadingMore) {
      event.target.complete();
      return;
    }
    this.loadComments(this.nextCursor);
    setTimeout(() => event.target.complete(), 1000);
  }

  async submitComment() {
    const content = this.commentContent.trim();
    if (!content) {
      await this.showToast('Komentar tidak boleh kosong');
      return;
    }

    this.submitting = true;

    const payload: { content: string; parentId?: string } = { content };
    const replyingToComment = this.replyingTo();

    if (replyingToComment) {
      payload.parentId = replyingToComment.id;
    }

    this.api.post(`posts/${this.postId}/comments`, payload).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: async (res: any) => {
        // Add new comment to list optimistically
        const newComment: CommentWithAuthor = {
          ...res,
          timeAgo: 'Just now',
          replies: [],
          likeCount: 0,
          liked: false
        };

        // Insert comment in the correct position
        this.comments.update(current => {
          if (replyingToComment && replyingToComment.parentId) {
            // Replying to a reply - find parent comment and add to its replies
            return current.map(comment => {
              if (comment.id === replyingToComment!.parentId) {
                return {
                  ...comment,
                  replies: [...(comment.replies || []), newComment]
                };
              }
              return comment;
            });
          } else if (replyingToComment) {
            // Replying to a root comment - add to its replies
            return current.map(comment => {
              if (comment.id === replyingToComment!.id) {
                return {
                  ...comment,
                  replies: [...(comment.replies || []), newComment]
                };
              }
              return comment;
            });
          } else {
            // Root comment - add to top
            return [newComment, ...current];
          }
        });

        this.commentContent = '';
        this.submitting = false;
        this.commentCount.update(count => count + 1);
        this.replyingTo.set(null); // Clear reply mode
      },
      error: async () => {
        this.submitting = false;
        await this.showToast('Gagal mengirim komentar');
      }
    });
  }

  async deleteComment(commentId: string) {
    this.deletingCommentId.set(commentId);

    this.api.delete(`posts/${this.postId}/comments/${commentId}`).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: async () => {
        this.comments.update(current => {
          // Check if it's a root comment
          const rootIndex = current.findIndex(c => c.id === commentId);
          if (rootIndex !== -1) {
            // It's a root comment, remove from main list
            return current.filter(c => c.id !== commentId);
          }

          // It's a reply, find and remove from parent's replies
          return current.map(comment => ({
            ...comment,
            replies: comment.replies?.filter(r => r.id !== commentId) || []
          }));
        });

        this.deletingCommentId.set('');
        this.commentCount.update(count => Math.max(0, count - 1));
      },
      error: async () => {
        this.deletingCommentId.set('');
        await this.showToast('Gagal menghapus komentar');
      }
    });
  }

  replyToComment(comment: CommentWithAuthor) {
    this.replyingTo.set(comment);
    // Focus on input field after a short delay
    setTimeout(() => {
      const inputElement = document.querySelector('input[type="text"]') as HTMLInputElement;
      inputElement?.focus();
    }, 100);
  }

  cancelReply() {
    this.replyingTo.set(null);
  }

  getReplyingToUsername(): string {
    return this.replyingTo()?.authorName || '';
  }

  goBack() {
    this.router.navigate(['/app/home']);
  }

  private formatTimeAgo(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m`;
    if (diffHours < 24) return `${diffHours}h`;
    if (diffDays < 7) return `${diffDays}d`;
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  private async showToast(message: string) {
    const toast = await this.toastCtrl.create({
      message,
      duration: 3000,
      position: 'top',
      color: 'danger'
    });
    await toast.present();
  }

  canSubmit(): boolean {
    return this.commentContent.trim().length > 0 && !this.submitting;
  }

  async onLongPressComment(comment: CommentWithAuthor) {
    // TODO: Add ownership check later
    const actionSheet = await this.actionSheetCtrl.create({
      header: 'Comment Options',
      buttons: [
        {
          text: 'Delete',
          role: 'destructive',
          icon: 'trash-outline',
          handler: () => {
            this.deleteComment(comment.id);
          }
        },
        {
          text: 'Cancel',
          role: 'cancel'
        }
      ]
    });

    await actionSheet.present();
  }

  // Track long press timeout
  private longPressTimeout: any;
  private isLongPress = false;

  onTouchStartComment(comment: CommentWithAuthor, event: Event) {
    // Long press enabled for all comments (ownership check on server)
    this.isLongPress = false;

    this.isLongPress = false;
    this.longPressTimeout = setTimeout(() => {
      this.isLongPress = true;
      this.onLongPressComment(comment);
    }, 500); // 500ms = long press
  }

  onTouchEndComment(event: Event) {
    if (this.longPressTimeout) {
      clearTimeout(this.longPressTimeout);
    }

    // If it was a long press, prevent click
    if (this.isLongPress) {
      event.preventDefault();
      event.stopPropagation();
    }
    this.isLongPress = false;
  }

  onTouchMoveComment() {
    // Cancel long press if finger moves
    if (this.longPressTimeout) {
      clearTimeout(this.longPressTimeout);
    }
  }
}
