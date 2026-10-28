import 'dart:async';
import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/data/repositories/post_repository.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/posts/post_composer_dialog.dart';
import 'package:eflutter/presentation/shared/app_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityPostsScreen extends StatelessWidget {
  const CommunityPostsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final admin =
        context.watch<AppCubit>().state.user?.role.toLowerCase() == 'admin';
    return Scaffold(
      body: SafeArea(
        child: admin
            ? const DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: 'Community'),
                        Tab(text: 'Moderation'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          PostList(),
                          PostList(admin: true, canCreate: false),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : const PostList(),
      ),
    );
  }
}

class ClassroomPostsView extends StatelessWidget {
  const ClassroomPostsView({
    super.key,
    required this.classroomId,
    required this.isTeacher,
    required this.active,
  });
  final int classroomId;
  final bool isTeacher, active;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'Posts'),
            Tab(text: 'Pinned'),
          ],
        ),
        SizedBox(
          height: 560,
          child: TabBarView(
            children: [
              PostList(
                classroomId: classroomId,
                canCreate: isTeacher && active,
                readOnly: !active,
              ),
              PostList(
                classroomId: classroomId,
                pinned: true,
                readOnly: !active,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PostList extends StatefulWidget {
  const PostList({
    super.key,
    this.classroomId,
    this.pinned = false,
    this.canCreate = true,
    this.readOnly = false,
    this.admin = false,
    this.mine = false,
  });
  final int? classroomId;
  final bool pinned, canCreate, readOnly, admin, mine;
  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  late final repo = PostRepository(getIt<Dio>());
  final controller = ScrollController();
  List<PostItem> items = [];
  int page = 0, pageCount = 1;
  bool loading = true, more = false;
  String? error;
  @override
  void initState() {
    super.initState();
    controller.addListener(_scroll);
    unawaited(load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _scroll() {
    if (controller.position.extentAfter < 300) unawaited(loadMore());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final v = await repo.getPosts(
        page: 1,
        classroomId: widget.classroomId,
        pinned: widget.pinned,
        admin: widget.admin,
        mine: widget.mine,
      );
      if (mounted) {
        setState(() {
          items = v.items;
          page = v.page;
          pageCount = v.pageCount;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Could not load posts';
          loading = false;
        });
      }
    }
  }

  Future<void> loadMore() async {
    if (more || page >= pageCount) return;
    setState(() => more = true);
    try {
      final v = await repo.getPosts(
        page: page + 1,
        classroomId: widget.classroomId,
        pinned: widget.pinned,
        admin: widget.admin,
      );
      if (mounted) {
        setState(() {
          items = [...items, ...v.items];
          page = v.page;
          pageCount = v.pageCount;
          more = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => more = false);
    }
  }

  Future<void> compose([PostItem? post]) async {
    final value = await showDialog<PostComposeResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PostComposerDialog(
        repository: repo,
        content: post?.content ?? '',
        allowComments: post?.allowComments ?? true,
        editing: post != null,
      ),
    );
    if (value == null) return;
    try {
      if (post == null) {
        await repo.create(
          value.content,
          classroomId: widget.classroomId,
          allowComments: value.allowComments,
          attachmentIds: value.attachmentIds,
        );
      } else {
        await repo.update(
          post.id,
          value.content,
          allowComments: value.allowComments,
        );
      }
      await load();
    } catch (e) {
      _message('Could not save post');
    }
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> remove(PostItem p) async {
    try {
      await repo.delete(p.id);
      setState(() => items.removeWhere((e) => e.id == p.id));
    } catch (_) {
      _message('Could not delete post');
    }
  }

  Future<void> like(PostItem p) async {
    if (widget.readOnly) return;
    try {
      await repo.setLike(p.id, !p.liked);
      await load();
    } catch (_) {
      _message('Could not update like');
    }
  }

  Future<void> pin(PostItem p) async {
    if (widget.classroomId == null || widget.readOnly) return;
    try {
      await repo.setPin(widget.classroomId!, p.id, !p.pinned);
      await load();
    } catch (_) {
      _message('Could not update pin');
    }
  }

  Future<void> moderate(PostItem post, String action) async {
    final input = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action[0]}${action.substring(1).toLowerCase()} post'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    input.dispose();
    if (reason == null || reason.isEmpty) return;
    try {
      await repo.moderate(post.id, action, reason);
      await load();
    } catch (_) {
      _message('Could not moderate post');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: FilledButton.tonalIcon(
          onPressed: load,
          icon: const Icon(Icons.refresh),
          label: Text(error!),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          if (widget.canCreate && !widget.pinned && !widget.readOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => compose(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create post'),
                ),
              ),
            ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: Text('No posts yet')),
            ),
          ...items.map(
            (p) => _PostCard(
              post: p,
              readOnly: widget.readOnly,
              onLike: () => like(p),
              onPin: () => pin(p),
              onEdit: () => compose(p),
              onDelete: () => remove(p),
              repo: repo,
              admin: widget.admin,
              onModerate: (action) => moderate(p, action),
            ),
          ),
          if (more)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  const _PostCard({
    required this.post,
    required this.readOnly,
    required this.onLike,
    required this.onPin,
    required this.onEdit,
    required this.onDelete,
    required this.repo,
    required this.admin,
    required this.onModerate,
  });
  final PostItem post;
  final bool readOnly;
  final VoidCallback onLike, onPin, onEdit, onDelete;
  final PostRepository repo;
  final bool admin;
  final ValueChanged<String> onModerate;
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool expanded = false;
  bool loading = false;
  List<PostCommentItem> comments = [];
  final input = TextEditingController();
  PostCommentItem? reply;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> open() async {
    setState(() => expanded = !expanded);
    if (!expanded) return;
    setState(() => loading = true);
    try {
      comments = await widget.repo.getComments(widget.post.id);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final value = input.text.trim();
    if (value.isEmpty) return;
    await widget.repo.comment(
      widget.post.id,
      value,
      replyToCommentId: reply?.id,
    );
    input.clear();
    reply = null;
    comments = await widget.repo.getComments(widget.post.id);
    if (mounted) setState(() {});
  }

  Future<void> toggleCommentLike(PostCommentItem comment) async {
    await widget.repo.setCommentLike(comment.id, !comment.liked);
    comments = await widget.repo.getComments(widget.post.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final hidden = post.status == 'HIDDEN';
    return Opacity(
      opacity: hidden ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: post.author?.avatar != null
                        ? NetworkImage(post.author!.avatar!)
                        : null,
                    child: post.author?.avatar == null
                        ? const Icon(Icons.person_outline)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author?.name ?? 'User',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _date(post.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (post.pinned)
                    const Tooltip(
                      message: 'Pinned',
                      child: Icon(Icons.push_pin, size: 19),
                    ),
                  if (hidden)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Chip(label: Text('Hidden by moderation')),
                    ),
                  if (widget.admin)
                    PopupMenuButton<String>(
                      tooltip: 'Moderate',
                      onSelected: widget.onModerate,
                      itemBuilder: (_) => [
                        if (post.status == 'PUBLISHED')
                          const PopupMenuItem(
                            value: 'HIDE',
                            child: Text('Hide'),
                          ),
                        if (post.status == 'HIDDEN')
                          const PopupMenuItem(
                            value: 'UNHIDE',
                            child: Text('Unhide'),
                          ),
                        const PopupMenuItem(
                          value: 'DELETE',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  if (post.canEdit || post.canDelete || post.canPin)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') widget.onEdit();
                        if (value == 'delete') widget.onDelete();
                        if (value == 'pin') widget.onPin();
                      },
                      itemBuilder: (_) => [
                        if (post.canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                        if (post.canPin && !widget.readOnly)
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(post.pinned ? 'Unpin' : 'Pin'),
                          ),
                        if (post.canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(post.content),
              if (post.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...post.attachments.map((attachment) {
                  if (attachment.mediaType == 'VIDEO') {
                    if (attachment.processingStatus == 'PROCESSING') {
                      return const ListTile(
                        leading: CircularProgressIndicator(),
                        title: Text('Video is being processed'),
                      );
                    }
                    if (attachment.processingStatus == 'FAILED') {
                      return const ListTile(
                        leading: Icon(Icons.error_outline),
                        title: Text('Video processing failed'),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppVideoPlayer(
                        url: attachment.url,
                        thumbnailUrl: attachment.thumbnailUrl,
                      ),
                    );
                  }
                  if (attachment.mediaType == 'IMAGE') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 480),
                          child: Image.network(
                            attachment.url,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      attachment.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_attachmentSize(attachment.size)),
                    trailing: IconButton(
                      tooltip: 'Open',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => launchUrl(
                        Uri.parse(attachment.url),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: post.liked ? 'Unlike' : 'Like',
                    onPressed: widget.readOnly ? null : widget.onLike,
                    icon: Icon(
                      post.liked ? Icons.favorite : Icons.favorite_border,
                      color: post.liked ? Colors.red : null,
                    ),
                  ),
                  Text('${post.likeCount}'),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Comments',
                    onPressed: post.allowComments || post.commentCount > 0
                        ? open
                        : null,
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                  Text('${post.commentCount}'),
                ],
              ),
              if (expanded) ...[
                const Divider(),
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else
                  ...comments.map(
                    (comment) => Padding(
                      padding: EdgeInsets.only(
                        left: comment.parentId == null ? 0 : 28,
                        bottom: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 15,
                            child: Icon(Icons.person, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  comment.user?.name ?? 'User',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (comment.replyToUser != null)
                                  Text(
                                    'Replying to ${comment.replyToUser!.name}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                Text(comment.content),
                                Wrap(
                                  children: [
                                    TextButton(
                                      onPressed: widget.readOnly
                                          ? null
                                          : () =>
                                                setState(() => reply = comment),
                                      child: const Text('Reply'),
                                    ),
                                    TextButton.icon(
                                      onPressed: widget.readOnly
                                          ? null
                                          : () => toggleCommentLike(comment),
                                      icon: Icon(
                                        comment.liked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 16,
                                        color: comment.liked
                                            ? Colors.red
                                            : null,
                                      ),
                                      label: Text('${comment.likeCount}'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (post.allowComments && !widget.readOnly)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          decoration: InputDecoration(
                            hintText: reply == null
                                ? 'Write a comment'
                                : 'Reply to ${reply!.user?.name ?? 'user'}',
                            suffixIcon: reply == null
                                ? null
                                : IconButton(
                                    onPressed: () =>
                                        setState(() => reply = null),
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Send',
                        onPressed: send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _date(DateTime value) {
  final v = value.toLocal();
  return '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year} ${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
}

String _attachmentSize(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB'
    : '${(bytes / 1024).toStringAsFixed(1)} KiB';
