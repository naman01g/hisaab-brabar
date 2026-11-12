import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/expense_repository.dart';
import '../../domain/models/expense.dart';

class ExpenseReviewScreen extends StatefulWidget {
  final Expense expense;
  final ExpenseRepository repository;

  const ExpenseReviewScreen({
    super.key,
    required this.expense,
    required this.repository,
  });

  @override
  State<ExpenseReviewScreen> createState() => _ExpenseReviewScreenState();
}

class _ExpenseReviewScreenState extends State<ExpenseReviewScreen> {
  bool isSaving = false;
  String? errorMessage;

  String _formatPaise(int paise) {
    final rupees = paise ~/ 100;
    final remaining = (paise % 100).toString().padLeft(2, '0');

    return '₹$rupees.$remaining';
  }

  Future<void> _saveExpense() async {
    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await widget.repository.createExpense(widget.expense);

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.message ?? error.code;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Review Expense'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Expense',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatPaise(expense.amountPaise),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    expense.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _infoRow('Group', expense.groupName),
                  _infoRow('Category', expense.category),
                  _infoRow('Paid by', expense.paidByName),
                  _infoRow(
                    'Split method',
                    expense.splitType.name.toUpperCase(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Share Breakdown',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ...expense.sharesPaise.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            expense.participantNames[entry.key] ?? 'Member',
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
                    margin: const EdgeInsets.symmetric(vertical: 10),
                  ),

                  _infoRow(
                    'Total allocated',
                    _formatPaise(
                      expense.sharesPaise.values.fold<int>(
                        0,
                        (total, share) => total + share,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ],

            const SizedBox(height: 24),

            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(14),
              onPressed: isSaving ? null : _saveExpense,
              child: isSaving
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text('Save & Split Expense'),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
