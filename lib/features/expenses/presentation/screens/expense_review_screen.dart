import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';

class ExpenseReviewScreen extends StatelessWidget {
  final String title;
  final String category;
  final String group;
  final String payer;
  final int amountPaise;
  final Map<String, int> shares;
  final String splitMethod;

  const ExpenseReviewScreen({
    super.key,
    required this.title,
    required this.category,
    required this.group,
    required this.payer,
    required this.amountPaise,
    required this.shares,
    required this.splitMethod,
  });

  // Format paise as Indian rupees
  String formatAmount(int paise) {
    final rupees = paise ~/ 100;
    final remaining = (paise % 100).toString().padLeft(2, '0');

    return '₹$rupees.$remaining';
  }

  // Reusable detail row
  Widget _detailRow(String label, String value) {
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
              textAlign: TextAlign.end,
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
    final totalAllocated = shares.values.fold(0, (sum, share) => sum + share);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,

      navigationBar: CupertinoNavigationBar(
        middle: const Text('Review Expense'),
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
      ),

      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Amount Summary
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    'TOTAL EXPENSE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    formatAmount(amountPaise),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Expense Details
            const Text(
              'Expense Details',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            _detailRow('Category', category),
            _detailRow('Group', group),
            _detailRow('Paid By', payer),
            _detailRow('Split Method', splitMethod),

            const SizedBox(height: 28),

            // Split Breakdown
            const Text(
              'Split Breakdown',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ...shares.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.sage,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              entry.key[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.sageDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),

                          Text(
                            formatAmount(entry.value),
                            style: const TextStyle(
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total allocated',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      Text(
                        formatAmount(totalAllocated),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: totalAllocated == amountPaise
                              ? AppColors.sageDark
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Prototype notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Please review the details carefully. Saving expenses will be implemented in a later step.',
                style: TextStyle(fontSize: 12, color: AppColors.sageDark),
              ),
            ),

            const SizedBox(height: 20),

            CupertinoButton(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.primary,
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Back to Edit',
                style: TextStyle(color: AppColors.surface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
