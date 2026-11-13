import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/group_settlement.dart';

class GroupSettlementRepository {
  final FirebaseFirestore _db;

  GroupSettlementRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _settlements(String groupId) {
    return _db.collection('groups').doc(groupId).collection('settlements');
  }

  Stream<List<GroupSettlement>> watchGroupSettlements(String groupId) {
    return _settlements(groupId).snapshots().map((snapshot) {
      final settlements = snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['createdAt'] as Timestamp?;

        return GroupSettlement(
          id: doc.id,
          groupId: data['groupId'] as String? ?? groupId,
          fromUid: data['fromUid'] as String? ?? '',
          fromName: data['fromName'] as String? ?? 'Member',
          toUid: data['toUid'] as String? ?? '',
          toName: data['toName'] as String? ?? 'Member',
          amountPaise: (data['amountPaise'] as num?)?.toInt() ?? 0,
          status: data['status'] as String? ?? 'pending',
          createdAt:
              timestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      }).toList();

      settlements.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return settlements;
    });
  }
}
