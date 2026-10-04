import 'dart:async';

import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/presentation/app/cubit/app_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class ClassroomDetailScreen extends StatefulWidget {
  const ClassroomDetailScreen({super.key, required this.classroomId});
  final int classroomId;
  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  late final ClassroomRepository repository = ClassroomRepository(getIt<Dio>());
  Classroom? classroom;
  List<ClassroomMember> requests = [];
  bool loading = true;
  bool busy = false;
  String? error;
  int tab = 0;
  StreamSubscription<AppState>? userSubscription;

  bool get isTeacher =>
      classroom?.teacher?.id ==
      context.read<AppCubit>().state.user?.id.toString();

  @override
  void initState() {
    super.initState();
    userSubscription = context.read<AppCubit>().stream.listen((state) {
      if (classroom?.active == true &&
          classroom?.teacher?.id == state.user?.id.toString()) {
        loadRequests();
      }
    });
    load();
  }

  @override
  void dispose() {
    userSubscription?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final result = await repository.get(widget.classroomId);
    if (!mounted) return;
    switch (result) {
      case Success(data: final item):
        setState(() {
          classroom = item;
          loading = false;
        });
        if (isTeacher && item.active) await loadRequests();
      case Failure(message: final message):
        setState(() {
          error = message;
          loading = false;
        });
      case Cancelled():
        setState(() => loading = false);
    }
  }

  Future<void> loadRequests() async {
    final result = await repository.joinRequests(widget.classroomId);
    if (!mounted) return;
    switch (result) {
      case Success(data: final items):
        setState(() => requests = items);
      case Failure(message: final message):
        showMessage(message ?? 'Could not load join requests');
      case Cancelled():
        break;
    }
  }

  Future<void> edit() async {
    final current = classroom!;
    var name = current.name;
    var description = current.description ?? '';
    final form = GlobalKey<FormState>();
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Edit classroom'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  onChanged: (value) => name = value,
                  decoration: const InputDecoration(
                    labelText: 'Classroom name',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a classroom name'
                      : null,
                ),
                TextFormField(
                  initialValue: description,
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (values == null || !mounted) return;
    setState(() => busy = true);
    final result = await repository.update(
      current.id,
      name: values.$1,
      description: values.$2,
    );
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await load();
      case Failure(message: final message):
        showMessage(message ?? 'Could not update the classroom');
      case Cancelled():
        break;
    }
  }

  Future<void> archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive classroom?'),
        content: const Text(
          'The classroom will no longer accept join requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    final result = await repository.archive(widget.classroomId);
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await load();
      case Failure(message: final message):
        showMessage(message ?? 'Could not archive the classroom');
      case Cancelled():
        break;
    }
  }

  Future<void> review(ClassroomMember member, bool approve) async {
    final userId = member.user?.id;
    if (userId == null) return;
    setState(() => busy = true);
    final result = await repository.review(widget.classroomId, userId, approve);
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await load();
      case Failure(message: final message):
        showMessage(message ?? 'Could not process the request');
      case Cancelled():
        break;
    }
  }

  Future<void> remove(ClassroomMember member) async {
    final userId = member.user?.id;
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text(member.user?.name ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    final result = await repository.remove(widget.classroomId, userId);
    if (!mounted) return;
    setState(() => busy = false);
    switch (result) {
      case Success():
        await load();
      case Failure(message: final message):
        showMessage(message ?? 'Could not remove the student');
      case Cancelled():
        break;
    }
  }

  void showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    context.watch<AppCubit>();
    final item = classroom;
    return Scaffold(
      appBar: AppBar(
        title: Text(item?.name ?? 'Classroom'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/classrooms'),
        ),
        actions: [
          if (item != null && isTeacher && item.active) ...[
            IconButton(
              tooltip: 'Edit classroom',
              icon: const Icon(Icons.edit_outlined),
              onPressed: busy ? null : edit,
            ),
            IconButton(
              tooltip: 'Archive classroom',
              icon: const Icon(Icons.archive_outlined),
              onPressed: busy ? null : archive,
            ),
          ],
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  TextButton(onPressed: load, child: const Text('Retry')),
                ],
              ),
            )
          : item == null
          ? const Center(child: Text('Classroom not found'))
          : Column(
              children: [
                if (busy) const LinearProgressIndicator(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      children: [
                        ClassroomOverviewHeader(classroom: item),
                        Center(
                          child: TabsBar(
                            selected: tab,
                            onSelected: (value) => setState(() => tab = value),
                          ),
                        ),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 940),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 20,
                              ),
                              child: switch (tab) {
                                0 => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Teacher',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.person_outline),
                                      title: Text(
                                        item.teacher?.name ??
                                            'Information unavailable',
                                      ),
                                      subtitle: Text(item.teacher?.email ?? ''),
                                    ),
                                  ],
                                ),
                                1 => const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: Text('No assignments yet'),
                                  ),
                                ),
                                _ => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Teacher',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    ListTile(
                                      title: Text(
                                        item.teacher?.name ??
                                            'Information unavailable',
                                      ),
                                      subtitle: Text(item.teacher?.email ?? ''),
                                    ),
                                    const Divider(),
                                    Text(
                                      'Students (${item.members.length})',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    ...item.members.map(
                                      (member) => ListTile(
                                        title: Text(
                                          member.user?.name ??
                                              'User no longer available',
                                        ),
                                        subtitle: Text(
                                          member.user?.email ?? '',
                                        ),
                                        trailing: isTeacher && item.active
                                            ? IconButton(
                                                tooltip:
                                                    'Remove from classroom',
                                                onPressed: busy
                                                    ? null
                                                    : () => remove(member),
                                                icon: const Icon(
                                                  Icons.person_remove_outlined,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    if (isTeacher && item.active) ...[
                                      const Divider(),
                                      Text(
                                        'Pending requests (${requests.length})',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      ...requests.map(
                                        (member) => ListTile(
                                          title: Text(
                                            member.user?.name ?? 'Student',
                                          ),
                                          subtitle: Text(
                                            member.user?.email ?? '',
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Reject',
                                                onPressed: busy
                                                    ? null
                                                    : () =>
                                                          review(member, false),
                                                icon: const Icon(Icons.close),
                                              ),
                                              IconButton(
                                                tooltip: 'Approve',
                                                onPressed: busy
                                                    ? null
                                                    : () =>
                                                          review(member, true),
                                                icon: const Icon(Icons.check),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              },
                            ),
                          ),
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

class ClassroomOverviewHeader extends StatefulWidget {
  const ClassroomOverviewHeader({super.key, required this.classroom});

  final Classroom classroom;

  @override
  State<ClassroomOverviewHeader> createState() =>
      _ClassroomOverviewHeaderState();
}

class _ClassroomOverviewHeaderState extends State<ClassroomOverviewHeader> {
  Timer? _copyResetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = widget.classroom.description?.trim();
    final avatar = widget.classroom.avatar;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE4E9EC))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFE3F1EF),
                      backgroundImage: avatar != null && avatar.isNotEmpty
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar == null || avatar.isEmpty
                          ? const Icon(
                              Icons.school_outlined,
                              color: Color(0xFF1D6A63),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.classroom.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.classroom.teacher?.name ??
                                'Teacher unavailable',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.classroom.active) ...[
                      const SizedBox(width: 8),
                      const Tooltip(
                        message: 'Archived classroom',
                        child: Icon(
                          Icons.archive_outlined,
                          color: Color(0xFF8A625B),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Class code',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SelectableText(
                      widget.classroom.code,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      tooltip: _copied ? 'Copied' : 'Copy class code',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _copied ? Icons.check : Icons.copy_outlined,
                        size: 18,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.classroom.code),
                        );
                        if (!mounted) return;
                        _copyResetTimer?.cancel();
                        setState(() => _copied = true);
                        _copyResetTimer = Timer(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _copied = false);
                        });
                      },
                    ),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TabsBar extends StatelessWidget {
  const TabsBar({super.key, required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('Stream')),
        ButtonSegment(value: 1, label: Text('Classwork')),
        ButtonSegment(value: 2, label: Text('People')),
      ],
      selected: {selected},
      onSelectionChanged: (v) => onSelected(v.first),
    ),
  );
}
