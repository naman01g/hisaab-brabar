import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/group.dart';
import '../../domain/models/group_invitation.dart';

class GroupInvitationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _invitations(String groupId) {
    return _db.collection('groups').doc(groupId).collection('invitations');
  }

  // CREATE INVITATION
  Future<GroupInvitation> createInvitation(Group group) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final groupRef = _db.collection('groups').doc(group.id);
    final groupSnapshot = await groupRef.get();

    if (!groupSnapshot.exists) {
      throw StateError('Group not found.');
    }

    final groupData = groupSnapshot.data()!;
    final memberIds = groupData['memberIds'];

    if (memberIds is! List || !memberIds.contains(user.uid)) {
      throw StateError('Only group members can invite others.');
    }

    final groupName = groupData['name'];

    if (groupName is! String) {
      throw StateError('Invalid group information.');
    }

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: 7));

    final invitationRef = _invitations(group.id).doc();

    await invitationRef.set({
      'groupId': group.id,
      'groupName': groupName,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': 'pending',
      'acceptedBy': null,
      'acceptedAt': null,
    });

    return GroupInvitation(
      id: invitationRef.id,
      groupId: group.id,
      groupName: groupName,
      createdBy: user.uid,
      status: 'pending',
      createdAt: now,
      expiresAt: expiresAt,
    );
  }

  // GET INVITATION
  Future<GroupInvitation> getInvitation({
    required String groupId,
    required String invitationId,
  }) async {
    if (_auth.currentUser == null) {
      throw StateError('Please sign in first.');
    }

    final document = await _invitations(groupId)
        .doc(invitationId)
        .get(const GetOptions(source: Source.server));

    if (!document.exists) {
      throw StateError('Invitation not found.');
    }

    final invitation = GroupInvitation.fromDocument(document);

    if (!invitation.isPending) {
      throw StateError('Invitation has expired or was already used.');
    }

    return invitation;
  }

  // ACCEPT INVITATION
  Future<void> acceptInvitation({
    required String groupId,
    required String invitationId,
    required String displayName,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before joining a group.');
    }

    final cleanName = displayName.trim();

    if (cleanName.length < 2 || cleanName.length > 40) {
      throw ArgumentError('Display name must contain 2 to 40 characters.');
    }

    // Verify that the invitation exists and is still valid.
    await getInvitation(groupId: groupId, invitationId: invitationId);

    final groupRef = _db.collection('groups').doc(groupId);

    final invitationRef = _invitations(groupId).doc(invitationId);

    final claimRef = groupRef.collection('joinClaims').doc(user.uid);

    final batch = _db.batch();

    // 1. Accept invitation.
    batch.update(invitationRef, {
      'status': 'accepted',
      'acceptedBy': user.uid,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // 2. Create one-time join claim.
    batch.set(claimRef, {
      'userId': user.uid,
      'displayName': cleanName,
      'invitationId': invitationId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Add user to group.
    batch.update(groupRef, {
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'members': FieldValue.arrayUnion([
        {'userId': user.uid, 'displayName': cleanName, 'role': 'member'},
      ]),
    });

    await batch.commit();
  }
}
