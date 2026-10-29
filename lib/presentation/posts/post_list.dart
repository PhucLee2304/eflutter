import 'dart:async';
import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/data/repositories/post_repository.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/posts/post_card.dart';
import 'package:eflutter/presentation/posts/post_composer_dialog.dart';
import 'package:eflutter/presentation/posts/post_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
    this.aside,
  });
  final int? classroomId;
  final bool pinned, canCreate, readOnly, admin, mine;

  /// Cột bên trái cột bài viết (trang cá nhân); màn hẹp thì xếp lên trên.
  final Widget? aside;
  @override
  State<PostList> createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  late final repo = PostRepository(getIt<Dio>());
  final controller = ScrollController();
  List<PostItem> items = [];
  int page = 0, pageCount = 1;
  bool loading = true, more = false;
  final liking = <int>{};
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
        mine: widget.mine,
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

  /// Mở trang chi tiết; quay lại thì tải lại để cập nhật số like/comment.
  Future<void> open(PostItem p) async {
    await context.push('/posts/${p.id}');
    if (mounted) await load();
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

  /// Cập nhật ngay trên giao diện rồi mới gọi API; lỗi thì hoàn lại.
  Future<void> like(PostItem p) async {
    if (widget.readOnly || liking.contains(p.id)) return;
    liking.add(p.id);
    _replace(p.withLike(!p.liked));
    try {
      await repo.setLike(p.id, !p.liked);
    } catch (_) {
      _replace(p);
      _message('Could not update like');
    } finally {
      liking.remove(p.id);
    }
  }

  void _replace(PostItem post) {
    if (!mounted) return;
    setState(() {
      items = [for (final e in items) e.id == post.id ? post : e];
    });
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final aside = widget.aside;
              if (aside == null) return Center(child: _feed(context));
              if (constraints.maxWidth < 1100) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        aside,
                        const SizedBox(height: 16),
                        _feed(context),
                      ],
                    ),
                  ),
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 24,
                children: [
                  SizedBox(width: 380, child: aside),
                  _feed(context),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Cột feed rộng tối đa 680 như Facebook.
  Widget _feed(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 680),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.canCreate && !widget.pinned && !widget.readOnly)
          _ComposerPrompt(onTap: () => compose()),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: Text('No posts yet')),
          ),
        ...items.map(
          (p) => PostCard(
            key: ValueKey(p.id),
            post: p,
            readOnly: widget.readOnly,
            onLike: () => like(p),
            onPin: () => pin(p),
            onEdit: () => compose(p),
            onDelete: () => remove(p),
            admin: widget.admin,
            onModerate: (action) => moderate(p, action),
            onOpen: () => open(p),
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

class _ComposerPrompt extends StatelessWidget {
  const _ComposerPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppCubit>().state.user;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PostAvatar(url: me?.avatar, name: me?.name),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: postBubbleColor(context),
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    child: Text(
                      "What's on your mind${me == null ? '' : ', ${me.name.split(' ').last}'}?",
                      style: TextStyle(color: theme.hintColor, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
