import 'package:flutter/foundation.dart';

@immutable
class Post {
  const Post({
    required this.id,
    required this.serverId,
    required this.authorId,
    required this.authorNickname,
    required this.caption,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.createdAt,
    this.authorAvatarUrl,
    this.imageUrl,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String? ?? json['postId'] as String,
      serverId: (json['serverId'] as String?) ?? '',
      authorId: (json['authorId'] as String?) ?? '',
      authorNickname: (json['authorNickname'] as String?) ??
          (json['author']?['nickname'] as String?) ??
          'Unknown',
      authorAvatarUrl: (json['authorAvatarUrl'] as String?) ??
          (json['author']?['avatarUrl'] as String?),
      caption: (json['caption'] as String?) ?? '',
      imageUrl: json['imageUrl'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      isLiked: (json['isLiked'] as bool?) ?? false,
      createdAt: (json['createdAt'] as String?) ?? '',
    );
  }

  final String id;
  final String serverId;
  final String authorId;
  final String authorNickname;
  final String? authorAvatarUrl;
  final String caption;
  final String? imageUrl;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final String createdAt;

  Post copyWith({int? likeCount, int? commentCount, bool? isLiked}) {
    return Post(
      id: id,
      serverId: serverId,
      authorId: authorId,
      authorNickname: authorNickname,
      authorAvatarUrl: authorAvatarUrl,
      caption: caption,
      imageUrl: imageUrl,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt,
    );
  }
}

@immutable
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorNickname,
    required this.content,
    required this.createdAt,
    this.authorAvatarUrl,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: (json['id'] as String?) ?? (json['commentId'] as String),
      postId: (json['postId'] as String?) ?? '',
      authorId: (json['authorId'] as String?) ?? '',
      authorNickname: (json['authorNickname'] as String?) ??
          (json['author']?['nickname'] as String?) ??
          'Unknown',
      authorAvatarUrl: (json['authorAvatarUrl'] as String?) ??
          (json['author']?['avatarUrl'] as String?),
      content: (json['content'] as String?) ?? '',
      createdAt: (json['createdAt'] as String?) ?? '',
    );
  }

  final String id;
  final String postId;
  final String authorId;
  final String authorNickname;
  final String? authorAvatarUrl;
  final String content;
  final String createdAt;
}
