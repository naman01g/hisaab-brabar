import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../groups/data/repositories/group_repository.dart';
import '../../../groups/domain/models/group.dart';
import '../../../groups/domain/models/group_member.dart';
import '../../data/repositories/expense_repository.dart';
import '../../domain/models/expense.dart';
import '../../domain/services/split_calculator.dart';
import 'expense_review_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final groupRepository = GroupRepository();

  final expenseRepository = ExpenseRepository();

  late final Stream<List<Group>> groupsStream;

  final amountController = TextEditingController();
  final titleController = TextEditingController();

  final categories = ['Food', 'Travel', 'Shopping', 'Bills', 'Other'];

  final Map<String, TextEditingController> exactControllers = {};
  final Map<String, TextEditingController> percentageControllers = {};

  String selectedCategory = 'Food';
  Group? selectedGroup;
  String? selectedPayerId;

  final Set<String> selectedParticipants = {};

  SplitType splitType = SplitType.equal;

  @override
  void initState() {
    super.initState();
    groupsStream = groupRepository.watchMyGroups();
  }

  @override
  void dispose() {
    amountController.dispose();
    titleController.dispose();

    for (final controller in exactControllers.values) {
      controller.dispose();
    }

    for (final controller in percentageControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // Convert rupees into integer paise.
  int? _parsePaise(String value) {
    final input = value.trim().replaceAll(',', '');

    if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(input)) {
      return null;
    }

    final parts = input.split('.');
    final rupees = int.tryParse(parts[0]);

    if (rupees == null) return null;

    final paise = parts.length > 1 ? parts[1].padRight(2, '0') : '00';

    return rupees * 100 + int.parse(paise);
  }

  String _formatPaise(int paise) {
    final rupees = paise ~/ 100;
    final remaining = (paise % 100).toString().padLeft(2, '0');

    return '₹$rupees.$remaining';
  }

  void _initializeMemberControllers(Group group) {
    for (final member in group.members) {
      exactControllers.putIfAbsent(
        member.userId,
        () => TextEditingController(),
      );

      percentageControllers.putIfAbsent(
        member.userId,
        () => TextEditingController(),
      );
    }
  }

  void _selectGroup(List<Group> groups) {
    if (groups.isEmpty) return;

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Select Group'),
          message: const Text('Choose where this expense belongs'),
          actions: groups.map((group) {
            return CupertinoActionSheetAction(
              onPressed: () {
                _initializeMemberControllers(group);

                setState(() {
                  selectedGroup = group;
                  selectedParticipants
                    ..clear()
                    ..addAll(group.members.map((member) => member.userId));

                  final currentUid = FirebaseAuth.instance.currentUser?.uid;

                  selectedPayerId =
                      group.members.any((member) => member.userId == currentUid)
                      ? currentUid
                      : group.members.first.userId;

                  for (final controller in exactControllers.values) {
                    controller.clear();
                  }

                  for (final controller in percentageControllers.values) {
                    controller.clear();
                  }
                });

                Navigator.pop(context);
              },
              child: Text(group.name),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  void _selectPayer() {
    final group = selectedGroup;

    if (group == null) return;

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Who paid?'),
          actions: group.members.map((member) {
            return CupertinoActionSheetAction(
              onPressed: () {
                setState(() {
                  selectedPayerId = member.userId;
                });

                Navigator.pop(context);
              },
              child: Text(member.displayName),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  void _toggleParticipant(String userId) {
    setState(() {
      if (selectedParticipants.contains(userId)) {
        if (selectedParticipants.length > 1) {
          selectedParticipants.remove(userId);
        }
      } else {
        selectedParticipants.add(userId);
      }
    });
  }

  int _percentageTotal() {
    return selectedParticipants.fold<int>(0, (total, userId) {
      final value = int.tryParse(
        percentageControllers[userId]?.text.trim() ?? '',
      );

      return total + (value ?? 0) * 100;
    });
  }

  Map<String, int> _calculateShares(int totalPaise) {
    final group = selectedGroup;

    if (group == null || selectedParticipants.isEmpty) {
      return {};
    }

    final participants = selectedParticipants.toList()..sort();

    try {
      switch (splitType) {
        case SplitType.equal:
          return SplitCalculator.equal(
            totalPaise: totalPaise,
            participants: participants,
          );

        case SplitType.exact:
          final shares = <String, int>{};

          for (final userId in participants) {
            final value = _parsePaise(exactControllers[userId]?.text ?? '');

            if (value == null) return {};

            shares[userId] = value;
          }

          return SplitCalculator.exact(
            totalPaise: totalPaise,
            participants: participants,
            sharesPaise: shares,
          );

        case SplitType.percentage:
          final percentages = <String, int>{};

          for (final userId in participants) {
            final value = int.tryParse(
              percentageControllers[userId]?.text.trim() ?? '',
            );

            if (value == null) return {};

            percentages[userId] = value * 100;
          }

          return SplitCalculator.percentage(
            totalPaise: totalPaise,
            participants: participants,
            percentagesBasisPoints: percentages,
          );
      }
    } on ArgumentError {
      return {};
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Check Expense Details'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reviewExpense() async {
    final group = selectedGroup;
    final total = _parsePaise(amountController.text);
    final title = titleController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showError('Please sign in first.');
      return;
    }

    if (group == null) {
      _showError('Please select a group.');
      return;
    }

    if (total == null || total <= 0) {
      _showError('Enter a valid expense amount.');
      return;
    }

    if (title.isEmpty) {
      _showError('Enter an expense title.');
      return;
    }

    if (selectedPayerId == null) {
      _showError('Select who paid for this expense.');
      return;
    }

    final shares = _calculateShares(total);

    final allocated = shares.values.fold<int>(0, (sum, share) => sum + share);

    if (shares.length != selectedParticipants.length ||
        allocated != total ||
        shares.values.any((share) => share <= 0)) {
      _showError('Please check your split amounts.');
      return;
    }

    final membersById = {
      for (final member in group.members) member.userId: member,
    };

    final payer = membersById[selectedPayerId];

    if (payer == null) {
      _showError('The selected payer is not in this group.');
      return;
    }

    final participantNames = <String, String>{
      for (final userId in selectedParticipants)
        userId: membersById[userId]!.displayName,
    };

    final expense = Expense(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      groupId: group.id,
      groupName: group.name,
      title: title,
      category: selectedCategory,
      createdBy: currentUser.uid,
      paidByUserId: payer.userId,
      paidByName: payer.displayName,
      amountPaise: total,
      sharesPaise: shares,
      participantNames: participantNames,
      splitType: splitType,
      createdAt: DateTime.now(),
    );

    final saved = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (context) => ExpenseReviewScreen(
          expense: expense,
          repository: expenseRepository,
        ),
      ),
    );

    if (!mounted || saved != true) return;

    setState(() {
      amountController.clear();
      titleController.clear();
      selectedCategory = 'Food';
      splitType = SplitType.equal;
    });

    _showError('Expense saved successfully!');
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _selectionField({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: title.startsWith('Choose')
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareInput(GroupMember member) {
    final isExact = splitType == SplitType.exact;

    return SizedBox(
      width: 105,
      child: CupertinoTextField(
        controller: isExact
            ? exactControllers[member.userId]
            : percentageControllers[member.userId],
        keyboardType: TextInputType.numberWithOptions(decimal: isExact),
        textAlign: TextAlign.right,
        placeholder: isExact ? '0.00' : '0',
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        suffix: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            isExact ? '₹' : '%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildParticipantRow(GroupMember member) {
    final selected = selectedParticipants.contains(member.userId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondary.withValues(alpha: 0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryLight : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _toggleParticipant(member.userId),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sage,
                      ),
                      child: Text(
                        member.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.sageDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        member.displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      selected
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 21,
                    ),
                  ],
                ),
              ),
            ),
            if (selected && splitType != SplitType.equal) ...[
              const SizedBox(width: 8),
              _buildShareInput(member),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSplitPreview(int total) {
    if (splitType == SplitType.percentage && _percentageTotal() != 10000) {
      return Text(
        'Percentages must total 100%. Current: ${_percentageTotal() ~/ 100}%',
        style: const TextStyle(fontSize: 12, color: AppColors.error),
      );
    }

    final shares = _calculateShares(total);

    if (shares.length != selectedParticipants.length) {
      return const Text(
        'Enter valid split amounts to see the breakdown.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }

    final members = {
      for (final member in selectedGroup!.members) member.userId: member,
    };

    final allocated = shares.values.fold<int>(0, (sum, share) => sum + share);

    return Column(
      children: [
        ...shares.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  members[entry.key]!.displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _formatPaise(entry.value),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        }),
        Container(
          height: 1,
          color: AppColors.border,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total allocated',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              _formatPaise(allocated),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: allocated == total
                    ? AppColors.sageDark
                    : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm(List<Group> groups) {
    final group = selectedGroup;
    final total = _parsePaise(amountController.text);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle('How much did you spend?'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: CupertinoTextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                '₹',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: const BoxDecoration(),
            padding: const EdgeInsets.all(8),
            onChanged: (_) => setState(() {}),
          ),
        ),

        const SizedBox(height: 28),

        _sectionTitle('What was it for?'),
        const SizedBox(height: 12),
        CupertinoTextField(
          controller: titleController,
          placeholder: 'e.g. Dinner with friends',
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
        ),

        const SizedBox(height: 28),

        _sectionTitle('Choose Category'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: categories.map((category) {
            final selected = selectedCategory == category;

            return CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              borderRadius: BorderRadius.circular(20),
              color: selected ? AppColors.secondary : AppColors.surface,
              onPressed: () {
                setState(() => selectedCategory = category);
              },
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        _sectionTitle('Select Group'),
        const SizedBox(height: 12),
        _selectionField(
          title: group?.name ?? 'Choose a group',
          icon: CupertinoIcons.person_2,
          onPressed: () => _selectGroup(groups),
        ),

        const SizedBox(height: 28),

        if (group != null) ...[
          _sectionTitle('Paid By'),
          const SizedBox(height: 12),
          _selectionField(
            title: group.members
                .firstWhere((member) => member.userId == selectedPayerId)
                .displayName,
            icon: CupertinoIcons.person,
            onPressed: _selectPayer,
          ),

          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('Split Between'),
              Text(
                '${selectedParticipants.length} selected',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          const Text(
            'Select everyone sharing this expense.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),

          const SizedBox(height: 12),

          ...group.members.map(_buildParticipantRow),

          const SizedBox(height: 24),

          _sectionTitle('Split Method'),
          const SizedBox(height: 12),

          CupertinoSlidingSegmentedControl<SplitType>(
            groupValue: splitType,
            backgroundColor: AppColors.border,
            thumbColor: AppColors.surface,
            children: {
              SplitType.equal: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Equal'),
              ),
              SplitType.exact: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Exact'),
              ),
              SplitType.percentage: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('%'),
              ),
            },
            onValueChanged: (value) {
              if (value == null) return;
              setState(() => splitType = value);
            },
          ),

          const SizedBox(height: 12),

          Text(
            splitType == SplitType.equal
                ? 'Divide the amount equally.'
                : splitType == SplitType.exact
                ? 'Enter each member’s exact amount.'
                : 'Enter each member’s percentage. Total must be 100%.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 20),

          if (total != null && total > 0)
            Container(
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
                    'Split Breakdown',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSplitPreview(total),
                ],
              ),
            ),

          const SizedBox(height: 24),

          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(14),
            onPressed: _reviewExpense,
            child: const Text('Review Expense'),
          ),
        ],

        if (group == null) ...[
          const SizedBox(height: 16),
          const Text(
            'Select a group to choose its members and split the expense.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Add Expense'),
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
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
                  child: Text(
                    'Unable to load groups: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            return _buildForm(snapshot.data ?? []);
          },
        ),
      ),
    );
  }
}
