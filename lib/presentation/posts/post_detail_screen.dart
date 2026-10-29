import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/data/repositories/post_repository.dart';
import 'package:eflutter/presentation/posts/post_card.dart';
import 'package:eflutter/presentation/posts/post_comments.dart';
import 'package:eflutter/presentation/posts/post_composer_dialog.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Trang chi tiết bài viết cộng đồng (`/posts/:id`).
class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.postId, this.commentId});
  final int postId;

  /// Comment cần mở tới, từ `?comment=` (thông báo comment/reply/like comment).
  final int? commentId;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: PostDetailView(
              postId: postId,
              commentId: commentId,
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Nội dung chi tiết: tải đầy đủ nội dung, toàn bộ file đính kèm, rồi comment phân trang.
/// Không tự cuộn; dùng ở trang bài viết cộng đồng và trong tab Announcements của lớp.
class PostDetailView extends StatefulWidget {
  const PostDetailView({
    super.key,
    required this.postId,
    required this.onBack,
    this.commentId,
    this.backLabel = 'Back',
    this.classroomName,
  });
  final int postId;
  final int? commentId;
  final VoidCallback onBack;
  final String backLabel;

  /// Tên lớp cho popup sửa bài (bài viết trong lớp).
  final String? classroomName;

  @override
  State<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  late final repo = PostRepository(getIt<Dio>());
  final commentFocus = FocusNode();
  PostItem? post;
  String? error;
  bool liking = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Bỏ ?comment= khỏi thanh địa chỉ (chỉ dùng để service worker truyền comment).
    final uri = Uri.base;
    if (uri.queryParameters.containsKey('comment')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemNavigator.routeInformationUpdated(uri: Uri.parse(uri.path), replace: true);
      });
    }
  }

  @override
  void dispose() {
    commentFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = await repo.getPost(widget.postId);
      if (mounted) setState(() => post = value);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load post');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    context.showToast(message, type: ToastType.error);
  }

  Future<void> _like() async {
    final p = post!;
    if (liking) return;
    liking = true;
    setState(() => post = p.withLike(!p.liked));
    try {
      await repo.setLike(p.id, !p.liked);
    } catch (_) {
      if (mounted) setState(() => post = p);
      _snack('Could not update like');
    } finally {
      liking = false;
    }
  }

  Future<void> _pin() async {
    final p = post!;
    if (p.classroomId == null) return;
    try {
      await repo.setPin(p.classroomId!, p.id, !p.pinned);
      await _load();
    } catch (_) {
      _snack('Could not update pin');
    }
  }

  Future<void> _edit() async {
    final p = post!;
    final value = await showDialog<PostComposeResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PostComposerDialog(
        repository: repo,
        content: p.content,
        allowComments: p.allowComments,
        attachments: p.attachments,
        author: p.author,
        editing: true,
        classroomName: widget.classroomName,
      ),
    );
    if (value == null) return;
    try {
      await repo.update(
        p.id,
        value.content,
        allowComments: value.allowComments,
        attachmentIds: value.attachmentIds,
      );
      await _load();
    } catch (_) {
      _snack('Could not save post');
    }
  }

  Future<void> _delete() async {
    try {
      await repo.delete(post!.id);
      if (mounted) widget.onBack();
    } catch (_) {
      _snack('Could not delete post');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = post;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: Text(widget.backLabel),
          ),
        ),
        const SizedBox(height: 8),
        if (p != null)
          PostCard(
            post: p,
            full: true,
            readOnly: false,
            admin: false,
            onLike: _like,
            onPin: _pin,
            onEdit: _edit,
            onDelete: _delete,
            onModerate: (_) {},
            onComment: commentFocus.requestFocus,
            footer: PostComments(
              key: ValueKey(p.id),
              repo: repo,
              post: p,
              readOnly: false,
              focus: commentFocus,
              onCommentAdded: _load,
              focusCommentId: widget.commentId,
            ),
          )
        else if (error != null)
          Center(
            child: FilledButton.icon(
              style: AppButtonStyles.secondary,
              onPressed: () {
                setState(() => error = null);
                _load();
              },
              icon: const Icon(Icons.refresh),
              label: Text(error!),
            ),
          )
        else
          const Padding(padding: EdgeInsets.all(48), child: AppLoader()),
      ],
    );
  }
}
