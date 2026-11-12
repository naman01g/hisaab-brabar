enum SplitType { equal, exact, percentage }

class Expense {
  final String id;
  final String groupId;
  final String groupName;
  final String title;
  final String category;

  final String createdBy;
  final String paidByUserId;
  final String paidByName;

  // Money is stored in integer paise.
  final int amountPaise;

  // Firebase UID -> share in paise.
  final Map<String, int> sharesPaise;

  // Firebase UID -> display name.
  final Map<String, String> participantNames;

  final SplitType splitType;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.title,
    required this.category,
    required this.createdBy,
    required this.paidByUserId,
    required this.paidByName,
    required this.amountPaise,
    required Map<String, int> sharesPaise,
    required Map<String, String> participantNames,
    required this.splitType,
    required this.createdAt,
  }) : sharesPaise = Map.unmodifiable(sharesPaise),
       participantNames = Map.unmodifiable(participantNames) {
    if (amountPaise <= 0) {
      throw ArgumentError('Expense amount must be positive');
    }

    if (this.sharesPaise.isEmpty) {
      throw ArgumentError('At least one participant is required');
    }

    if (this.sharesPaise.keys
            .toSet()
            .difference(this.participantNames.keys.toSet())
            .isNotEmpty ||
        this.participantNames.keys
            .toSet()
            .difference(this.sharesPaise.keys.toSet())
            .isNotEmpty) {
      throw ArgumentError('Participant names and shares must match');
    }

    if (this.sharesPaise.values.any((share) => share <= 0)) {
      throw ArgumentError('Each share must be positive');
    }

    final allocated = this.sharesPaise.values.fold<int>(
      0,
      (total, share) => total + share,
    );

    if (allocated != amountPaise) {
      throw ArgumentError('Shares must equal the total expense');
    }
  }
}
