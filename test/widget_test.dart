import 'package:eflutter/data/models/user.dart';
import 'package:eflutter/data/models/topic_lesson_detail.dart';
import 'package:eflutter/presentation/app/navigation/app_routes.dart';
import 'package:eflutter/presentation/app/navigation/navigation_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses GetMe response with nullable avatar and default role', () {
    final user = User.fromJson({
      'id': 1,
      'email': 'user@example.com',
      'name': 'EFlutter User',
      'avatar': null,
    });

    expect(user.id, 1);
    expect(user.email, 'user@example.com');
    expect(user.name, 'EFlutter User');
    expect(user.avatar, isNull);
    expect(user.role, '');
  });

  test('profile is a dedicated navigation item', () {
    expect(NavigationItem.mobileShellBranches.map((item) => item.route), [
      AppRoutes.home,
      AppRoutes.topic,
      AppRoutes.profile,
      AppRoutes.other,
    ]);
    expect(NavigationItem.profileItem.title, 'Profile');
    expect(NavigationItem.profileItem.route.path, '/profile');
  });

  test('topic is a dedicated navigation item', () {
    expect(NavigationItem.topicItem.title, 'Topic');
    expect(NavigationItem.topicItem.route.path, '/topic');
  });

  test('parses lesson detail response with transcripts', () {
    final lesson = TopicLessonDetail.fromJson({
      'id': 9,
      'title': 'Lesson 01',
      'description': 'Lesson description',
      'subtitle': 'B2',
      'url': 'https://example.com',
      'sectionId': 3,
      'transcripts': [
        {
          'id': 1,
          'content': 'Hello world',
          'order': 1,
          'timeStart': 0,
          'timeEnd': 12.5,
          'url': 'https://example.com/clip',
          'lessonId': 9,
        },
      ],
    });

    expect(lesson.id, 9);
    expect(lesson.transcripts, hasLength(1));
    expect(lesson.transcripts.first.content, 'Hello world');
    expect(topicLessonPath(9), '/topic/lessons/9');
  });
}
