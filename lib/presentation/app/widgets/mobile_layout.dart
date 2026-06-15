import 'package:eflutter/presentation/app/navigation/navigation_item.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MobileLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MobileLayout({super.key, required this.navigationShell});

  void _onTabTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: AppNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTabTapped: _onTabTapped,
      ),
    );
  }
}

class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
  });
  final int currentIndex;
  final ValueChanged<int> onTabTapped;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTabTapped,
      destinations: NavigationItem.mobileShellBranches.map((item) {
        return NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.selectedIcon),
          label: item.title,
        );
      }).toList(),
    );
  }
}
