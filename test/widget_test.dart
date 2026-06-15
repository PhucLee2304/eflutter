import 'package:eflutter/data/models/user.dart';
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
      AppRoutes.profile,
      AppRoutes.other,
    ]);
    expect(NavigationItem.profileItem.title, 'Profile');
    expect(NavigationItem.profileItem.route.path, '/profile');
  });
}
