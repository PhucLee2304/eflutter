import 'package:eflutter/core/utils/extensions/toast_bar_extension.dart';
import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/classrooms/create_classroom_dialog.dart';
import 'package:eflutter/presentation/classrooms/join_classroom_dialog.dart';
import 'package:eflutter/generated/colors.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ClassroomListScreen extends StatefulWidget {
  const ClassroomListScreen({super.key});
  @override
  State<ClassroomListScreen> createState() => _ClassroomListScreenState();
}

class _ClassroomListScreenState extends State<ClassroomListScreen> {
  late final ClassroomRepository repository = ClassroomRepository(getIt<Dio>());
  final search = TextEditingController();
  final scrollController = ScrollController();
  List<Classroom> classrooms = [];
  int page = 1;
  int pageCounts = 1;
  bool loading = false;
  bool loadingMore = false;
  String? error;
  String activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    scrollController.addListener(loadMoreWhenNeeded);
    load();
  }

  @override
  void dispose() {
    search.dispose();
    scrollController
      ..removeListener(loadMoreWhenNeeded)
      ..dispose();
    super.dispose();
  }

  void loadMoreWhenNeeded() {
    if (scrollController.position.extentAfter < 320 && page < pageCounts) {
      load(reset: false);
    }
  }

  Future<void> load({bool reset = true}) async {
    if (loading || loadingMore || (!reset && page >= pageCounts)) return;
    final requestedPage = reset ? 1 : page + 1;
    setState(() {
      if (reset) {
        loading = true;
        error = null;
      } else {
        loadingMore = true;
      }
    });
    final result = await repository.getMine(
      page: requestedPage,
      query: search.text.trim(),
      active: switch (activeFilter) {
        'active' => true,
        'archived' => false,
        _ => null,
      },
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      loadingMore = false;
      switch (result) {
        case Success(data: final data):
          classrooms = reset ? data.items : [...classrooms, ...data.items];
          page = requestedPage;
          pageCounts = data.pageCounts;
        case Failure(message: final message):
          if (reset) error = message;
        case Cancelled():
          break;
      }
    });
  }

  Future<void> create() async {
    final classroom = await showCreateClassroomDialog(context);
    if (classroom == null || !mounted) return;
    await load();
    if (mounted) context.go('${AppRoutes.classrooms.path}/${classroom.id}');
  }

  Future<void> join() async {
    final value = await showJoinClassroomDialog(context);
    if (value == null || value.isEmpty || !mounted) return;
    final preview = await repository.preview(value);
    if (!mounted) return;
    if (preview case Success(data: final classroom)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(classroom.name),
          content: Text(
            'Teacher: ${classroom.teacher?.name ?? 'Unknown'}\n'
            '${classroom.countApprovedMembers ?? 0} students',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Request to join'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final result = await repository.join(value);
      if (!mounted) return;
      switch (result) {
        case Success():
          showMessage('Request sent. Waiting for teacher approval.', type: ToastType.success);
        case Failure(message: final message):
          showMessage(message ?? 'Could not join the classroom');
        case Cancelled():
          break;
      }
    } else if (preview case Failure(message: final message)) {
      showMessage(message ?? 'Classroom not found');
    }
  }

  void showMessage(String text, {ToastType type = ToastType.error}) =>
      context.showToast(text, type: type);

  static const _border = Color(0xFFDADDE1);
  static const _muted = Color(0xFF65676B);
  static const _covers = [
    Color(0xFF4F6D8A),
    Color(0xFF6B7F5E),
    Color(0xFF8A6B4F),
    Color(0xFF5E6B8A),
    Color(0xFF7A5E7F),
    Color(0xFF4F7F7A),
  ];

  Widget _header(String? userId) {
    final teaching = classrooms.where((c) => c.teacher?.id == userId).length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Classrooms', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '${classrooms.length} classrooms · $teaching you teach',
                style: const TextStyle(fontSize: 14, color: _muted),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: join,
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Join with code'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ColorName.primary,
            side: const BorderSide(color: ColorName.primary),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: create,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create classroom'),
          style: FilledButton.styleFrom(
            backgroundColor: ColorName.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _toolbar() {
    const outline = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: _border),
    );
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: search,
            onSubmitted: (_) => load(),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search, color: Color(0xFF8A8D91)),
              hintText: 'Search by name, description, or teacher',
              border: outline,
              enabledBorder: outline,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF0F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              for (final (value, label) in const [
                ('all', 'All'),
                ('active', 'Active'),
                ('archived', 'Archived'),
              ])
                _pill(value, label),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String value, String label) {
    final selected = activeFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () {
        if (selected) return;
        setState(() => activeFilter = value);
        load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : null,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? ColorName.primary : _muted,
          ),
        ),
      ),
    );
  }

  Widget _grid(String? userId) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? 3
          : constraints.maxWidth >= 640
          ? 2
          : 1;
      final width = (constraints.maxWidth - 20 * (columns - 1)) / columns;
      return Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          for (final item in classrooms)
            SizedBox(
              width: width,
              child: _ClassroomCard(
                item: item,
                cover: _covers[item.id % _covers.length],
                isTeacher: item.teacher?.id == userId,
                onTap: () => context.go('${AppRoutes.classrooms.path}/${item.id}'),
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final userId = context.select<AppCubit, String?>((c) => c.state.user?.id.toString());
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: RefreshIndicator(
        onRefresh: load,
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1224),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(userId),
                    const SizedBox(height: 20),
                    _toolbar(),
                    const SizedBox(height: 20),
                    if (loading) const Padding(padding: EdgeInsets.all(48), child: AppLoader()),
                    if (error != null)
                      ListTile(
                        title: Text(error!),
                        trailing: IconButton(
                          tooltip: 'Retry',
                          onPressed: load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    if (!loading && error == null && classrooms.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'No classrooms yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted),
                        ),
                      ),
                    if (!loading) _grid(userId),
                    if (loadingMore) const Padding(padding: EdgeInsets.all(24), child: AppLoader()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassroomCard extends StatefulWidget {
  const _ClassroomCard({
    required this.item,
    required this.cover,
    required this.isTeacher,
    required this.onTap,
  });

  final Classroom item;
  final Color cover;
  final bool isTeacher;
  final VoidCallback onTap;

  @override
  State<_ClassroomCard> createState() => _ClassroomCardState();
}

class _ClassroomCardState extends State<_ClassroomCard> {
  bool hover = false;

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final active = item.active;
    final cover = active ? widget.cover : const Color(0xFFB0B3B8);
    final description = item.description?.trim() ?? '';
    final teacher = item.teacher;
    final hasAvatar = item.avatar?.isNotEmpty == true;
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E6EB)),
            boxShadow: hover
                ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4))]
                : null,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 88,
                    color: cover,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.all(12),
                    child: !active
                        ? _badge('Archived', const Color(0xFF65676B))
                        : widget.isTeacher
                        ? _badge('Teacher', const Color(0xFF191919))
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: active ? const Color(0xFF191919) : const Color(0xFF65676B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description.isEmpty ? 'No description' : description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: description.isEmpty
                                ? const Color(0xFFB0B3B8)
                                : const Color(0xFF65676B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFEEF0F2)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: const Color(0xFFD8DADF),
                              backgroundImage: teacher?.avatar?.isNotEmpty == true
                                  ? NetworkImage(teacher!.avatar!)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                teacher?.name ?? 'Teacher',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF3A3B3C),
                                ),
                              ),
                            ),
                            if (item.countApprovedMembers != null) ...[
                              const Icon(Icons.group_outlined, size: 16, color: Color(0xFF65676B)),
                              const SizedBox(width: 4),
                              Text(
                                '${item.countApprovedMembers}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF65676B)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F2F5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.code,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF3A3B3C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 16,
                top: 62,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 3),
                    image: hasAvatar
                        ? DecorationImage(image: NetworkImage(item.avatar!), fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: hasAvatar
                      ? null
                      : Text(
                          item.name.isEmpty ? '?' : item.name[0].toUpperCase(),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: cover),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
