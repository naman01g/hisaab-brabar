import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/expense.dart';

class ExpenseRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _expenses(String groupId) {
    return _db.collection('groups').doc(groupId).collection('expenses');
  }

  // Save an expense inside its group.
  Future<void> createExpense(Expense expense) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before saving an expense.');
    }

    if (expense.createdBy != user.uid) {
      throw StateError('You cannot create an expense for another user.');
    }

    // Verify group membership before attempting the write.
    final groupRef = _db.collection('groups').doc(expense.groupId);
    final groupSnapshot = await groupRef.get();

    if (!groupSnapshot.exists) {
      throw StateError('The selected group no longer exists.');
    }

    final groupData = groupSnapshot.data()!;
    final memberIds = List<String>.from(groupData['memberIds'] ?? []);

    if (!memberIds.contains(user.uid)) {
      throw StateError('You are not a member of this group.');
    }

    if (!memberIds.contains(expense.paidByUserId)) {
      throw StateError('The selected payer is not a group member.');
    }

    if (!memberIds.toSet().containsAll(expense.sharesPaise.keys)) {
      throw StateError('An expense participant is not a group member.');
    }

    final allocated = expense.sharesPaise.values.fold<int>(
      0,
      (total, share) => total + share,
    );

    if (allocated != expense.amountPaise) {
      throw ArgumentError('Expense shares do not match the total.');
    }

    await _expenses(expense.groupId).doc(expense.id).set({
      'title': expense.title,
      'category': expense.category,
      'groupName': expense.groupName,
      'createdBy': user.uid,
      'paidByUserId': expense.paidByUserId,
      'paidByName': expense.paidByName,
      'amountPaise': expense.amountPaise,
      'participantIds': expense.sharesPaise.keys.toList(),
      'participantNames': expense.participantNames,
      'sharesPaise': expense.sharesPaise,
      'splitType': expense.splitType.name,
      'currencyCode': 'INR',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Listen to expenses belonging to one group.
  Stream<List<Expense>> watchGroupExpenses(String groupId) {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.error(StateError('Please sign in to view expenses.'));
    }

    return _expenses(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(_fromDocument).toList();
        });
  }

  Expense _fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();

    final rawShares = Map<String, dynamic>.from(data['sharesPaise'] as Map);

    final rawNames = Map<String, dynamic>.from(data['participantNames'] as Map);

    final rawSplitType = data['splitType'] as String? ?? 'equal';

    final splitType = SplitType.values.firstWhere(
      (value) => value.name == rawSplitType,
      orElse: () => SplitType.equal,
    );

    return Expense(
      id: document.id,
      groupId: document.reference.parent.parent!.id,
      groupName: data['groupName'] as String? ?? '',
      title: data['title'] as String,
      category: data['category'] as String,
      createdBy: data['createdBy'] as String,
      paidByUserId: data['paidByUserId'] as String,
      paidByName: data['paidByName'] as String,
      amountPaise: data['amountPaise'] as int,
      sharesPaise: rawShares.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      participantNames: rawNames.map(
        (key, value) => MapEntry(key, value as String),
      ),
      splitType: splitType,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
