import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/group_repository.dart';
import '../../domain/models/group.dart';
import '../widgets/group_list_card.dart';
import 'create_group_screen.dart';
import 'group_details_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final repository = GroupRepository();

  final categories = [
    'All',
    'Flatmates',
    'Trips',
    'College',
    'Hostel',
    'Other',
  ];

  String selectedCategory = 'All';
  String searchQuery = '';

  late final Stream<List<Group>> groupsStream;

  @override
  void initState() {
    super.initState();
    groupsStream = repository.watchMyGroups();
  }

  Future<void> _openCreateGroup() async {
    await Navigator.push<bool>(
      context,
      CupertinoPageRoute(builder: (context) => const CreateGroupScreen()),
    );
    // Firestore stream automatically updates the list.
  }

  void _openGroupDetails(Group group) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => GroupDetailsScreen(group: group),
      ),
    );
  }

  List<Group> _filterGroups(List<Group> groups) {
    return groups.where((group) {
      final matchesCategory =
          selectedCategory == 'All' || group.category == selectedCategory;

      final matchesSearch = group.name.toLowerCase().contains(
        searchQuery.trim().toLowerCase(),
      );

      return matchesCategory && matchesSearch;
    }).toList();
  }

  IconData _groupIcon(String category) {
    switch (category) {
      case 'Flatmates':
        return CupertinoIcons.house;
      case 'Trips':
        return CupertinoIcons.airplane;
      case 'College':
        return CupertinoIcons.person_3;
      case 'Hostel':
        return CupertinoIcons.house_fill;
      default:
        return CupertinoIcons.person_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Your Groups'),
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _openCreateGroup,
          child: const Icon(CupertinoIcons.add, color: AppColors.primary),
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<List<Group>>(
          stream: groupsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Unable to load your groups.',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final allGroups = snapshot.data ?? <Group>[];
            final visibleGroups = _filterGroups(allGroups);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Create Group Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.person_2,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start a new split',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Create a group with friends',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _openCreateGroup,
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Search
                CupertinoSearchTextField(
                  placeholder: 'Search groups...',
                  backgroundColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.all(12),
                  onChanged: (value) {
                    setState(() => searchQuery = value);
                  },
                ),

                const SizedBox(height: 18),

                // Categories
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryChip(
                          title: category,
                          selected: selectedCategory == category,
                          onTap: () {
                            setState(() {
                              selectedCategory = category;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // Live balance placeholder
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GROUP BALANCES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sageDark,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Balances will appear after you add expenses.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.sageDark,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  selectedCategory == 'All' ? 'All Groups' : selectedCategory,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 14),

                if (visibleGroups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          CupertinoIcons.person_2,
                          size: 30,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          allGroups.isEmpty
                              ? 'No groups yet'
                              : 'No groups found',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          allGroups.isEmpty
                              ? 'Create your first group to get started.'
                              : 'Try another name or category.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...visibleGroups.map((group) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GroupListCard(
                        group: group,
                        activity: 'Group created',
                        amount: '—',
                        status: 'No expenses',
                        icon: _groupIcon(group.category),
                        amountColor: AppColors.textSecondary,
                        iconBackground: AppColors.secondary,
                        onTap: () => _openGroupDetails(group),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.title,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryLight : AppColors.border,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
