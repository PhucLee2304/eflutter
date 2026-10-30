import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:eflutter/presentation/classrooms/gradebook_widgets.dart';
import 'package:flutter/material.dart';

class StudentProgressScreen extends StatefulWidget {
  const StudentProgressScreen({
    super.key,
    required this.classroomId,
    required this.studentId,
    this.onBack,
  });
  final int classroomId;
  final String studentId;

  /// Mở trong tab Classwork: thanh Back thay AppBar, không tự cuộn.
  final VoidCallback? onBack;
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
    final result = await repository.getStudentProgress(widget.classroomId, widget.studentId);
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
  Widget build(BuildContext context) {
    final onBack = widget.onBack;
    if (onBack == null) return _scaffold();
    final data = progress;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          GbHeader(onBack: onBack),
          if (data != null)
            GbCard(
              children: [
                Text(
                  data.student.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                Text(data.student.email, style: const TextStyle(color: Gb.muted)),
                const SizedBox(height: 12),
                Text(
                  'Average: ${Gb.scoreText(data.averageScore)} · '
                  'Completion: ${data.completionRate.toStringAsFixed(0)}%',
                ),
                const Divider(height: 32),
                for (final item in data.assignments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: Text(Gb.statusLabel(item.status)),
                    trailing: Text(Gb.scoreText(item.score)),
                  ),
              ],
            )
          else if (error != null)
            GbError(message: error!, onRetry: load)
          else
            const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: AppLoader()),
        ],
      ),
    );
  }

  Widget _scaffold() => Scaffold(
    appBar: AppBar(title: Text(progress?.student.name ?? 'Student progress')),
    body: progress == null
        ? Center(
            child: error == null
                ? const AppLoader()
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
                    Text('Average: ${progress!.averageScore?.toStringAsFixed(2) ?? '-'}'),
                    Text('Completion: ${progress!.completionRate.toStringAsFixed(1)}%'),
                  ],
                ),
                const Divider(height: 32),
                ...progress!.assignments.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: Text('${item.status.replaceAll('_', ' ')}  |  Due ${item.dueAt}'),
                    trailing: Text(item.score?.toStringAsFixed(2) ?? '-'),
                  ),
                ),
              ],
            ),
          ),
  );
}
