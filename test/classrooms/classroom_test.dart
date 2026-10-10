import 'package:eflutter/data/models/classroom.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses classroom with approved members and nullable user fields', () {
    final classroom = Classroom.fromJson({
      'id': 4,
      'code': 'ABC12345',
      'name': 'Toan 12',
      'active': true,
      'teacher': {
        'id': '12',
        'name': 'Teacher',
        'email': 't@example.com',
        'avatar': '',
      },
      'members': [
        {
          'id': 8,
          'approved': true,
          'user': {
            'id': '34',
            'name': 'Student',
            'email': 's@example.com',
            'avatar': '',
          },
        },
      ],
    });
    expect(classroom.teacher?.id, '12');
    expect(classroom.members.single.user?.name, 'Student');
    expect(classroom.members.single.approved, true);
  });

  test('parses preview and paginated list', () {
    final preview = Classroom.fromJson({
      'id': 4,
      'code': 'ABC12345',
      'name': 'Toan 12',
      'active': true,
      'countApprovedMembers': 16,
    });
    final page = ClassroomPage.fromJson({
      'data': [
        {'id': 4, 'code': 'ABC12345', 'name': 'Toan 12', 'active': true},
      ],
      'page': 1,
      'pageCounts': 2,
    });
    expect(preview.countApprovedMembers, 16);
    expect(preview.members, isEmpty);
    expect(page.items.single.id, 4);
    expect(page.pageCounts, 2);
  });

  test('pending join request keeps approved null', () {
    final member = ClassroomMember.fromJson({
      'id': 9,
      'approved': null,
      'user': {'id': '34', 'name': 'Student', 'email': 's@example.com'},
    });
    expect(member.approved, isNull);
    expect(member.user?.id, '34');
  });

  test('parses assignment and student submission state', () {
    final assignment = ClassroomAssignment.fromJson({
      'id': 21,
      'classroomId': 4,
      'title': 'Listening test',
      'description': 'Unit 1',
      'examId': 15,
      'opensAt': '2026-10-04T01:00:00Z',
      'dueAt': '2026-10-05T01:00:00Z',
      'submission': {
        'id': 7,
        'assignmentId': 21,
        'attemptId': 19,
        'status': 'IN_PROGRESS',
      },
    });

    expect(assignment.examId, 15);
    expect(assignment.submission?.attemptId, 19);
    expect(assignment.submission?.status, 'IN_PROGRESS');
  });

  test('parses assignment gradebook submissions', () {
    final assignment = ClassroomAssignment.fromJson({
      'id': 21,
      'classroomId': 4,
      'title': 'Listening test',
      'examId': 15,
      'opensAt': '2026-10-04T01:00:00Z',
      'dueAt': '2026-10-05T01:00:00Z',
      'submissions': [
        {
          'id': 7,
          'assignmentId': 21,
          'attemptId': 19,
          'status': 'SUBMITTED',
          'score': 8.5,
          'student': {
            'id': 'student-1',
            'name': 'Student',
            'email': 'student@example.com',
          },
        },
      ],
    });

    expect(assignment.submissions.single.student?.id, 'student-1');
    expect(assignment.submissions.single.score, 8.5);
  });
}
