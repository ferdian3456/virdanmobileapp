export interface Post {
  ownerId: string;
  ownerName: string;
  ownerImageUrl: string | null;
  postId: string;
  postImageUrl: string;
  caption: string;
  commentCount: number;
  likeCount: number;
  isLiked?: boolean;
  createDatetime: string;
  updateDatetime: string;
  liked?: boolean;
}

export interface PostsResponse {
  data: Post[];
  page: {
    nextCursor: string;
  };
}

export interface Comment {
  id: string;
  authorId: string;
  authorName: string;
  authorAvatar: string | null;
  content: string;
  createDatetime: string;
  updateDatetime: string;
  parentId: string | null;
}

export interface CommentsResponse {
  data: Comment[];
  page: {
    nextCursor: string;
    limit: number;
  };
}

export interface CreateCommentRequest {
  content: string;
}