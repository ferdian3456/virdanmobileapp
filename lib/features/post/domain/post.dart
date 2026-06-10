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
    this.isSaved = false,
    this.authorAvatarUrl,
    this.imageUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.mediaType,
    this.mediaWidth,
    this.mediaHeight,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return Post(
      id: json['id'] as String? ?? json['postId'] as String,
      serverId: (json['serverId'] as String?) ?? '',
      authorId: (json['authorId'] as String?) ??
          (author?['userId'] as String?) ??
          '',
      authorNickname: (json['authorNickname'] as String?) ??
          (author?['nickname'] as String?) ??
          'Unknown',
      authorAvatarUrl: (json['authorAvatarUrl'] as String?) ??
          (author?['avatarUrl'] as String?),
      caption: (json['caption'] as String?) ?? '',
      imageUrl: json['imageUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      mediaType: json['mediaType'] as String?,
      mediaWidth: (json['mediaWidth'] as num?)?.toInt(),
      mediaHeight: (json['mediaHeight'] as num?)?.toInt(),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      isLiked: (json['userLiked'] as bool?) ??
          (json['isLiked'] as bool?) ??
          false,
      isSaved: (json['userSaved'] as bool?) ??
          (json['isSaved'] as bool?) ??
          false,
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
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? mediaType;
  final int? mediaWidth;
  final int? mediaHeight;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isSaved;
  final String createdAt;

  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image' || (imageUrl != null && mediaType == null);

  double? get mediaAspectRatio {
    if (mediaWidth != null && mediaHeight != null && mediaHeight! > 0) {
      return mediaWidth! / mediaHeight!;
    }
    return null;
  }

  Post copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    bool? isSaved,
  }) {
    return Post(
      id: id,
      serverId: serverId,
      authorId: authorId,
      authorNickname: authorNickname,
      authorAvatarUrl: authorAvatarUrl,
      caption: caption,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      mediaType: mediaType,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
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
    this.parentId,
    this.authorAvatarUrl,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return Comment(
      id: (json['id'] as String?) ?? (json['commentId'] as String),
      postId: (json['postId'] as String?) ?? '',
      authorId: (json['authorId'] as String?) ??
          (author?['userId'] as String?) ??
          '',
      authorNickname: (json['authorNickname'] as String?) ??
          (author?['nickname'] as String?) ??
          'Unknown',
      authorAvatarUrl: (json['authorAvatarUrl'] as String?) ??
          (author?['avatarUrl'] as String?),
      content: (json['content'] as String?) ?? '',
      parentId: json['parentId'] as String?,
      createdAt: (json['createdAt'] as String?) ?? '',
    );
  }

  final String id;
  final String postId;
  final String authorId;
  final String authorNickname;
  final String? authorAvatarUrl;
  final String content;
  final String? parentId;
  final String createdAt;
}
