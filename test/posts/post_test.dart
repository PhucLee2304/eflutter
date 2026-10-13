import 'package:eflutter/data/models/post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses post permissions, counts and author', () {
    final post = PostItem.fromJson({
      'id': 4,
      'authorId': '1',
      'author': {'id': '1', 'name': 'Teacher', 'email': 'teacher@example.com'},
      'scope': 'CLASSROOM',
      'classroomId': 2,
      'content': 'Welcome',
      'status': 'PUBLISHED',
      'pinned': true,
      'allowComments': true,
      'likeCount': 3,
      'commentCount': 2,
      'liked': true,
      'canEdit': true,
      'canDelete': true,
      'canPin': true,
      'createdAt': '2026-10-12T08:00:00Z',
    });

    expect(post.author?.name, 'Teacher');
    expect(post.classroomId, 2);
    expect(post.pinned, isTrue);
    expect(post.liked, isTrue);
    expect(post.likeCount, 3);
    expect(post.canPin, isTrue);
  });

  test('parses flat reply target', () {
    final comment = PostCommentItem.fromJson({
      'id': 8,
      'postId': 4,
      'userId': '3',
      'content': 'Reply',
      'parentId': 5,
      'replyToUserId': '2',
      'replyToUser': {'id': '2', 'name': 'Student', 'email': 's@example.com'},
      'likeCount': 1,
      'liked': false,
      'canEdit': true,
      'canDelete': true,
      'createdAt': '2026-10-12T08:10:00Z',
    });

    expect(comment.parentId, 5);
    expect(comment.replyToUser?.name, 'Student');
  });
}
