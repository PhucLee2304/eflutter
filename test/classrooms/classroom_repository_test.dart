import 'package:dio/dio.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/core/di/injection.dart';
import 'package:eflutter/data/models/classroom.dart';
import 'package:eflutter/data/repositories/classroom_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  setUpAll(() {
    if (!getIt.isRegistered<Talker>()) {
      getIt.registerSingleton<Talker>(Talker());
    }
  });

  test('list uses current user route, query, and pagination', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': [
                    {
                      'id': 3,
                      'code': 'ABC12345',
                      'name': 'Lop 12',
                      'active': true,
                    },
                  ],
                  'page': 2,
                  'pageCounts': 4,
                },
              ),
            );
          },
        ),
      );
    final result = await ClassroomRepository(
      dio,
    ).getMine(page: 2, query: 'Lop');
    expect(captured.path, '/classrooms/api/v1/classrooms/me');
    expect(captured.queryParameters['page'], 2);
    expect(captured.queryParameters['query'], 'Lop');
    expect(result.dataOrNull?.items.single.id, 3);
  });

  test('join and review use backend contract', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'id': 7,
                  'approved': null,
                  'user': {
                    'id': 'student-1',
                    'name': 'Student',
                    'email': 's@example.com',
                  },
                },
              ),
            );
          },
        ),
      );
    final repository = ClassroomRepository(dio);
    expect(await repository.join(' abc12345 '), isA<Success>());
    expect(requests.first.path, '/classrooms/api/v1/classrooms/join');
    expect((requests.first.data as Map)['code'], 'ABC12345');
    expect(await repository.review(5, 'student-1', true), isA<Success>());
    expect(
      requests.last.path,
      '/classrooms/api/v1/classrooms/5/members/student-1/approve',
    );
  });

  test('previews a classroom using the non-conflicting code route', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'id': 5,
                  'code': 'ABC12345',
                  'name': 'Class',
                  'active': true,
                },
              ),
            );
          },
        ),
      );

    final result = await ClassroomRepository(dio).preview(' abc12345 ');

    expect(captured.path, '/classrooms/api/v1/classrooms/code');
    expect(captured.queryParameters['code'], 'ABC12345');
    expect(result.dataOrNull?.id, 5);
  });

  test(
    'sends the full description and an empty value when clearing it',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'id': 1,
                    'code': 'ABC12345',
                    'name': 'Class',
                    'active': true,
                  },
                ),
              );
            },
          ),
        );
      final repository = ClassroomRepository(dio);
      final longDescription = 'A long description. ' * 1000;
      expect(
        await repository.create('Class', description: longDescription),
        isA<Success>(),
      );
      expect(
        (requests.last.data as Map)['description'],
        longDescription.trim(),
      );

      expect(
        await repository.update(1, name: 'Class', description: ''),
        isA<Success>(),
      );
      expect((requests.last.data as Map).containsKey('description'), isTrue);
      expect((requests.last.data as Map)['description'], '');
    },
  );

  test('gets assignments using the classroom route', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': [
                    {
                      'id': 3,
                      'classroomId': 5,
                      'title': 'Assignment',
                      'examId': 8,
                      'opensAt': '2026-10-04T01:00:00Z',
                      'dueAt': '2026-10-05T01:00:00Z',
                    },
                  ],
                  'pageCounts': 2,
                },
              ),
            );
          },
        ),
      );

    final result = await ClassroomRepository(
      dio,
    ).getAssignments(5, page: 2, pageSize: 10);

    expect(captured.path, '/classrooms/api/v1/classrooms/5/assignments');
    expect(captured.queryParameters, {'page': 2, 'pageSize': 10});
    expect(result.dataOrNull?.items.single.examId, 8);
  });

  test('creates an exam and assignments with the backend contract', () async {
    late RequestOptions captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'assignments': [
                    {
                      'id': 3,
                      'classroomId': 5,
                      'title': 'Assignment',
                      'examId': 8,
                      'opensAt': '2026-10-04T01:00:00Z',
                      'dueAt': '2026-10-05T01:00:00Z',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
    final opensAt = DateTime.parse('2026-10-04T08:00:00+07:00');
    final dueAt = DateTime.parse('2026-10-05T08:00:00+07:00');

    final result = await ClassroomRepository(dio).createAssignments(
      schedules: [
        AssignmentScheduleInput(
          classroomId: 5,
          duration: 45,
          opensAt: opensAt,
          dueAt: dueAt,
        ),
        AssignmentScheduleInput(
          classroomId: 6,
          duration: 45,
          opensAt: opensAt,
          dueAt: dueAt,
        ),
      ],
      title: ' Assignment ',
      description: ' Instructions ',
      questions: const [
        CreateAssignmentQuestion(
          content: '2 + 2 = ?',
          explanation: 'Basic addition',
          options: ['1', '2', '3', '4'],
          correctOptionIndex: 3,
        ),
      ],
    );

    final body = captured.data as Map<String, dynamic>;
    expect(captured.path, '/classrooms/api/v1/classrooms/assignments');
    expect(body['schedules'], hasLength(2));
    expect((body['schedules'] as List).first['classroomId'], 5);
    expect(body['title'], 'Assignment');
    expect(body['description'], 'Instructions');
    final questions = body['questions'] as List<dynamic>;
    expect(questions, hasLength(1));
    expect((questions.single as Map<String, dynamic>)['options'], [
      '1',
      '2',
      '3',
      '4',
    ]);
    expect(questions.single['correctOptionIndex'], 3);
    expect((body['schedules'] as List).first['duration'], 45);
    expect(body.containsKey('exam'), isFalse);
    expect(body.containsKey('examId'), isFalse);
    expect(
      (body['schedules'] as List).first['opensAt'],
      '2026-10-04T01:00:00.000Z',
    );
    expect(result.dataOrNull?.assignments.single.classroomId, 5);
  });

  test(
    'updates assignment content with confirmation and score exclusion',
    () async {
      late RequestOptions captured;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              captured = options;
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'id': 3,
                    'examId': 8,
                    'title': 'Updated',
                    'questions': [
                      {
                        'content': 'Question',
                        'options': ['A', 'B', 'C', 'D'],
                        'correctOptionIndex': 1,
                        'excludedFromScore': true,
                      },
                    ],
                  },
                ),
              );
            },
          ),
        );
      final result = await ClassroomRepository(dio).updateAssignmentContent(
        classroomId: 5,
        assignmentId: 3,
        title: ' Updated ',
        description: ' Description ',
        confirm: true,
        reason: 'Incorrect answer',
        questions: const [
          CreateAssignmentQuestion(
            content: 'Question',
            explanation: '',
            options: ['A', 'B', 'C', 'D'],
            correctOptionIndex: 1,
            excludedFromScore: true,
          ),
        ],
      );
      final body = captured.data as Map<String, dynamic>;
      expect(captured.path, '/classrooms/api/v1/classrooms/5/assignments/3');
      expect(body['confirm'], isTrue);
      expect((body['questions'] as List).single['excludedFromScore'], isTrue);
      expect(result.dataOrNull?.questions.single.excludedFromScore, isTrue);
    },
  );
}
