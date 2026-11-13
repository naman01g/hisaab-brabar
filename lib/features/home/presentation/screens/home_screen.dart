import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../widgets/quick_action_tile.dart';
import '../widgets/group_card.dart';
import '../widgets/transaction_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openNotifications(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  Widget _notificationButton(BuildContext context) {
    final repository = NotificationRepository();

    return StreamBuilder<int>(
      stream: repository.watchUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(42, 42),
          onPressed: () => _openNotifications(context),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  CupertinoIcons.bell,
                  color: AppColors.primary,
                  size: 25,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 3,
                    right: 4,
                    child: Container(
                      height: 9,
                      width: 9,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final rawName = user?.displayName?.trim() ?? '';
    final firstName = rawName.isEmpty
        ? 'there'
        : rawName.split(RegExp(r'\s+')).first;

    final displayName = firstName == 'there'
        ? firstName
        : '${firstName[0].toUpperCase()}${firstName.substring(1)}';

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,

      // Header: App name and notification bell only.
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Hisaab Brabar'),
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
        trailing: _notificationButton(context),
      ),

      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Personalized greeting.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $displayName 👋',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Here is your expense overview',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, AppColors.surface],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL NET BALANCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '₹4,250',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: AppColors.border,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'You are owed',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '+₹6,400',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.sageDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'You owe',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '-₹2,150',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: QuickActionTile(
                    title: 'Add Expense',
                    icon: CupertinoIcons.add,
                    iconBackground: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionTile(
                    title: 'Settle Up',
                    icon: CupertinoIcons.arrow_left_right,
                    iconBackground: AppColors.sage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionTile(
                    title: 'Invite',
                    icon: CupertinoIcons.person_2,
                    iconBackground: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionTile(
                    title: 'Discover',
                    icon: CupertinoIcons.search,
                    iconBackground: AppColors.sage,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Active Groups
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Active Groups',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            const GroupCard(
              groupName: 'Flat 402 Boys & Girls',
              members: '4 members',
              amount: '+₹1,200',
              status: 'You receive',
              icon: CupertinoIcons.house,
              iconBackground: AppColors.sage,
              amountColor: AppColors.sageDark,
            ),

            const SizedBox(height: 10),

            const GroupCard(
              groupName: 'Goa Summer Getaway',
              members: '6 members',
              amount: '-₹450',
              status: 'You owe',
              icon: CupertinoIcons.airplane,
              iconBackground: AppColors.secondary,
              amountColor: AppColors.primary,
            ),

            const SizedBox(height: 10),

            const GroupCard(
              groupName: 'College Fest SOS',
              members: '12 members',
              amount: 'Settled',
              status: 'All clear',
              icon: CupertinoIcons.person_3,
              iconBackground: AppColors.sage,
              amountColor: AppColors.sageDark,
            ),

            const SizedBox(height: 28),

            // Recent Transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            const TransactionTile(
              title: 'Groceries & Daily Staples',
              paidBy: 'Paid by you',
              amount: '+₹340',
              date: 'Today',
              icon: CupertinoIcons.cart,
              iconBackground: AppColors.sage,
              amountColor: AppColors.sageDark,
            ),

            const SizedBox(height: 10),

            const TransactionTile(
              title: 'Swiggy Biryani Feast',
              paidBy: 'Paid by Meera',
              amount: '-₹280',
              date: 'Yesterday',
              icon: CupertinoIcons.cart,
              iconBackground: AppColors.secondary,
              amountColor: AppColors.primary,
            ),

            const SizedBox(height: 10),

            const TransactionTile(
              title: 'Airport Uber Intercity',
              paidBy: 'Paid by you',
              amount: '+₹620',
              date: '2 days ago',
              icon: CupertinoIcons.car,
              iconBackground: AppColors.sage,
              amountColor: AppColors.sageDark,
            ),
          ],
        ),
      ),
    );
  }
}
