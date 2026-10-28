import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/data/repositories/post_repository.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/posts/post_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Khung comment ở trang chi tiết: comment gốc tải 20/trang, reply của mỗi
/// comment gốc chỉ tải khi bấm "View replies", 5/trang.
class PostComments extends StatefulWidget {
  const PostComments({
    super.key,
    required this.repo,
    required this.post,
    required this.readOnly,
    required this.focus,
    this.onCommentAdded,
  });
  final PostRepository repo;
  final PostItem post;
  final bool readOnly;
  final FocusNode focus;
  final VoidCallback? onCommentAdded;

  @override
  State<PostComments> createState() => _PostCommentsState();
}

class _Thread {
  _Thread(this.root);
  PostCommentItem root;
  final replies = <PostCommentItem>[];
  int page = 0, pageCount = 1;
  bool loading = false;
  bool get hasMore => page < pageCount;
  int get remaining => root.replyCount - replies.length;
}

class _PostCommentsState extends State<PostComments> {
  final input = TextEditingController();
  final threads = <_Thread>[];
  int page = 0, pageCount = 1, total = 0;
  bool loading = false;
  String? error;
  PostCommentItem? reply;
  bool sending = false;

  int get postId => widget.post.id;

  @override
  void initState() {
    super.initState();
    _loadRoots();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _loadRoots() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repo.getComments(postId, page: page + 1);
      final known = threads.map((t) => t.root.id).toSet();
      threads.addAll(
        result.items.where((c) => !known.contains(c.id)).map(_Thread.new),
      );
      page = result.page;
      pageCount = result.pageCount;
      total = result.total;
    } catch (_) {
      error = 'Could not load comments';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadReplies(_Thread thread) async {
    if (thread.loading) return;
    setState(() => thread.loading = true);
    try {
      final result = await widget.repo.getComments(
        postId,
        parentId: thread.root.id,
        page: thread.page + 1,
      );
      final known = thread.replies.map((c) => c.id).toSet();
      thread.replies.addAll(result.items.where((c) => !known.contains(c.id)));
      thread.page = result.page;
      thread.pageCount = result.pageCount;
    } catch (_) {
      _snack('Could not load replies');
    } finally {
      if (mounted) setState(() => thread.loading = false);
    }
  }

  Future<void> _send() async {
    final value = input.text.trim();
    if (value.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final created = await widget.repo.comment(
        postId,
        value,
        replyToCommentId: reply?.id,
      );
      input.clear();
      reply = null;
      final parentId = created.parentId;
      if (parentId == null) {
        threads.add(_Thread(created));
        total++;
      } else {
        final thread = threads.where((t) => t.root.id == parentId).firstOrNull;
        if (thread != null) {
          thread.replies.add(created);
          thread.root = _withReplyCount(
            thread.root,
            thread.root.replyCount + 1,
          );
        }
      }
      widget.onCommentAdded?.call();
    } catch (_) {
      _snack('Could not send comment');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _toggleLike(PostCommentItem comment) async {
    final updated = _withLike(comment, !comment.liked);
    setState(() => _replace(updated));
    try {
      await widget.repo.setCommentLike(comment.id, updated.liked);
    } catch (_) {
      if (mounted) setState(() => _replace(comment));
      _snack('Could not update like');
    }
  }

  void _replace(PostCommentItem comment) {
    for (final thread in threads) {
      if (thread.root.id == comment.id) {
        thread.root = comment;
        return;
      }
      final i = thread.replies.indexWhere((c) => c.id == comment.id);
      if (i >= 0) {
        thread.replies[i] = comment;
        return;
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final link = muted?.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 8),
          const SizedBox(height: 8),
          for (final thread in threads) ...[
            _comment(context, thread.root, muted),
            if (thread.replies.isNotEmpty || thread.root.replyCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in thread.replies) _comment(context, r, muted),
                    if (thread.loading)
                      const Padding(
                        padding: EdgeInsets.all(6),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (thread.remaining > 0 &&
                        (thread.page == 0 || thread.hasMore))
                      _LinkButton(
                        icon: Icons.subdirectory_arrow_right,
                        label: thread.page == 0
                            ? 'View ${thread.remaining} repl${thread.remaining == 1 ? 'y' : 'ies'}'
                            : 'View more replies',
                        style: link,
                        onTap: () => _loadReplies(thread),
                      ),
                  ],
                ),
              ),
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Center(
              child: TextButton.icon(
                onPressed: _loadRoots,
                icon: const Icon(Icons.refresh),
                label: Text(error!),
              ),
            )
          else if (page < pageCount)
            _LinkButton(
              label: 'View more comments (${total - threads.length})',
              style: link,
              onTap: _loadRoots,
            )
          else if (threads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No comments yet', style: muted),
            ),
          if (widget.post.allowComments && !widget.readOnly) ...[
            const SizedBox(height: 8),
            _input(context),
          ],
        ],
      ),
    );
  }

