import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/groups/presentation/screens/groups_screen.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';
import '../../features/people/presentation/screens/people_discovery_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/groups/presentation/screens/join_group_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final AppLinks _appLinks = AppLinks();
  late final CupertinoTabController _tabController;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = CupertinoTabController(initialIndex: 0);

    _linkSubscription = _appLinks.uriLinkStream.listen(_handleLink);

    _appLinks
        .getInitialLink()
        .then((uri) {
          if (uri != null) _handleLink(uri);
        })
        .catchError((_) {});
  }

  void _handleLink(Uri uri) {
    if (uri.scheme != 'hisaabbrabar' || uri.host != 'join') {
      return;
    }

    final groupId = uri.queryParameters['groupId'];
    final invitationId = uri.queryParameters['inviteId'];

    if (groupId == null ||
        groupId.isEmpty ||
        invitationId == null ||
        invitationId.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) =>
              JoinGroupScreen(groupId: groupId, invitationId: invitationId),
        ),
      );
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabController,
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
            icon: Icon(CupertinoIcons.person_2),
            label: 'People',
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
                return HomeScreen(
                  onSelectTab: (tabIndex) => _tabController.index = tabIndex,
                );
              case 1:
                return const GroupsScreen();
              case 2:
                return const AddExpenseScreen();
              case 3:
                return const PeopleDiscoveryScreen();
              case 4:
                return const ProfileScreen();
              default:
                return HomeScreen(
                  onSelectTab: (tabIndex) => _tabController.index = tabIndex,
                );
            }
          },
        );
      },
    );
  }
}
