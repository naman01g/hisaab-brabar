import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import 'expense_review_screen.dart';

enum SplitType { equal, exact, percentage }

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  // Selected values
  String selectedCategory = 'Food';
  String? selectedGroup;
  String selectedPayer = 'You';
  SplitType splitType = SplitType.equal;

  // Text controllers
  final TextEditingController amountController = TextEditingController();
  final TextEditingController titleController = TextEditingController();

  // Sample categories
  final List<String> categories = [
    'Food',
    'Travel',
    'Shopping',
    'Bills',
    'Other',
  ];

  // Sample groups
  final List<String> groups = [
    'Flat 402 Boys & Girls',
    'Goa Summer Getaway',
    'College Fest SOS',
    'Hostel Wing B',
  ];

  // Sample group members
  final List<String> members = ['You', 'Aarav', 'Meera', 'Kabir'];

  // Selected participants
  final Set<String> selectedParticipants = {'You', 'Aarav', 'Meera', 'Kabir'};

  // Controllers for custom splits
  late final Map<String, TextEditingController> exactControllers;
  late final Map<String, TextEditingController> percentageControllers;

  @override
  void initState() {
    super.initState();

    exactControllers = {
      for (final member in members) member: TextEditingController(),
    };

    percentageControllers = {
      for (final member in members) member: TextEditingController(),
    };
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

  // Convert rupees into integer paise
  int? _parsePaise(String value) {
    final input = value.trim().replaceAll(',', '');

    if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(input)) {
      return null;
    }

    final parts = input.split('.');
    final rupees = int.tryParse(parts[0]);

    if (rupees == null) return null;

    final paiseText = parts.length > 1 ? parts[1].padRight(2, '0') : '00';

    return rupees * 100 + int.parse(paiseText);
  }

  // Convert integer paise into rupees
  String _formatPaise(int paise) {
    final rupees = paise ~/ 100;
    final remaining = (paise % 100).toString().padLeft(2, '0');

    return '₹$rupees.$remaining';
  }

  // Calculate percentage total
  int _percentageTotal() {
    return selectedParticipants.fold(0, (total, member) {
      final percentage = int.tryParse(
        percentageControllers[member]!.text.trim(),
      );

      return total + (percentage ?? 0) * 100;
    });
  }

  // Calculate shares
  Map<String, int> _calculateShares() {
    final total = _parsePaise(amountController.text);

    if (total == null || total <= 0 || selectedParticipants.isEmpty) {
      return {};
    }

    final participantList = selectedParticipants.toList()..sort();

    // Equal split
    if (splitType == SplitType.equal) {
      final baseShare = total ~/ participantList.length;
      final remainder = total % participantList.length;

      return {
        for (int i = 0; i < participantList.length; i++)
          participantList[i]: baseShare + (i < remainder ? 1 : 0),
      };
    }

    // Exact split
    if (splitType == SplitType.exact) {
      return {
        for (final member in participantList)
          member: _parsePaise(exactControllers[member]!.text) ?? 0,
      };
    }

    // Percentage split
    if (_percentageTotal() != 10000) {
      return {};
    }

    final shares = <String, int>{};
    final remainders = <MapEntry<String, int>>[];

    int allocated = 0;

    for (final member in participantList) {
      final percentage =
          int.parse(percentageControllers[member]!.text.trim()) * 100;

      final numerator = total * percentage;
      final share = numerator ~/ 10000;
      final remainder = numerator % 10000;

      shares[member] = share;
      allocated += share;

      remainders.add(MapEntry(member, remainder));
    }

    // Distribute leftover paise using largest remainder
    remainders.sort((a, b) {
      final comparison = b.value.compareTo(a.value);

      if (comparison != 0) return comparison;

      return a.key.compareTo(b.key);
    });

    final remaining = total - allocated;

    for (int i = 0; i < remaining; i++) {
      final member = remainders[i].key;
      shares[member] = shares[member]! + 1;
    }

    return shares;
  }

  // Show group selection
  void _showGroupPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Select Group'),
          message: const Text('Choose where this expense belongs'),
          actions: groups.map((group) {
            return CupertinoActionSheetAction(
              onPressed: () {
                setState(() {
                  selectedGroup = group;
                });

                Navigator.pop(context);
              },
              child: Text(group),
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

  // Show payer selection
  void _showPayerPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Who paid?'),
          actions: members.map((member) {
            return CupertinoActionSheetAction(
              onPressed: () {
                setState(() {
                  selectedPayer = member;
                });

                Navigator.pop(context);
              },
              child: Text(member),
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

  // Select or deselect participants
  void _toggleParticipant(String member) {
    setState(() {
      if (selectedParticipants.contains(member)) {
        if (selectedParticipants.length > 1) {
          selectedParticipants.remove(member);
        }
      } else {
        selectedParticipants.add(member);
      }
    });
  }

  // Show validation error
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

  // Navigate to review screen
  void _reviewExpense() {
    final total = _parsePaise(amountController.text);
    final title = titleController.text.trim();

    if (total == null || total <= 0) {
      _showError('Please enter a valid expense amount.');
      return;
    }

    if (title.isEmpty) {
      _showError('Please enter an expense title.');
      return;
    }

    if (selectedGroup == null) {
      _showError('Please select a group.');
      return;
    }

    if (selectedParticipants.isEmpty) {
      _showError('Please select participants.');
      return;
    }

    final shares = _calculateShares();

    final allocated = shares.values.fold(0, (sum, share) => sum + share);

    if (shares.length != selectedParticipants.length ||
        allocated != total ||
        shares.values.any((share) => share <= 0)) {
      _showError('Please check your split amounts.');
      return;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ExpenseReviewScreen(
          title: title,
          category: selectedCategory,
          group: selectedGroup!,
          payer: selectedPayer,
          amountPaise: total,
          shares: Map<String, int>.from(shares),
          splitMethod: splitType.name.toUpperCase(),
        ),
      ),
    );
  }

  // Section heading
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

  // Reusable selection field
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
                  color: title == 'Choose a group'
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

  // Exact or percentage input
  Widget _buildShareInput(String member) {
    final isExact = splitType == SplitType.exact;

    final controller = isExact
        ? exactControllers[member]!
        : percentageControllers[member]!;

    return SizedBox(
      width: 105,
      child: CupertinoTextField(
        controller: controller,
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

  // Participant row
  Widget _buildParticipantRow(String member) {
    final isSelected = selectedParticipants.contains(member);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withValues(alpha: 0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _toggleParticipant(member),
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
                        member[0],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.sageDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        member,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      isSelected
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 21,
                    ),
                  ],
                ),
              ),
            ),

            if (isSelected && splitType != SplitType.equal) ...[
              const SizedBox(width: 8),
              _buildShareInput(member),
            ],
          ],
        ),
      ),
    );
  }

  // Split preview
  Widget _buildSplitPreview() {
    final total = _parsePaise(amountController.text);

    if (total == null || total <= 0) {
      return const Text(
        'Enter an amount to see the split breakdown.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }

    if (selectedParticipants.isEmpty) {
      return const Text('Select at least one participant.');
    }

    if (splitType == SplitType.percentage && _percentageTotal() != 10000) {
      return Text(
        'Percentages must total 100%. Currently: '
        '${_percentageTotal() ~/ 100}%',
        style: const TextStyle(color: AppColors.error, fontSize: 12),
      );
    }

    final shares = _calculateShares();
    final allocated = shares.values.fold(0, (sum, value) => sum + value);

    final participantList = selectedParticipants.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...participantList.map((member) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  member,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _formatPaise(shares[member] ?? 0),
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
                fontSize: 14,
                color: allocated == total
                    ? AppColors.sageDark
                    : AppColors.error,
              ),
            ),
          ],
        ),

        if (allocated != total)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Your shares must add up exactly to the expense amount.',
              style: TextStyle(fontSize: 11, color: AppColors.error),
            ),
          ),
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Amount
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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

            // Expense title
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

            // Category
            _sectionTitle('Choose Category'),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories.map((category) {
                final isSelected = selectedCategory == category;

                return CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected ? AppColors.secondary : AppColors.surface,
                  onPressed: () {
                    setState(() {
                      selectedCategory = category;
                    });
                  },
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Group
            _sectionTitle('Select Group'),
            const SizedBox(height: 12),

            _selectionField(
              title: selectedGroup ?? 'Choose a group',
              icon: CupertinoIcons.person_2,
              onPressed: _showGroupPicker,
            ),

            const SizedBox(height: 28),

            // Payer
            _sectionTitle('Paid By'),
            const SizedBox(height: 12),

            _selectionField(
              title: selectedPayer,
              icon: CupertinoIcons.person,
              onPressed: _showPayerPicker,
            ),

            const SizedBox(height: 28),

            // Participants
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

            ...members.map(_buildParticipantRow),

            const SizedBox(height: 24),

            // Split method
            _sectionTitle('Split Method'),
            const SizedBox(height: 12),

            CupertinoSlidingSegmentedControl<SplitType>(
              groupValue: splitType,
              backgroundColor: AppColors.border,
              thumbColor: AppColors.surface,
              children: <SplitType, Widget>{
                SplitType.equal: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Equal',
                    style: TextStyle(
                      color: splitType == SplitType.equal
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                SplitType.exact: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Exact',
                    style: TextStyle(
                      color: splitType == SplitType.exact
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                SplitType.percentage: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '%',
                    style: TextStyle(
                      color: splitType == SplitType.percentage
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              },
              onValueChanged: (value) {
                if (value == null) return;

                setState(() {
                  splitType = value;
                });
              },
            ),

            const SizedBox(height: 12),

            Text(
              splitType == SplitType.equal
                  ? 'The amount is divided equally between selected members.'
                  : splitType == SplitType.exact
                  ? 'Enter the exact rupee amount for each member.'
                  : 'Enter each member’s percentage. Total must be 100%.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            // Split breakdown
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
                  _buildSplitPreview(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Review button
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(14),
              onPressed: _reviewExpense,
              child: const Text('Review Expense'),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
