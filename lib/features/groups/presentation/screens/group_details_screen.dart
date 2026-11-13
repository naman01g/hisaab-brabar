import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../expenses/data/repositories/expense_repository.dart';
import '../../../expenses/domain/models/expense.dart';
import '../../../expenses/domain/services/balance_calculator.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';
import 'group_invitation_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late final Stream<List<Expense>> expensesStream;
  late final NotificationRepository notificationRepository;

  final Set<String> _sendingReminderIds = {};

  @override
  void initState() {
    super.initState();

    expensesStream = ExpenseRepository().watchGroupExpenses(widget.group.id);
    notificationRepository = NotificationRepository();
  }

  String _formatPaise(int paise) {
    final rupees = paise ~/ 100;
    final remaining = (paise % 100).toString().padLeft(2, '0');

    return '₹$rupees.$remaining';
  }

  void _openInvitation() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => GroupInvitationScreen(group: widget.group),
      ),
    );
  }

  GroupMember? _findUniqueMemberByName(String displayName) {
    final normalizedName = displayName.trim().toLowerCase();
    final matches = widget.group.members
        .where(
          (member) => member.displayName.trim().toLowerCase() == normalizedName,
        )
        .toList();

    // Avoid sending a reminder to the wrong person when names are duplicated.
    return matches.length == 1 ? matches.single : null;
  }

  Future<void> _showReminderFeedback({
    required String title,
    required String message,
  }) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReminder(GroupMember recipient) async {
    if (_sendingReminderIds.contains(recipient.userId)) return;

    setState(() => _sendingReminderIds.add(recipient.userId));

    try {
      await notificationRepository.sendSettleUpRequest(
        group: widget.group,
        recipient: recipient,
        message: 'Please settle your pending balance in ${widget.group.name}.',
      );

      if (!mounted) return;
      await _showReminderFeedback(
        title: 'Reminder sent',
        message: 'A settle-up reminder was sent to ${recipient.displayName}.',
      );
    } catch (error) {
      if (!mounted) return;
      await _showReminderFeedback(
        title: 'Could not send reminder',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingReminderIds.remove(recipient.userId));
      }
    }
  }

  Widget _memberCard(GroupMember member) {
    final isOwner =
        member.userId == widget.group.createdBy ||
        member.role == GroupRole.owner;

    final displayName = member.displayName.isNotEmpty
        ? member.displayName
        : 'Member';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.sage,
              shape: BoxShape.circle,
            ),
            child: Text(
              displayName[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.sageDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOwner ? 'Owner' : 'Member',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isOwner)
            const Icon(
              CupertinoIcons.checkmark_seal_fill,
              color: AppColors.sageDark,
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _balanceCard(GroupBalanceSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL GROUP EXPENSES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatPaise(summary.totalExpensesPaise),
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'MEMBER BALANCES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          ...summary.balances.map((balance) {
            final amount = balance.netBalancePaise;
            final reminderRecipient = amount < 0
                ? _findUniqueMemberByName(balance.displayName)
                : null;
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final isSendingReminder =
                reminderRecipient != null &&
                _sendingReminderIds.contains(reminderRecipient.userId);
            final color = amount > 0
                ? AppColors.sageDark
                : amount < 0
                ? AppColors.error
                : AppColors.textSecondary;

            final status = amount > 0
                ? 'Gets back'
                : amount < 0
                ? 'Owes'
                : 'Settled';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      balance.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatPaise(amount.abs()),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                    ],
                  ),
                  if (reminderRecipient != null &&
                      reminderRecipient.userId != currentUserId) ...[
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: isSendingReminder
                          ? null
                          : () => _sendReminder(reminderRecipient),
                      child: isSendingReminder
                          ? const CupertinoActivityIndicator(radius: 8)
                          : const Text(
                              'Remind',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _settlementSection(List<SettlementSuggestion> settlements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggested Settlements',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        if (settlements.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.sage,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Everyone is settled up!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.sageDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...settlements.map((settlement) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settlement.fromName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Icon(
                            CupertinoIcons.arrow_down,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          settlement.toName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatPaise(settlement.amountPaise),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),

        if (settlements.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'These are suggested payments. No settlement is recorded automatically.',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _expenseCard(Expense expense) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.doc_text,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${expense.category} • Paid by ${expense.paidByName}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatPaise(expense.amountPaise),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Group Details'),
      ),
      child: SafeArea(
        child: StreamBuilder<List<Expense>>(
          stream: expensesStream,
          builder: (context, snapshot) {
            final expenses = snapshot.data ?? <Expense>[];

            GroupBalanceSummary? summary;
            String? calculationError;

            if (snapshot.hasData) {
              try {
                summary = BalanceCalculator.calculate(
                  group: group,
                  expenses: expenses,
                );
              } catch (error) {
                calculationError = error.toString();
              }
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Group information
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${group.memberCount} members • ${group.currencyCode}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Invite members
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _openInvitation,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.person_add, size: 18),
                      SizedBox(width: 9),
                      Text('Invite Members'),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'Members (${group.memberCount})',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 14),

                ...group.members.map(_memberCard),

                const SizedBox(height: 24),

                const Text(
                  'Group Balances',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 14),

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Center(child: CupertinoActivityIndicator())
                else if (snapshot.hasError)
                  Text(
                    'Unable to calculate balances: ${snapshot.error}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  )
                else if (calculationError != null)
                  Text(
                    'Balance calculation error: $calculationError',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  )
                else if (summary != null) ...[
                  _balanceCard(summary),
                  const SizedBox(height: 20),
                  _settlementSection(summary.settlements),
                ],

                const SizedBox(height: 28),

                const Text(
                  'Expense History',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 14),

                if (snapshot.hasError)
                  Text(
                    'Unable to load expenses: ${snapshot.error}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  )
                else if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Center(child: CupertinoActivityIndicator())
                else if (expenses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'No expenses in this group yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...expenses.map(_expenseCard),

                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
