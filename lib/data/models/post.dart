class PostUser {
  const PostUser({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
  });
  final String id;
  final String name;
  final String email;
  final String? avatar;
  factory PostUser.fromJson(Map<String, dynamic> json) => PostUser(
    id: json['id'].toString(),
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    avatar: json['avatar'] as String?,
  );
}

class PostItem {
  const PostItem({
    required this.id,
    required this.authorId,
    required this.scope,
    required this.content,
    required this.status,
    required this.pinned,
    required this.allowComments,
    required this.likeCount,
    required this.commentCount,
    required this.liked,
    required this.canEdit,
    required this.canDelete,
    required this.canPin,
    required this.createdAt,
    this.classroomId,
    this.author,
    this.attachments = const [],
  });
  final int id;
  final String authorId;
  final String scope;
  final int? classroomId;
  final String content;
  final String status;
  final bool pinned;
  final bool allowComments;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final bool canEdit;
  final bool canDelete;
  final bool canPin;
  final DateTime createdAt;
  final PostUser? author;
  final List<PostAttachment> attachments;

  /// Bản sao đã like/bỏ like, dùng để cập nhật giao diện ngay khi bấm.
  PostItem withLike(bool value) => PostItem(
    id: id,
    authorId: authorId,
    scope: scope,
    content: content,
    status: status,
    pinned: pinned,
    allowComments: allowComments,
    likeCount: (likeCount + (value ? 1 : -1)).clamp(0, 1 << 31),
    commentCount: commentCount,
    liked: value,
    canEdit: canEdit,
    canDelete: canDelete,
    canPin: canPin,
    createdAt: createdAt,
    classroomId: classroomId,
    author: author,
    attachments: attachments,
  );

  factory PostItem.fromJson(Map<String, dynamic> json) => PostItem(
    id: (json['id'] as num).toInt(),
    authorId: json['authorId'].toString(),
    scope: json['scope'] as String? ?? '',
    classroomId: (json['classroomId'] as num?)?.toInt(),
    content: json['content'] as String? ?? '',
    status: json['status'] as String? ?? '',
    pinned: json['pinned'] as bool? ?? false,
    allowComments: json['allowComments'] as bool? ?? true,
    likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
    commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    liked: json['liked'] as bool? ?? false,
    canEdit: json['canEdit'] as bool? ?? false,
    canDelete: json['canDelete'] as bool? ?? false,
    canPin: json['canPin'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    author: json['author'] is Map<String, dynamic>
        ? PostUser.fromJson(json['author'] as Map<String, dynamic>)
        : null,
    attachments: (json['attachments'] as List<dynamic>? ?? const [])
        .map((e) => PostAttachment.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PostAttachment {
  const PostAttachment({
    required this.id,
    required this.url,
    required this.mediaType,
    required this.originalName,
    required this.contentType,
    required this.size,
    required this.processingStatus,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.durationSeconds,
  });
  final int id, size;
  final String url, mediaType, originalName, contentType;
  final String processingStatus;
  final String? thumbnailUrl;
  final int? width, height;
  final double? durationSeconds;
  factory PostAttachment.fromJson(Map<String, dynamic> json) => PostAttachment(
    id: (json['id'] as num).toInt(),
    url: json['url'] as String,
    mediaType: json['mediaType'] as String,
    originalName: json['originalName'] as String,
    contentType: json['contentType'] as String,
    size: (json['size'] as num).toInt(),
    processingStatus: json['processingStatus'] as String? ?? 'READY',
    thumbnailUrl: json['thumbnailUrl'] as String?,
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
  );
}

class PostUploadLimits {
  const PostUploadLimits({
    required this.imageMaxBytes,
    required this.fileMaxBytes,
    required this.videoMaxBytes,
    required this.postMaxBytes,
    required this.maxAttachments,
    required this.imageTypes,
    required this.fileTypes,
    required this.videoTypes,
  });
  final int imageMaxBytes,
      fileMaxBytes,
      videoMaxBytes,
      postMaxBytes,
      maxAttachments;
  final List<String> imageTypes, fileTypes, videoTypes;
  factory PostUploadLimits.fromJson(Map<String, dynamic> j) => PostUploadLimits(
    imageMaxBytes: (j['imageMaxBytes'] as num).toInt(),
    fileMaxBytes: (j['fileMaxBytes'] as num).toInt(),
    videoMaxBytes: (j['videoMaxBytes'] as num).toInt(),
    postMaxBytes: (j['postMaxBytes'] as num).toInt(),
    maxAttachments: (j['maxAttachments'] as num).toInt(),
    imageTypes: List<String>.from(j['imageTypes'] as List),
    fileTypes: List<String>.from(j['fileTypes'] as List),
    videoTypes: List<String>.from(j['videoTypes'] as List),
  );
}

class PostPage {
  const PostPage({
    required this.items,
    required this.page,
    required this.pageCount,
    this.total = 0,
  });
  final List<PostItem> items;
  final int page;
  final int pageCount;
  final int total;
  factory PostPage.fromJson(Map<String, dynamic> json) => PostPage(
    items: (json['posts'] as List<dynamic>? ?? const [])
        .map((e) => PostItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    page: (json['page'] as num?)?.toInt() ?? 1,
    pageCount: (json['pageCount'] as num?)?.toInt() ?? 1,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );
}

class PostCommentItem {
  const PostCommentItem({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.likeCount,
    required this.liked,
    required this.canEdit,
    required this.canDelete,
    required this.createdAt,
    this.replyCount = 0,
    this.parentId,
    this.replyToUserId,
    this.user,
    this.replyToUser,
  });
  final int id, postId, likeCount, replyCount;
  final String userId, content;
  final int? parentId;
  final String? replyToUserId;
  final bool liked, canEdit, canDelete;
  final DateTime createdAt;
  final PostUser? user, replyToUser;
  factory PostCommentItem.fromJson(Map<String, dynamic> j) => PostCommentItem(
    id: (j['id'] as num).toInt(),
    postId: (j['postId'] as num).toInt(),
    userId: j['userId'].toString(),
    content: j['content'] as String? ?? '',
    parentId: (j['parentId'] as num?)?.toInt(),
    replyToUserId: j['replyToUserId']?.toString(),
    likeCount: (j['likeCount'] as num?)?.toInt() ?? 0,
    replyCount: (j['replyCount'] as num?)?.toInt() ?? 0,
    liked: j['liked'] as bool? ?? false,
    canEdit: j['canEdit'] as bool? ?? false,
    canDelete: j['canDelete'] as bool? ?? false,
    createdAt: DateTime.parse(j['createdAt'] as String),
    user: j['user'] is Map<String, dynamic>
        ? PostUser.fromJson(j['user'])
        : null,
    replyToUser: j['replyToUser'] is Map<String, dynamic>
        ? PostUser.fromJson(j['replyToUser'])
        : null,
  );
}

class PostCommentPage {
  const PostCommentPage({
    required this.items,
    required this.page,
    required this.pageCount,
    required this.total,
  });
  final List<PostCommentItem> items;
  final int page, pageCount, total;
  bool get hasMore => page < pageCount;
  factory PostCommentPage.fromJson(Map<String, dynamic> j) => PostCommentPage(
    items: (j['comments'] as List<dynamic>? ?? const [])
        .map((e) => PostCommentItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    page: (j['page'] as num?)?.toInt() ?? 1,
    pageCount: (j['pageCount'] as num?)?.toInt() ?? 1,
    total: (j['total'] as num?)?.toInt() ?? 0,
  );
}
