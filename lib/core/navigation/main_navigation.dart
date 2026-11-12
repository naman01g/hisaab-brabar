import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/groups/presentation/screens/groups_screen.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: AppColors.primary,
        inactiveColor: AppColors.textSecondary,
        backgroundColor: AppColors.background.withValues(alpha: 0.95),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.group),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.add_circled_solid, size: 28),
            label: 'Add',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.time),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            label: 'Profile',
          ),
        ],
      ),

      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0:
                return const HomeScreen();
              case 1:
                return const GroupsScreen();
              case 2:
                return const AddExpenseScreen();
              case 3:
                return const _PlaceholderTab(title: 'Activity');
              default:
                return const _PlaceholderTab(title: 'Profile');
            }
          },
        );
      },
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String title;

  const _PlaceholderTab({required this.title});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(title)),
      child: Center(
        child: Text(
          '$title — Coming Soon',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}
