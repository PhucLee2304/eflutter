import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/post.dart';
import 'package:eflutter/data/repositories/post_repository.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/posts/post_card.dart';
import 'package:eflutter/presentation/posts/post_composer_dialog.dart';
import 'package:eflutter/presentation/posts/post_detail_screen.dart';
import 'package:eflutter/presentation/posts/post_media.dart';
import 'package:eflutter/presentation/app/theme/app_button_styles.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CommunityPostsScreen extends StatelessWidget {
  const CommunityPostsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AppCubit>().state.user?.role.toLowerCase() == 'admin';
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
                        children: [PostList(), PostList(admin: true, canCreate: false)],
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

/// Tab Announcements của lớp: bài viết nằm chung cuộn với trang chi tiết lớp, [aside] ở cột trái.
class ClassroomPostsView extends StatefulWidget {
  const ClassroomPostsView({
    super.key,
    required this.classroomId,
    required this.isTeacher,
    required this.active,
    this.aside,
    this.classroomName,
    this.postId,
    this.commentId,
  });
  final int classroomId;
  final bool isTeacher, active;
  final Widget? aside;
  final String? classroomName;

  /// Bài mở sẵn khi vào từ link/thông báo (`/classrooms/:id/posts/:postId`).
  final int? postId;
  final int? commentId;

  @override
  State<ClassroomPostsView> createState() => _ClassroomPostsViewState();
}

class _ClassroomPostsViewState extends State<ClassroomPostsView> {
  bool pinned = false;

  // Bài đang mở chi tiết ngay trong cột bài viết; danh sách vẫn giữ nguyên bên dưới (Offstage)
  // để quay lại đúng chỗ mà không vẽ lại cả trang.
  late int? openPostId = widget.postId;
  late int? openCommentId = widget.commentId;
  Completer<void>? _closed;
  double _listOffset = 0;
  final _detailKey = GlobalKey();

  void _setUrl(String path) =>
      SystemNavigator.routeInformationUpdated(uri: Uri.parse(path), replace: true);

  Future<void> _openPost(PostItem post) {
    _listOffset = Scrollable.maybeOf(context)?.position.pixels ?? 0;
    _closed = Completer<void>();
    setState(() {
      openPostId = post.id;
      openCommentId = null;
    });
    _setUrl(classroomPostPath(widget.classroomId, post.id));
    // Đưa đầu bài viết vào khung nhìn nếu đang cuộn sâu trong danh sách.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _detailKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
    return _closed!.future;
  }

  void _closePost() {
    final position = Scrollable.maybeOf(context)?.position;
    setState(() => openPostId = null);
    _setUrl(classroomPath(widget.classroomId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (position != null && position.hasPixels) {
        position.jumpTo(_listOffset.clamp(0, position.maxScrollExtent));
      }
      _closed?.complete();
      _closed = null;
    });
  }

