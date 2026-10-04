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
}
