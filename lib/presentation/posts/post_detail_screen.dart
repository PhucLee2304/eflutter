import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/data/repositories/post_repository.dart';
import 'package:eflutter/presentation/posts/post_card.dart';
import 'package:eflutter/presentation/posts/post_comments.dart';
import 'package:eflutter/presentation/posts/post_composer_dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Trang chi tiết: tải đầy đủ nội dung, toàn bộ file đính kèm, rồi comment
/// phân trang.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final int postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final repo = PostRepository(getIt<Dio>());
  final commentFocus = FocusNode();
  PostItem? post;
  String? error;
  bool liking = false;

  @override
  void initState() {
    super.initState();
    _load();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        editing: true,
      ),
    );
    if (value == null) return;
    try {
      await repo.update(
        p.id,
        value.content,
        allowComments: value.allowComments,
      );
      await _load();
    } catch (_) {
      _snack('Could not save post');
    }
  }

  Future<void> _delete() async {
    try {
      await repo.delete(post!.id);
      if (mounted) _back();
    } catch (_) {
      _snack('Could not delete post');
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    final p = post;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
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
                      ),
                    )
                  else if (error != null)
                    Center(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() => error = null);
                          _load();
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(error!),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
