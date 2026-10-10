import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ClassGradebookScreen extends StatefulWidget {
  const ClassGradebookScreen({super.key, required this.classroomId});
  final int classroomId;
  @override
  State<ClassGradebookScreen> createState() => _ClassGradebookScreenState();
}

class _ClassGradebookScreenState extends State<ClassGradebookScreen> {
  late final repository = ClassroomRepository(getIt<Dio>());
  ClassGradebook? gradebook;
  String? error;
  DateTimeRange? range;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final result = await repository.getClassGradebook(
      widget.classroomId,
      from: range?.start,
      to: range?.end.add(const Duration(days: 1)),
    );
    if (!mounted) return;
    switch (result) {
      case Success(data: final data):
        setState(() {
          gradebook = data;
          error = null;
        });
      case Failure(message: final message):
        setState(() => error = message ?? 'Could not load the class gradebook');
      case Cancelled():
        break;
    }
  }

  Future<void> selectRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: range,
    );
    if (selected == null) return;
    setState(() => range = selected);
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Class gradebook'),
      actions: [
        IconButton(
          tooltip: 'Filter by due date',
          onPressed: selectRange,
          icon: const Icon(Icons.date_range_outlined),
        ),
        if (range != null)
          IconButton(
            tooltip: 'Clear date filter',
            onPressed: () {
              setState(() => range = null);
              load();
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
      ],
    ),
    body: gradebook == null
        ? Center(
            child: error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!),
                      TextButton(onPressed: load, child: const Text('Retry')),
                    ],
                  ),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Average score: ${gradebook!.averageScore?.toStringAsFixed(2) ?? '-'}',
                    ),
                    Text(
                      'Completion: ${gradebook!.completionRate.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Student')),
                      const DataColumn(label: Text('Average')),
                      ...gradebook!.assignments.map(
                        (item) => DataColumn(
                          label: SizedBox(
                            width: 120,
                            child: Text(
                              item['title'] as String? ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                    rows: gradebook!.students
                        .map(
                          (student) => DataRow(
                            onSelectChanged: (_) => context.go(
                              studentProgressPath(
                                widget.classroomId,
                                student.student.id,
                              ),
                            ),
                            cells: [
                              DataCell(Text(student.student.name)),
                              DataCell(
                                Text(
                                  student.averageScore?.toStringAsFixed(2) ??
                                      '-',
                                ),
                              ),
                              ...student.assignments.map(
                                (item) => DataCell(
                                  Text(
                                    item.score?.toStringAsFixed(2) ??
                                        item.status.replaceAll('_', ' '),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
  );
}
