import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';

class GroupRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  // Get groups belonging to the signed-in user.
  Stream<List<Group>> watchMyGroups() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.error(StateError('Please sign in to view groups.'));
    }

    return _groups.where('memberIds', arrayContains: user.uid).snapshots().map((
      snapshot,
    ) {
      final groups = snapshot.docs.map(_fromDocument).toList();

      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return groups;
    });
  }

  // Create a group with the signed-in user as its owner.
  Future<Group> createGroup({
    required String name,
    required String category,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('You must sign in before creating a group.');
    }

    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Group name cannot be empty.');
    }

    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'Member');

    final document = _groups.doc();

    // Firestore assigns the actual creation time on the server.
    await document.set({
      'name': cleanName,
      'category': category,
      'createdBy': user.uid,
      'currencyCode': 'INR',
      'createdAt': FieldValue.serverTimestamp(),
      'memberIds': [user.uid],
      'members': [
        {'userId': user.uid, 'displayName': displayName, 'role': 'owner'},
      ],
    });

    return Group(
      id: document.id,
      name: cleanName,
      category: category,
      createdBy: user.uid,
      createdAt: DateTime.now(),
      currencyCode: 'INR',
      members: [
        GroupMember(
          userId: user.uid,
          displayName: displayName,
          role: GroupRole.owner,
        ),
      ],
    );
  }

  // Convert a Firestore document into a Group object.
  Group _fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();

    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final rawMembers = data['members'] as List<dynamic>? ?? [];

    final members = rawMembers.map((rawMember) {
      final member = Map<String, dynamic>.from(rawMember as Map);

      final roleName = member['role'] as String? ?? 'member';

      final role = GroupRole.values.firstWhere(
        (item) => item.name == roleName,
        orElse: () => GroupRole.member,
      );

      return GroupMember(
        userId: member['userId'] as String,
        displayName: member['displayName'] as String,
        role: role,
        joinedAt: createdAt,
      );
    }).toList();

    return Group(
      id: document.id,
      name: data['name'] as String,
      category: data['category'] as String,
      createdBy: data['createdBy'] as String,
      createdAt: createdAt,
      currencyCode: data['currencyCode'] as String? ?? 'INR',
      members: members,
    );
  }
}
