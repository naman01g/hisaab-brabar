import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/group_list_card.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,

      navigationBar: CupertinoNavigationBar(
        middle: const Text('Your Groups'),
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {},
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
                    onPressed: () {},
                    child: const Text('Create'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Search Field
            CupertinoSearchTextField(
              placeholder: 'Search groups...',
              backgroundColor: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.all(12),
            ),

            const SizedBox(height: 18),

            // Category Filters
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryChip(title: 'All', selected: true),
                  _CategoryChip(title: 'Flatmates'),
                  _CategoryChip(title: 'Trips'),
                  _CategoryChip(title: 'College'),
                  _CategoryChip(title: 'Clubs'),
                ],
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

            // Groups Heading
            const Text(
              'All Groups',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 14),

            // Group 1
            const GroupListCard(
              name: 'Flat 304 - Indiranagar',
              category: 'Flatmates',
              members: '4 members',
              activity: 'Electricity bill paid by Aarav',
              amount: '+₹1,850',
              status: 'You receive',
              icon: CupertinoIcons.house,
              amountColor: AppColors.sageDark,
              iconBackground: AppColors.sage,
            ),

            const SizedBox(height: 12),

            // Group 2
            const GroupListCard(
              name: 'Manali Trek Dec',
              category: 'Trip',
              members: '8 members',
              activity: 'Tempo traveller rental booked',
              amount: '-₹620',
              status: 'You owe',
              icon: CupertinoIcons.airplane,
              amountColor: AppColors.primary,
              iconBackground: AppColors.secondary,
            ),

            const SizedBox(height: 12),

            // Group 3
            const GroupListCard(
              name: 'CSE Dept Core Team',
              category: 'College',
              members: '15 members',
              activity: 'Hackathon posters printed',
              amount: 'Settled',
              status: 'All clear',
              icon: CupertinoIcons.person_3,
              amountColor: AppColors.sageDark,
              iconBackground: AppColors.sage,
            ),

            const SizedBox(height: 12),

            // Group 4
            const GroupListCard(
              name: 'Hostel Wing B Mess',
              category: 'Hostel',
              members: '6 members',
              activity: 'Late night Maggi pantry run',
              amount: '+₹420',
              status: 'You receive',
              icon: CupertinoIcons.house_fill,
              amountColor: AppColors.sageDark,
              iconBackground: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

// Category Filter Widget
class _CategoryChip extends StatelessWidget {
  final String title;
  final bool selected;

  const _CategoryChip({required this.title, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
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
    );
  }
}
