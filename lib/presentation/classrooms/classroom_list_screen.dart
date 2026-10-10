import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:flutter/material.dart';
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
    var name = '';
    var description = '';
    final form = GlobalKey<FormState>();
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Create classroom'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  onChanged: (value) => name = value,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Classroom name',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a classroom name'
                      : null,
                ),
                TextFormField(
                  onChanged: (value) => description = value,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, (name, description));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (values == null || !mounted) return;
    final result = await repository.create(values.$1, description: values.$2);
    if (!mounted) return;
    switch (result) {
      case Success(data: final classroom):
        await load();
        if (mounted) context.go('${AppRoutes.classrooms.path}/${classroom.id}');
      case Failure(message: final message):
        showMessage(message ?? 'Could not create the classroom');
      case Cancelled():
        break;
    }
  }

  Future<void> join() async {
    var code = '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a classroom'),
        content: SizedBox(
          width: 360,
          child: TextField(
            onChanged: (value) => code = value,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Class code'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, code.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
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
          showMessage('Request sent. Waiting for teacher approval.');
        case Failure(message: final message):
          showMessage(message ?? 'Could not join the classroom');
        case Cancelled():
          break;
      }
    } else if (preview case Failure(message: final message)) {
      showMessage(message ?? 'Classroom not found');
    }
  }

  void showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: RefreshIndicator(
      onRefresh: load,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Classrooms',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: join,
                            tooltip: 'Join classroom',
                            icon: const Icon(Icons.group_add_outlined),
                          ),
                          IconButton(
                            onPressed: create,
                            tooltip: 'Create classroom',
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: search,
                        onSubmitted: (_) {
                          load();
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search by name, description, or teacher',
                          suffixIcon: IconButton(
                            tooltip: 'Search',
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () {
                              load();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'all', label: Text('All')),
                              ButtonSegment(
                                value: 'active',
                                label: Text('Active'),
                              ),
                              ButtonSegment(
                                value: 'archived',
                                label: Text('Archived'),
                              ),
                            ],
                            selected: {activeFilter},
                            onSelectionChanged: (selection) {
                              setState(() {
                                activeFilter = selection.single;
                              });
                              load();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      if (loading) const LinearProgressIndicator(),
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
                          child: Text('No classrooms yet'),
                        ),
                      ...classrooms.map(
                        (item) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: item.avatar?.isNotEmpty == true
                                  ? NetworkImage(item.avatar!)
                                  : null,
                              child: item.avatar?.isNotEmpty == true
                                  ? null
                                  : const Icon(Icons.school_outlined),
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.code}  •  ${item.teacher?.name ?? 'Teacher'}',
                            ),
                            trailing: item.active
                                ? const Icon(Icons.chevron_right)
                                : const Text('Archived'),
                            onTap: () => context.go(
                              '${AppRoutes.classrooms.path}/${item.id}',
                            ),
                          ),
                        ),
                      ),
                      if (loadingMore)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                    ],
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
