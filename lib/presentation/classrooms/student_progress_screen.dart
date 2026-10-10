import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:flutter/material.dart';

class StudentProgressScreen extends StatefulWidget {
  const StudentProgressScreen({
    super.key,
    required this.classroomId,
    required this.studentId,
  });
  final int classroomId;
  final String studentId;
  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  late final repository = ClassroomRepository(getIt<Dio>());
  StudentProgress? progress;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final result = await repository.getStudentProgress(
      widget.classroomId,
      widget.studentId,
    );
    if (!mounted) return;
    switch (result) {
      case Success(data: final data):
        setState(() {
          progress = data;
          error = null;
        });
      case Failure(message: final message):
        setState(() => error = message ?? 'Could not load student progress');
      case Cancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(progress?.student.name ?? 'Student progress')),
    body: progress == null
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
                Text(progress!.student.email),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  children: [
                    Text(
                      'Average: ${progress!.averageScore?.toStringAsFixed(2) ?? '-'}',
                    ),
                    Text(
                      'Completion: ${progress!.completionRate.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
                const Divider(height: 32),
                ...progress!.assignments.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.status.replaceAll('_', ' ')}  |  Due ${item.dueAt}',
                    ),
                    trailing: Text(item.score?.toStringAsFixed(2) ?? '-'),
                  ),
                ),
              ],
            ),
          ),
  );
}
