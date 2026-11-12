import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';
import '../widgets/group_list_card.dart';
import 'create_group_screen.dart';
import 'group_details_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final List<String> categories = [
    'All',
    'Flatmates',
    'Trips',
    'College',
    'Hostel',
    'Other',
  ];

  String selectedCategory = 'All';
  String searchQuery = '';

  late final List<_GroupEntry> groups;

  @override
  void initState() {
    super.initState();

    groups = [
      _GroupEntry(
        group: _buildSampleGroup(
          id: 'flat_304',
          name: 'Flat 304 - Indiranagar',
          category: 'Flatmates',
          memberCount: 4,
        ),
        activity: 'Electricity bill paid by Aarav',
        amount: '+₹1,850',
        status: 'You receive',
        icon: CupertinoIcons.house,
        amountColor: AppColors.sageDark,
        iconBackground: AppColors.sage,
      ),
      _GroupEntry(
        group: _buildSampleGroup(
          id: 'manali_trek',
          name: 'Manali Trek Dec',
          category: 'Trips',
          memberCount: 8,
        ),
        activity: 'Tempo traveller rental booked',
        amount: '-₹620',
        status: 'You owe',
        icon: CupertinoIcons.airplane,
        amountColor: AppColors.primary,
        iconBackground: AppColors.secondary,
      ),
      _GroupEntry(
        group: _buildSampleGroup(
          id: 'cse_team',
          name: 'CSE Dept Core Team',
          category: 'College',
          memberCount: 15,
        ),
        activity: 'Hackathon posters printed',
        amount: 'Settled',
        status: 'All clear',
        icon: CupertinoIcons.person_3,
        amountColor: AppColors.sageDark,
        iconBackground: AppColors.sage,
      ),
      _GroupEntry(
        group: _buildSampleGroup(
          id: 'hostel_wing_b',
          name: 'Hostel Wing B Mess',
          category: 'Hostel',
          memberCount: 6,
        ),
        activity: 'Late night Maggi pantry run',
        amount: '+₹420',
        status: 'You receive',
        icon: CupertinoIcons.house_fill,
        amountColor: AppColors.sageDark,
        iconBackground: AppColors.secondary,
      ),
    ];
  }

  // Create sample group data.
  Group _buildSampleGroup({
    required String id,
    required String name,
    required String category,
    required int memberCount,
  }) {
    final names = ['You', 'Aarav', 'Meera', 'Kabir'];

    final members = List.generate(memberCount, (index) {
      return GroupMember(
        userId: '${id}_user_$index',
        displayName: index < names.length
            ? names[index]
            : 'Member ${index + 1}',
        role: index == 0 ? GroupRole.owner : GroupRole.member,
      );
    });

    return Group(
      id: id,
      name: name,
      category: category,
      createdBy: members.first.userId,
      createdAt: DateTime.now(),
      members: members,
    );
  }

  // Open group details.
  Future<void> _openGroupDetails(_GroupEntry entry) async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute(
        builder: (context) => GroupDetailsScreen(
          group: entry.group,
          onGroupUpdated: _updateGroup,
        ),
      ),
    );
  }

  // Update the group in the parent screen.
  void _updateGroup(Group updatedGroup) {
    final index = groups.indexWhere(
      (entry) => entry.group.id == updatedGroup.id,
    );

    if (index == -1) return;

    setState(() {
      groups[index] = groups[index].copyWith(group: updatedGroup);
    });
  }

  // Create a new group.
  Future<void> _openCreateGroup() async {
    final newGroup = await Navigator.push<Group>(
      context,
      CupertinoPageRoute(builder: (context) => const CreateGroupScreen()),
    );

    if (!mounted || newGroup == null) return;

    setState(() {
      groups.insert(
        0,
        _GroupEntry(
          group: newGroup,
          activity: 'Created just now',
          amount: '—',
          status: 'No expenses',
          icon: CupertinoIcons.person_2,
          amountColor: AppColors.textSecondary,
          iconBackground: AppColors.secondary,
        ),
      );

      selectedCategory = 'All';
      searchQuery = '';
    });
  }

  // Search and category filtering.
  List<_GroupEntry> get filteredGroups {
    return groups.where((entry) {
      final matchesCategory =
          selectedCategory == 'All' || entry.group.category == selectedCategory;

      final matchesSearch = entry.group.name.toLowerCase().contains(
        searchQuery.trim().toLowerCase(),
      );

      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleGroups = filteredGroups;

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
        child: ListView(
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

            // Overall Balance
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NET BALANCE ACROSS GROUPS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sageDark,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'You are owed overall',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.sageDark,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹6,400',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
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

            // Group Cards
            if (visibleGroups.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      size: 30,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No groups found',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Try another name or category.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...visibleGroups.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GroupListCard(
                    group: entry.group,
                    activity: entry.activity,
                    amount: entry.amount,
                    status: entry.status,
                    icon: entry.icon,
                    amountColor: entry.amountColor,
                    iconBackground: entry.iconBackground,
                    onTap: () => _openGroupDetails(entry),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// Display information for each group card.
class _GroupEntry {
  final Group group;
  final String activity;
  final String amount;
  final String status;
  final IconData icon;
  final Color amountColor;
  final Color iconBackground;

  const _GroupEntry({
    required this.group,
    required this.activity,
    required this.amount,
    required this.status,
    required this.icon,
    required this.amountColor,
    required this.iconBackground,
  });

  _GroupEntry copyWith({Group? group}) {
    return _GroupEntry(
      group: group ?? this.group,
      activity: activity,
      amount: amount,
      status: status,
      icon: icon,
      amountColor: amountColor,
      iconBackground: iconBackground,
    );
  }
}

// Category Filter Widget
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
