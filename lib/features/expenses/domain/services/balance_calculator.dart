import '../../domain/models/expense.dart';
import '../../../groups/domain/models/group.dart';

/// A member's net financial position.
///
/// Positive balance = this member should receive money.
/// Negative balance = this member owes money.
/// Zero balance = nothing to settle.
class MemberBalance {
  final String userId;
  final String displayName;
  final int netBalancePaise;

  const MemberBalance({
    required this.userId,
    required this.displayName,
    required this.netBalancePaise,
  });

  bool get shouldReceive => netBalancePaise > 0;

  bool get shouldPay => netBalancePaise < 0;

  bool get isSettled => netBalancePaise == 0;
}

/// A suggested payment from one member to another.
class SettlementSuggestion {
  final String fromUserId;
  final String fromName;
  final String toUserId;
  final String toName;
  final int amountPaise;

  const SettlementSuggestion({
    required this.fromUserId,
    required this.fromName,
    required this.toUserId,
    required this.toName,
    required this.amountPaise,
  });
}

/// Complete balance calculation for one group.
class GroupBalanceSummary {
  final List<MemberBalance> balances;
  final List<SettlementSuggestion> settlements;
  final int totalExpensesPaise;

  GroupBalanceSummary({
    required List<MemberBalance> balances,
    required List<SettlementSuggestion> settlements,
    required this.totalExpensesPaise,
  }) : balances = List.unmodifiable(balances),
       settlements = List.unmodifiable(settlements);
}

class BalanceCalculator {
  BalanceCalculator._();

  /// Calculates balances and simplified settlements for a group.
  static GroupBalanceSummary calculate({
    required Group group,
    required List<Expense> expenses,
  }) {
    // Start every group member with a zero balance.
    final netBalances = <String, int>{};
    final memberNames = <String, String>{};

    for (final member in group.members) {
      if (netBalances.containsKey(member.userId)) {
        throw StateError('Duplicate member ID: ${member.userId}');
      }

      netBalances[member.userId] = 0;
      memberNames[member.userId] = member.displayName;
    }

    var totalExpensesPaise = 0;

    // Process every expense.
    for (final expense in expenses) {
      if (expense.groupId != group.id) {
        throw StateError('Expense ${expense.id} belongs to another group.');
      }

      if (!netBalances.containsKey(expense.paidByUserId)) {
        throw StateError('Expense payer is not a group member.');
      }

      final allocated = expense.sharesPaise.values.fold<int>(
        0,
        (total, share) => total + share,
      );

      if (allocated != expense.amountPaise) {
        throw StateError('Expense shares do not match the total.');
      }

      // Credit the person who paid the full amount.
      netBalances[expense.paidByUserId] =
          netBalances[expense.paidByUserId]! + expense.amountPaise;

      // Debit every participant for their share.
      for (final entry in expense.sharesPaise.entries) {
        if (!netBalances.containsKey(entry.key)) {
          throw StateError('Expense participant is not a group member.');
        }

        if (entry.value <= 0) {
          throw StateError('Invalid expense share.');
        }

        netBalances[entry.key] = netBalances[entry.key]! - entry.value;
      }

      totalExpensesPaise += expense.amountPaise;
    }

    // The sum of all net balances must always be zero.
    final balanceTotal = netBalances.values.fold<int>(
      0,
      (total, balance) => total + balance,
    );

    if (balanceTotal != 0) {
      throw StateError('Group balances are inconsistent.');
    }

    final balances = group.members.map((member) {
      return MemberBalance(
        userId: member.userId,
        displayName: member.displayName,
        netBalancePaise: netBalances[member.userId]!,
      );
    }).toList();

    final settlements = _simplifySettlements(balances);

    return GroupBalanceSummary(
      balances: balances,
      settlements: settlements,
      totalExpensesPaise: totalExpensesPaise,
    );
  }

  /// Reduces multiple debts into a smaller set of payments.
  ///
  /// Example:
  /// A owes ₹100 to C.
  /// B owes ₹200 to C.
  ///
  /// Result:
  /// A pays C ₹100.
  /// B pays C ₹200.
  static List<SettlementSuggestion> _simplifySettlements(
    List<MemberBalance> balances,
  ) {
    final debtors = <_PartyBalance>[];
    final creditors = <_PartyBalance>[];

    for (final balance in balances) {
      if (balance.netBalancePaise < 0) {
        debtors.add(
          _PartyBalance(
            userId: balance.userId,
            name: balance.displayName,
            remainingPaise: -balance.netBalancePaise,
          ),
        );
      } else if (balance.netBalancePaise > 0) {
        creditors.add(
          _PartyBalance(
            userId: balance.userId,
            name: balance.displayName,
            remainingPaise: balance.netBalancePaise,
          ),
        );
      }
    }

    // Process larger debts and credits first.
    debtors.sort((a, b) => b.remainingPaise.compareTo(a.remainingPaise));

    creditors.sort((a, b) => b.remainingPaise.compareTo(a.remainingPaise));

    final settlements = <SettlementSuggestion>[];

    var debtorIndex = 0;
    var creditorIndex = 0;

    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];

      final payment = debtor.remainingPaise < creditor.remainingPaise
          ? debtor.remainingPaise
          : creditor.remainingPaise;

      settlements.add(
        SettlementSuggestion(
          fromUserId: debtor.userId,
          fromName: debtor.name,
          toUserId: creditor.userId,
          toName: creditor.name,
          amountPaise: payment,
        ),
      );

      debtor.remainingPaise -= payment;
      creditor.remainingPaise -= payment;

      if (debtor.remainingPaise == 0) {
        debtorIndex++;
      }

      if (creditor.remainingPaise == 0) {
        creditorIndex++;
      }
    }

    return settlements;
  }
}

class _PartyBalance {
  final String userId;
  final String name;
  int remainingPaise;

  _PartyBalance({
    required this.userId,
    required this.name,
    required this.remainingPaise,
  });
}
