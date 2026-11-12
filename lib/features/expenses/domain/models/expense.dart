enum SplitType { equal, exact, percentage }

class Expense {
  final String id;
  final String title;
  final String category;
  final String group;
  final String paidBy;

  // All money values are stored in paise.
  final int amountPaise;

  // Member name -> share in paise.
  final Map<String, int> sharesPaise;

  final SplitType splitType;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.group,
    required this.paidBy,
    required this.amountPaise,
    required Map<String, int> sharesPaise,
    required this.splitType,
    required this.createdAt,
  }) : sharesPaise = Map.unmodifiable(sharesPaise) {
    if (amountPaise <= 0) {
      throw ArgumentError('Expense amount must be positive');
    }

    if (this.sharesPaise.isEmpty) {
      throw ArgumentError('At least one participant is required');
    }

    if (this.sharesPaise.values.any((share) => share <= 0)) {
      throw ArgumentError('Each share must be positive');
    }

    final allocatedPaise = this.sharesPaise.values.fold<int>(
      0,
      (total, share) => total + share,
    );

    if (allocatedPaise != amountPaise) {
      throw ArgumentError('Shares must equal the total expense');
    }
  }
}
