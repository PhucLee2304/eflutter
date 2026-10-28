import 'package:dio/dio.dart';
import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/core/utils/helpers/file_picker/local_picked_file.dart';

class PostRepository {
  PostRepository(this._dio);
  final Dio _dio;

  /// Dio không có interceptor: URL presigned đã chứa chữ ký, MinIO từ chối nếu
  /// request còn kèm header Authorization của app.
  static final _storageDio = Dio();
  static const _base = '/posts/api/v1';
  Future<PostPage> getPosts({
    required int page,
    int? classroomId,
    bool pinned = false,
    bool admin = false,
    bool mine = false,
  }) async {
    final path = mine
        ? '$_base/posts/me'
        : admin
        ? '$_base/admin/posts'
        : classroomId == null
        ? '$_base/posts'
        : '$_base/classrooms/$classroomId/posts${pinned ? '/pinned' : ''}';
    final r = await _dio.get(
      path,
      queryParameters: {'page': page, 'pageSize': 20},
    );
    return PostPage.fromJson(r.data as Map<String, dynamic>);
  }

  Future<PostItem> create(
    String content, {
    int? classroomId,
    bool allowComments = true,
    List<int> attachmentIds = const [],
  }) async {
    final path = classroomId == null
        ? '$_base/posts'
        : '$_base/classrooms/$classroomId/posts';
    final r = await _dio.post(
      path,
      data: {
        'content': content,
        'allowComments': allowComments,
        'attachmentIds': attachmentIds,
      },
    );
    return PostItem.fromJson(r.data as Map<String, dynamic>);
  }

  Future<PostUploadLimits> getUploadLimits() async {
    final r = await _dio.get('$_base/post-uploads/config');
    return PostUploadLimits.fromJson(r.data as Map<String, dynamic>);
  }

  Future<int> uploadAttachment(
    LocalPickedFile file, {
    required CancelToken cancelToken,
    required void Function(double) onProgress,
  }) async {
    final intent = await _dio.post(
      '$_base/post-uploads',
      data: {
        'originalName': file.name,
        'contentType': file.contentType,
        'size': file.bytes.length,
      },
    );
    final data = intent.data as Map<String, dynamic>;
    final id = (data['id'] as num).toInt();
    try {
      await _storageDio.putUri(
        Uri.parse(data['uploadUrl'] as String),
        data: file.bytes,
        options: Options(headers: {'Content-Type': data['contentType']}),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) =>
            onProgress(total <= 0 ? 0 : sent / total),
      );
      final complete = await _dio.post('$_base/post-uploads/$id/complete');
      return ((complete.data as Map<String, dynamic>)['id'] as num).toInt();
    } catch (_) {
      if (!cancelToken.isCancelled) {
        try {
          await _dio.delete('$_base/post-uploads/$id');
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<PostItem> update(
    int id,
    String content, {
    required bool allowComments,
  }) async {
    final r = await _dio.patch(
      '$_base/posts/$id',
      data: {'content': content, 'allowComments': allowComments},
    );
    return PostItem.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _dio.delete('$_base/posts/$id');
  Future<void> setLike(int id, bool value) => value
      ? _dio.post('$_base/posts/$id/like')
      : _dio.delete('$_base/posts/$id/like');
  Future<void> setPin(int classroomId, int id, bool value) => value
      ? _dio.post('$_base/classrooms/$classroomId/posts/$id/pin')
      : _dio.delete('$_base/classrooms/$classroomId/posts/$id/pin');
  Future<PostItem> getPost(int id) async {
    final r = await _dio.get('$_base/posts/$id');
    return PostItem.fromJson(r.data as Map<String, dynamic>);
  }

  /// Một trang comment gốc (không có [parentId]) hoặc reply của comment gốc [parentId].
  Future<PostCommentPage> getComments(
    int postId, {
    int? parentId,
    int page = 1,
    int? pageSize,
  }) async {
    final r = await _dio.get(
      '$_base/posts/$postId/comments',
      queryParameters: {
        'page': page,
        'pageSize': pageSize ?? (parentId == null ? 20 : 5),
        'parentId': ?parentId,
      },
    );
    return PostCommentPage.fromJson(r.data as Map<String, dynamic>);
  }

  Future<PostCommentItem> comment(
    int postId,
    String content, {
    int? replyToCommentId,
  }) async {
    final r = await _dio.post(
      '$_base/posts/$postId/comments',
      data: {'content': content, 'replyToCommentId': ?replyToCommentId},
    );
    return PostCommentItem.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> deleteComment(int id) => _dio.delete('$_base/comments/$id');
  Future<void> setCommentLike(int id, bool value) => value
      ? _dio.post('$_base/comments/$id/like')
      : _dio.delete('$_base/comments/$id/like');

  Future<void> moderate(int id, String action, String reason) {
    if (action == 'HIDE') {
      return _dio.post('$_base/admin/posts/$id/hide', data: {'reason': reason});
    }
    if (action == 'UNHIDE') {
      return _dio.delete(
        '$_base/admin/posts/$id/hide',
        data: {'reason': reason},
      );
    }
    return _dio.delete('$_base/admin/posts/$id', data: {'reason': reason});
  }
}
