import '../../domain/models/expense.dart';
import '../models/group_settlement.dart';
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

  /// Calculates current balances using expenses and confirmed payments.
  ///
  /// Pending or rejected payment requests do not affect balances.
  static GroupBalanceSummary calculate({
    required Group group,
    required List<Expense> expenses,
    List<GroupSettlement> settlements = const [],
  }) {
    final netBalances = <String, int>{};
    for (final member in group.members) {
      if (netBalances.containsKey(member.userId)) {
        throw StateError('Duplicate member ID: ${member.userId}');
      }

      netBalances[member.userId] = 0;
    }

    var totalExpensesPaise = 0;

    // Process all expenses.
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

    // Only confirmed payments change the ledger.
    for (final settlement in settlements) {
      if (settlement.groupId != group.id) {
        throw StateError(
          'Settlement ${settlement.id} belongs to another group.',
        );
      }

      if (!settlement.isConfirmed) continue;

      if (settlement.amountPaise <= 0) {
        throw StateError('Invalid confirmed settlement amount.');
      }

      if (settlement.fromUid == settlement.toUid) {
        throw StateError('A member cannot settle with themselves.');
      }

      if (!netBalances.containsKey(settlement.fromUid) ||
          !netBalances.containsKey(settlement.toUid)) {
        throw StateError('Settlement members must belong to this group.');
      }

      // Payer has paid money: reduce the amount they owe.
      netBalances[settlement.fromUid] =
          netBalances[settlement.fromUid]! + settlement.amountPaise;

      // Recipient has received money: reduce the amount they should receive.
      netBalances[settlement.toUid] =
          netBalances[settlement.toUid]! - settlement.amountPaise;
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

    final suggestedSettlements = _simplifySettlements(balances);

    return GroupBalanceSummary(
      balances: balances,
      settlements: suggestedSettlements,
      totalExpensesPaise: totalExpensesPaise,
    );
  }

  /// Reduces multiple debts into a smaller set of payments.
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

    debtors.sort((a, b) => b.remainingPaise.compareTo(a.remainingPaise));
    creditors.sort((a, b) => b.remainingPaise.compareTo(a.remainingPaise));

    final result = <SettlementSuggestion>[];
    var debtorIndex = 0;
    var creditorIndex = 0;

    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];

      final payment = debtor.remainingPaise < creditor.remainingPaise
          ? debtor.remainingPaise
          : creditor.remainingPaise;

      result.add(
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

      if (debtor.remainingPaise == 0) debtorIndex++;
      if (creditor.remainingPaise == 0) creditorIndex++;
    }

    return result;
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