  Widget _filter(String label, bool value) {
    final selected = pinned == value;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: selected ? null : () => setState(() => pinned = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : null,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (value)
              Icon(
                Icons.push_pin_outlined,
                size: 15,
                color: selected ? ColorName.primary : ColorName.labelSecondary,
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? ColorName.primary : ColorName.labelSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postId = openPostId;
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_filter('Recent', false), _filter('Pinned', true)],
            ),
          ),
        ),
        PostList(
          // Đổi bộ lọc thì tạo list mới để tải lại từ trang 1.
          key: ValueKey(pinned),
          classroomId: widget.classroomId,
          pinned: pinned,
          canCreate: widget.isTeacher && widget.active,
          readOnly: !widget.active,
          embedded: true,
          classroomName: widget.classroomName,
          onOpen: _openPost,
        ),
      ],
    );
    final feed = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (postId != null)
          PostDetailView(
            key: _detailKey,
            postId: postId,
            commentId: openCommentId,
            classroomName: widget.classroomName,
            onBack: _closePost,
          ),
        Offstage(offstage: postId != null, child: list),
      ],
    );
    final aside = widget.aside;
    if (aside == null) return feed;
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 900
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 24,
              children: [
                SizedBox(width: 300, child: aside),
                Expanded(child: feed),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [aside, const SizedBox(height: 16), feed],
            ),
    );
  }
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
    this.embedded = false,
    this.classroomName,
    this.onOpen,
  });
  final int? classroomId;
  final bool pinned, canCreate, readOnly, admin, mine;

  /// Không tự cuộn: nằm trong cuộn của màn cha và tải thêm theo cuộn đó (stream lớp học).
  final bool embedded;

  /// Tên lớp hiển thị trong popup đăng bài của lớp.
  final String? classroomName;

  /// Mở chi tiết tại chỗ thay vì đổi trang; xong (future hoàn tất) thì tải lại bài đó.
  final Future<void> Function(PostItem post)? onOpen;

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

  ScrollPosition? _parentPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.embedded) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position == _parentPosition) return;
    _parentPosition?.removeListener(_parentScroll);
    _parentPosition = position?..addListener(_parentScroll);
  }

  @override
  void dispose() {
    _parentPosition?.removeListener(_parentScroll);
    controller.dispose();
    super.dispose();
  }

  void _scroll() {
    if (controller.position.extentAfter < 300) unawaited(loadMore());
  }

  void _parentScroll() {
    // Đang ẩn sau trang chi tiết bài viết thì không tải thêm.
    if (context.findAncestorWidgetOfExactType<Offstage>()?.offstage ?? false) return;
    if ((_parentPosition?.extentAfter ?? double.infinity) < 300) unawaited(loadMore());
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
        attachments: post?.attachments ?? const [],
        author: post?.author,
        editing: post != null,
        classroomName: widget.classroomName,
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
          attachmentIds: value.attachmentIds,
        );
      }
      await load();
    } catch (e) {
      _message('Could not save post');
    }
  }

  /// Mở trang chi tiết; quay lại thì chỉ tải lại bài đó và thay tại chỗ để
  /// giữ nguyên vị trí cuộn (bài bị xóa ở trang chi tiết thì bỏ khỏi list).
  Future<void> open(PostItem p) async {
    final classroomId = widget.classroomId;
    if (widget.onOpen case final onOpen?) {
      await onOpen(p);
    } else {
      await context.push(
        classroomId == null ? postDetailPath(p.id) : classroomPostPath(classroomId, p.id),
      );
    }
    if (!mounted) return;
    try {
      final fresh = await repo.getPost(p.id);
      if (mounted) {
        setState(() => items = [for (final i in items) i.id == p.id ? fresh : i]);
      }
    } on DioException catch (e) {
      if (mounted && e.response?.statusCode == 404) {
        setState(() => items = items.where((i) => i.id != p.id).toList());
      }
    } catch (_) {}
  }

  void _message(String value) {
    if (mounted) {
      context.showToast(value, type: ToastType.error);
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
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: AppButtonStyles.secondary,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            style: AppButtonStyles.primary,
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
    if (loading) {
      return widget.embedded
          ? const Padding(padding: EdgeInsets.all(48), child: AppLoader())
          : const AppLoader();
    }
    if (error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: load,
          style: AppButtonStyles.secondary,
          icon: const Icon(Icons.refresh),
          label: Text(error!),
        ),
      );
    }
    if (widget.embedded) return _feed(context, maxWidth: double.infinity);
    return LayoutBuilder(
      builder: (context, constraints) {
        final aside = widget.aside;
        final wide = aside != null && constraints.maxWidth >= 1100;
        final list = RefreshIndicator(
          onRefresh: load,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            children: [
              if (wide)
                // Chừa chỗ bên trái cho khung [aside] được ghim ở Stack bên dưới.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: _asideGap,
                  children: [
                    const SizedBox(width: _asideWidth),
                    _feed(context),
                  ],
                )
              else if (aside != null)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [aside, const SizedBox(height: 16), _feed(context)],
                    ),
                  ),
                )
              else
                Center(child: _feed(context)),
            ],
          ),
        );
        if (!wide) return list;
        // Khung aside đứng yên khi cuộn bài viết (như cột trái Facebook).
        final left = (constraints.maxWidth - _asideWidth - _asideGap - 680) / 2;
        return Stack(
          children: [
            list,
            Positioned(
              left: left,
              top: 16,
              width: _asideWidth,
              bottom: 16,
              child: SingleChildScrollView(child: aside),
            ),
          ],
        );
      },
    );
  }

  static const _asideWidth = 380.0;
  static const _asideGap = 24.0;

  // Cột feed rộng tối đa 680 như Facebook.
  Widget _feed(BuildContext context, {double maxWidth = 680}) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.canCreate && !widget.pinned && !widget.readOnly)
          widget.classroomId == null
              ? _ComposerPrompt(onTap: () => compose())
              : _ClassComposerBar(onTap: () => compose()),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(36),
            child: Center(child: Text(widget.pinned ? 'No pinned posts' : 'No posts yet')),
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
        if (more) const Padding(padding: EdgeInsets.all(16), child: AppLoader()),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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

/// Thanh đăng bài gọn của lớp học (thay khung "What's on your mind").
class _ClassComposerBar extends StatelessWidget {
  const _ClassComposerBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AppCubit>().state.user;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E6EB)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              spacing: 12,
              children: [
                PostAvatar(url: me?.avatar, name: me?.name),
                const Expanded(
                  child: Text(
                    'Announce something to your class…',
                    style: TextStyle(fontSize: 14, color: Color(0xFF8A8D91)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
