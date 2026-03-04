export interface Post {
  ownerId: string;
  ownerName: string;
  ownerImageUrl: string | null;
  postId: string;
  postImageUrl: string;
  caption: string;
  commentCount: number;
  likeCount: number;
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