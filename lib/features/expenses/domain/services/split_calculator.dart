class SplitCalculator {
  // Validate the total amount and participant list.
  static List<String> _validateParticipants({
    required int totalPaise,
    required List<String> participants,
  }) {
    if (totalPaise <= 0) {
      throw ArgumentError('Expense amount must be positive');
    }

    if (participants.isEmpty) {
      throw ArgumentError('At least one participant is required');
    }

    if (participants.any((name) => name.trim().isEmpty)) {
      throw ArgumentError('Participant names cannot be empty');
    }

    if (participants.toSet().length != participants.length) {
      throw ArgumentError('Duplicate participants are not allowed');
    }

    if (totalPaise < participants.length) {
      throw ArgumentError(
        'There are not enough paise to give everyone a positive share',
      );
    }

    return participants.toList()..sort();
  }

  // 1. Equal split
  static Map<String, int> equal({
    required int totalPaise,
    required List<String> participants,
  }) {
    final members = _validateParticipants(
      totalPaise: totalPaise,
      participants: participants,
    );

    final baseShare = totalPaise ~/ members.length;
    final remainder = totalPaise % members.length;

    final shares = <String, int>{};

    for (int i = 0; i < members.length; i++) {
      shares[members[i]] = baseShare + (i < remainder ? 1 : 0);
    }

    return shares;
  }

  // 2. Exact split
  static Map<String, int> exact({
    required int totalPaise,
    required List<String> participants,
    required Map<String, int> sharesPaise,
  }) {
    final members = _validateParticipants(
      totalPaise: totalPaise,
      participants: participants,
    );

    if (sharesPaise.length != members.length ||
        !sharesPaise.keys.toSet().containsAll(members)) {
      throw ArgumentError(
        'Each selected participant must have exactly one share',
      );
    }

    if (sharesPaise.values.any((share) => share <= 0)) {
      throw ArgumentError('Each share must be positive');
    }

    final allocatedPaise = sharesPaise.values.fold<int>(
      0,
      (total, share) => total + share,
    );

    if (allocatedPaise != totalPaise) {
      throw ArgumentError('Exact shares must equal the total expense amount');
    }

    return {for (final member in members) member: sharesPaise[member]!};
  }

  // 3. Percentage split
  // 10000 basis points = 100%.
  // For example, 25% = 2500 basis points.
  static Map<String, int> percentage({
    required int totalPaise,
    required List<String> participants,
    required Map<String, int> percentagesBasisPoints,
  }) {
    final members = _validateParticipants(
      totalPaise: totalPaise,
      participants: participants,
    );

    if (percentagesBasisPoints.length != members.length ||
        !percentagesBasisPoints.keys.toSet().containsAll(members)) {
      throw ArgumentError('Every selected participant must have a percentage');
    }

    if (percentagesBasisPoints.values.any((value) => value <= 0)) {
      throw ArgumentError('Each percentage must be positive');
    }

    final percentageTotal = percentagesBasisPoints.values.fold<int>(
      0,
      (total, percentage) => total + percentage,
    );

    if (percentageTotal != 10000) {
      throw ArgumentError('Percentages must total exactly 100%');
    }

    final shares = <String, int>{};
    final remainders = <MapEntry<String, int>>[];

    int allocatedPaise = 0;

    for (final member in members) {
      final percentage = percentagesBasisPoints[member]!;

      final numerator = totalPaise * percentage;

      final share = numerator ~/ 10000;
      final remainder = numerator % 10000;

      shares[member] = share;
      allocatedPaise += share;

      remainders.add(MapEntry(member, remainder));
    }

    // Give leftover paise to members with the largest remainders.
    // Alphabetical order breaks ties, making the result deterministic.
    remainders.sort((a, b) {
      final comparison = b.value.compareTo(a.value);

      if (comparison != 0) {
        return comparison;
      }

      return a.key.compareTo(b.key);
    });

    final remainingPaise = totalPaise - allocatedPaise;

    for (int i = 0; i < remainingPaise; i++) {
      final member = remainders[i].key;
      shares[member] = shares[member]! + 1;
    }

    if (shares.values.any((share) => share <= 0)) {
      throw ArgumentError(
        'The amount is too small for the selected percentages',
      );
    }

    return {for (final member in members) member: shares[member]!};
  }
}