  Widget _comment(
    BuildContext context,
    PostCommentItem comment,
    TextStyle? muted,
  ) {
    final theme = Theme.of(context);
    final small = comment.parentId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostAvatar(user: comment.user, radius: small ? 13 : 16),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: postBubbleColor(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.user?.name ?? 'User',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (comment.replyToUser != null)
                              TextSpan(
                                text: '${comment.replyToUser!.name} ',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            TextSpan(text: comment.content),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Wrap(
                    spacing: 14,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(relativeTime(comment.createdAt), style: muted),
                      InkWell(
                        onTap: widget.readOnly
                            ? null
                            : () => _toggleLike(comment),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              comment.liked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: comment.liked ? Colors.red : muted?.color,
                            ),
                            if (comment.likeCount > 0) ...[
                              const SizedBox(width: 3),
                              Text('${comment.likeCount}', style: muted),
                            ],
                          ],
                        ),
                      ),
                      if (!widget.readOnly && widget.post.allowComments)
                        InkWell(
                          onTap: () {
                            setState(() => reply = comment);
                            widget.focus.requestFocus();
                          },
                          child: Text(
                            'Reply',
                            style: muted?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(BuildContext context) {
    final me = context.watch<AppCubit>().state.user;
    final theme = Theme.of(context);
    final noBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PostAvatar(url: me?.avatar, name: me?.name, radius: 16),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: input,
            focusNode: widget.focus,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: postBubbleColor(context),
              hintText: reply == null
                  ? 'Write a comment...'
                  : 'Reply to ${reply!.user?.name ?? 'user'}...',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: noBorder,
              enabledBorder: noBorder,
              focusedBorder: noBorder,
              prefixIcon: reply == null
                  ? null
                  : IconButton(
                      tooltip: 'Cancel reply',
                      onPressed: () => setState(() => reply = null),
                      icon: const Icon(Icons.close, size: 18),
                    ),
              suffixIcon: IconButton(
                tooltip: 'Send',
                onPressed: sending ? null : _send,
                icon: Icon(
                  Icons.send,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.label,
    required this.onTap,
    this.style,
    this.icon,
  });
  final String label;
  final VoidCallback onTap;
  final TextStyle? style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: style?.color),
              const SizedBox(width: 4),
            ],
            Text(label, style: style),
          ],
        ),
      ),
    ),
  );
}

PostCommentItem _withLike(PostCommentItem c, bool liked) => _copy(
  c,
  liked: liked,
  likeCount: (c.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 31),
);

PostCommentItem _withReplyCount(PostCommentItem c, int replyCount) =>
    _copy(c, replyCount: replyCount);

PostCommentItem _copy(
  PostCommentItem c, {
  bool? liked,
  int? likeCount,
  int? replyCount,
}) => PostCommentItem(
  id: c.id,
  postId: c.postId,
  userId: c.userId,
  content: c.content,
  likeCount: likeCount ?? c.likeCount,
  liked: liked ?? c.liked,
  canEdit: c.canEdit,
  canDelete: c.canDelete,
  createdAt: c.createdAt,
  replyCount: replyCount ?? c.replyCount,
  parentId: c.parentId,
  replyToUserId: c.replyToUserId,
  user: c.user,
  replyToUser: c.replyToUser,
);
