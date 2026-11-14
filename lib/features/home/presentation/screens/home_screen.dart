import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../expenses/data/repositories/expense_repository.dart';
import '../../../expenses/data/repositories/group_settlement_repository.dart';
import '../../../expenses/domain/models/expense.dart';
import '../../../expenses/domain/models/group_settlement.dart';
import '../../../expenses/domain/services/balance_calculator.dart';
import '../../../groups/data/repositories/group_repository.dart';
import '../../../groups/domain/models/group.dart';
import '../../../groups/presentation/screens/group_details_screen.dart';
import '../../../groups/presentation/screens/group_invitation_screen.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../widgets/quick_action_tile.dart';
import '../widgets/group_card.dart';
import '../widgets/transaction_tile.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;

  const HomeScreen({super.key, this.onSelectTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _groupRepository = GroupRepository();
  final _expenseRepository = ExpenseRepository();
  final _settlementRepository = GroupSettlementRepository();
  final _notificationRepository = NotificationRepository();
  late final Stream<int> _unreadCountStream;

  StreamSubscription<List<Group>>? _groupsSubscription;
  final Map<String, StreamSubscription<List<Expense>>> _expenseSubscriptions =
      {};
  final Map<String, StreamSubscription<List<GroupSettlement>>>
  _settlementSubscriptions = {};

  List<Group> _groups = [];
  final Map<String, List<Expense>> _expensesByGroup = {};
  final Map<String, List<GroupSettlement>> _settlementsByGroup = {};
  final Set<String> _expensesLoaded = {};
  final Set<String> _settlementsLoaded = {};
  final Set<String> _failedExpenseStreams = {};
  final Set<String> _failedSettlementStreams = {};

  bool _groupsLoading = true;
  String? _loadError;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _displayName {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'there';
  }

  bool get _isDataLoading {
    if (_groupsLoading) return true;
    return _groups.any(
      (group) =>
          !_failedExpenseStreams.contains(group.id) &&
          !_failedSettlementStreams.contains(group.id) &&
          (!_expensesLoaded.contains(group.id) ||
              !_settlementsLoaded.contains(group.id)),
    );
  }

  @override
  void initState() {
    super.initState();
    _unreadCountStream = _notificationRepository.watchUnreadCount();
    _groupsSubscription = _groupRepository.watchMyGroups().listen(
      _handleGroups,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loadError = error.toString();
          _groupsLoading = false;
        });
      },
    );
  }

  void _handleGroups(List<Group> groups) {
    final currentIds = groups.map((group) => group.id).toSet();

    for (final groupId in _expenseSubscriptions.keys.toList()) {
      if (!currentIds.contains(groupId)) {
        _expenseSubscriptions.remove(groupId)?.cancel();
        _expensesByGroup.remove(groupId);
        _expensesLoaded.remove(groupId);
        _failedExpenseStreams.remove(groupId);
        _failedSettlementStreams.remove(groupId);
      }
    }

    for (final groupId in _settlementSubscriptions.keys.toList()) {
      if (!currentIds.contains(groupId)) {
        _settlementSubscriptions.remove(groupId)?.cancel();
        _settlementsByGroup.remove(groupId);
        _settlementsLoaded.remove(groupId);
        _failedExpenseStreams.remove(groupId);
        _failedSettlementStreams.remove(groupId);
      }
    }

    if (mounted) {
      setState(() {
        _groups = groups;
        _groupsLoading = false;
        _loadError = null;
      });
    }

    for (final group in groups) {
      if (!_expenseSubscriptions.containsKey(group.id)) {
        final groupId = group.id;
        _expenseSubscriptions[groupId] = _expenseRepository
            .watchGroupExpenses(groupId)
            .listen(
              (expenses) {
                if (!mounted) return;
                setState(() {
                  _expensesByGroup[groupId] = expenses;
                  _expensesLoaded.add(groupId);
                  _failedExpenseStreams.remove(groupId);
                });
              },
              onError: (Object error) {
                if (!mounted) return;
                setState(() {
                  _loadError = error.toString();
                  _failedExpenseStreams.add(groupId);
                  _expensesByGroup[groupId] = const <Expense>[];
                  _expensesLoaded.add(groupId);
                });
              },
            );
      }

      if (!_settlementSubscriptions.containsKey(group.id)) {
        final groupId = group.id;
        _settlementSubscriptions[groupId] = _settlementRepository
            .watchGroupSettlements(groupId)
            .listen(
              (settlements) {
                if (!mounted) return;
                setState(() {
                  _settlementsByGroup[groupId] = settlements;
                  _settlementsLoaded.add(groupId);
                  _failedSettlementStreams.remove(groupId);
                });
              },
              onError: (Object error) {
                if (!mounted) return;
                setState(() {
                  _loadError = error.toString();
                  _failedSettlementStreams.add(groupId);
                  _settlementsByGroup[groupId] = const <GroupSettlement>[];
                  _settlementsLoaded.add(groupId);
                });
              },
            );
      }
    }
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    for (final subscription in _expenseSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _settlementSubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  GroupBalanceSummary? _summaryFor(Group group) {
    if (_failedExpenseStreams.contains(group.id) ||
        _failedSettlementStreams.contains(group.id) ||
        !_expensesLoaded.contains(group.id) ||
        !_settlementsLoaded.contains(group.id)) {
      return null;
    }

    return BalanceCalculator.calculate(
      group: group,
      expenses: _expensesByGroup[group.id] ?? const <Expense>[],
      settlements: _settlementsByGroup[group.id] ?? const <GroupSettlement>[],
    );
  }

  _DashboardTotals _calculateTotals() {
    var owedPaise = 0;
    var owePaise = 0;

    for (final group in _groups) {
      final summary = _summaryFor(group);
      if (summary == null) continue;

      for (final balance in summary.balances) {
        if (balance.userId != _currentUid) continue;
        if (balance.netBalancePaise > 0) {
          owedPaise += balance.netBalancePaise;
        } else if (balance.netBalancePaise < 0) {
          owePaise += -balance.netBalancePaise;
        }
      }
    }

    return _DashboardTotals(owedPaise: owedPaise, owePaise: owePaise);
  }

  List<_RecentExpense> _recentExpenses() {
    final recent = <_RecentExpense>[];
    for (final group in _groups) {
      for (final expense in _expensesByGroup[group.id] ?? const <Expense>[]) {
        recent.add(_RecentExpense(group: group, expense: expense));
      }
    }

    recent.sort((a, b) => b.expense.createdAt.compareTo(a.expense.createdAt));
    return recent.take(5).toList();
  }

  String _formatPaise(int paise) {
    final rupees = paise ~/ 100;
    final cents = (paise % 100).toString().padLeft(2, '0');
    return cents == '00' ? '₹$rupees' : '₹$rupees.$cents';
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expenseDay = DateTime(date.year, date.month, date.day);
    final days = today.difference(expenseDay).inDays;

    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    return '${date.day}/${date.month}/${date.year}';
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

  IconData _expenseIcon(String category) {
    final value = category.toLowerCase();
    if (value.contains('travel') || value.contains('transport')) {
      return CupertinoIcons.car;
    }
    if (value.contains('food') || value.contains('grocery')) {
      return CupertinoIcons.cart;
    }
    return CupertinoIcons.doc_text;
  }

  void _openGroup(Group group) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => GroupDetailsScreen(group: group),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const NotificationsScreen()));
  }

  void _openGroupInvitation(Group group) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => GroupInvitationScreen(group: group)),
    );
  }

  Future<void> _chooseGroupAndOpen({
    required String title,
    required ValueChanged<Group> onSelected,
  }) async {
    if (_groups.isEmpty) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('No groups yet'),
          content: const Text(
            'Create or join a group before using this action.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(title),
        message: const Text('Choose one of your groups.'),
        actions: _groups.map((group) {
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              onSelected(group);
            },
            child: Text(group.name),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();
    final netPaise = totals.owedPaise - totals.owePaise;
    final readyGroups = _groups
        .where((group) => _summaryFor(group) != null)
        .toList();
    final recentExpenses = _recentExpenses();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Hisaab Brabar'),
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _openNotifications,
          child: StreamBuilder<int>(
            stream: _unreadCountStream,
            builder: (context, snapshot) {
              final hasUnread = (snapshot.data ?? 0) > 0;

              return SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Align(
                      alignment: Alignment.center,
                      child: Icon(
                        CupertinoIcons.bell,
                        color: AppColors.primary,
                        size: 23,
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Hello, $_displayName 👋',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Here is your expense overview',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _buildBalanceCard(totals, netPaise),
            const SizedBox(height: 24),
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
                    onTap: () => widget.onSelectTab?.call(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionTile(
                    title: 'Settle Up',
                    icon: CupertinoIcons.arrow_left_right,
                    iconBackground: AppColors.sage,
                    onTap: () => _chooseGroupAndOpen(
                      title: 'Choose a group to settle up',
                      onSelected: _openGroup,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionTile(
                    title: 'Invite',
                    icon: CupertinoIcons.person_2,
                    iconBackground: AppColors.secondary,
                    onTap: () => _chooseGroupAndOpen(
                      title: 'Choose a group to invite someone',
                      onSelected: _openGroupInvitation,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: QuickActionTile(
                    title: 'Discover',
                    icon: CupertinoIcons.search,
                    iconBackground: AppColors.sage,
                    onTap: () => widget.onSelectTab?.call(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _sectionHeading(
              'Active Groups',
              trailing: '${_groups.length} total',
            ),
            const SizedBox(height: 14),
            if (_groupsLoading || _isDataLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (_groups.isEmpty)
              _emptyCard(
                icon: CupertinoIcons.person_2,
                title: 'No groups yet',
                message:
                    'Create a group or join one to see your expenses here.',
              )
            else if (readyGroups.isEmpty)
              _emptyCard(
                icon: CupertinoIcons.info,
                title: 'Group data unavailable',
                message: 'Your groups loaded, but their expense data is not available yet.',
              )
            else
              ...readyGroups.take(3).map((group) {
                final summary = _summaryFor(group);
                final memberBalance = summary?.balances.where(
                  (balance) => balance.userId == _currentUid,
                );
                final amountPaise =
                    memberBalance == null || memberBalance.isEmpty
                    ? 0
                    : memberBalance.first.netBalancePaise;
                final amount = amountPaise > 0
                    ? '+${_formatPaise(amountPaise)}'
                    : amountPaise < 0
                    ? '-${_formatPaise(-amountPaise)}'
                    : 'Settled';
                final status = amountPaise > 0
                    ? 'You receive'
                    : amountPaise < 0
                    ? 'You owe'
                    : 'All clear';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _openGroup(group),
                    child: GroupCard(
                      groupName: group.name,
                      members: '${group.memberCount} members',
                      amount: amount,
                      status: status,
                      icon: _groupIcon(group.category),
                      iconBackground: amountPaise < 0
                          ? AppColors.secondary
                          : AppColors.sage,
                      amountColor: amountPaise < 0
                          ? AppColors.primary
                          : AppColors.sageDark,
                    ),
                  ),
                );
              }),
            const SizedBox(height: 28),
            _sectionHeading('Recent Transactions', trailing: 'Latest 5'),
            const SizedBox(height: 14),
            if (_groupsLoading || _isDataLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (recentExpenses.isEmpty)
              _emptyCard(
                icon: CupertinoIcons.doc_text,
                title: _loadError == null
                    ? 'No expenses yet'
                    : 'Transactions unavailable',
                message: _loadError == null
                    ? 'Expenses added to your groups will appear here.'
                    : 'Some group expense data could not be loaded. Try again later.',
              )
            else
              ...recentExpenses.map((entry) {
                final expense = entry.expense;
                final paidByYou = expense.paidByUserId == _currentUid;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _openGroup(entry.group),
                    child: TransactionTile(
                      title: expense.title,
                      paidBy: paidByYou
                          ? 'Paid by you • ${entry.group.name}'
                          : 'Paid by ${expense.paidByName} • ${entry.group.name}',
                      amount: _formatPaise(expense.amountPaise),
                      date: _relativeDate(expense.createdAt),
                      icon: _expenseIcon(expense.category),
                      iconBackground: AppColors.secondary,
                      amountColor: AppColors.textPrimary,
                    ),
                  ),
                );
              }),
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              Text(
                'Some live data could not be refreshed: $_loadError',
                style: const TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(_DashboardTotals totals, int netPaise) {
    final netAmount = netPaise < 0 ? -netPaise : netPaise;
    final netLabel = netPaise < 0
        ? '-'
        : netPaise > 0
        ? '+'
        : '';

    return Container(
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
          Text(
            '$netLabel${_formatPaise(netAmount)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Container(width: double.infinity, height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _balanceBreakdown(
                  title: 'You are owed',
                  amount: '+${_formatPaise(totals.owedPaise)}',
                  color: AppColors.sageDark,
                ),
              ),
              Expanded(
                child: _balanceBreakdown(
                  title: 'You owe',
                  amount: '-${_formatPaise(totals.owePaise)}',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceBreakdown({
    required String title,
    required String amount,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          amount,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeading(String title, {required String trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTotals {
  final int owedPaise;
  final int owePaise;

  const _DashboardTotals({required this.owedPaise, required this.owePaise});
}

class _RecentExpense {
  final Group group;
  final Expense expense;

  const _RecentExpense({required this.group, required this.expense});
}
