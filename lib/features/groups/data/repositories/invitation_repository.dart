import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/group_invitation.dart';

class InvitationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  DocumentReference<Map<String, dynamic>> _invitationRef(
    String groupId,
    String invitationId,
  ) {
    return _groups.doc(groupId).collection('invitations').doc(invitationId);
  }

  // Creates a new invitation that expires after seven days.
  Future<GroupInvitation> createInvitation({required String groupId}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final groupRef = _groups.doc(groupId);
    final groupDocument = await groupRef.get();

    if (!groupDocument.exists) {
      throw StateError('Group not found.');
    }

    final groupData = groupDocument.data()!;
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

    final invitationDocument = groupRef.collection('invitations').doc();

    await invitationDocument.set({
      'groupId': groupId,
      'groupName': groupName,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': 'pending',
      'acceptedBy': null,
      'acceptedAt': null,
    });

    return GroupInvitation(
      id: invitationDocument.id,
      groupId: groupId,
      groupName: groupName,
      createdBy: user.uid,
      status: 'pending',
      createdAt: now,
      expiresAt: expiresAt,
    );
  }

  // Loads an invitation using its group ID and invitation ID.
  Future<GroupInvitation> getInvitation({
    required String groupId,
    required String invitationId,
  }) async {
    final document = await _invitationRef(groupId, invitationId).get();

    if (!document.exists) {
      throw StateError('Invitation not found, expired, or unavailable.');
    }

    final invitation = GroupInvitation.fromDocument(document);

    if (!invitation.isPending) {
      throw StateError('This invitation has expired or was used.');
    }

    return invitation;
  }

  // Accepts an invitation and adds the user to the group.
  // All three writes must succeed together.
  Future<void> acceptInvitation({
    required String groupId,
    required String invitationId,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before joining a group.');
    }

    final invitation = await getInvitation(
      groupId: groupId,
      invitationId: invitationId,
    );

    if (invitation.groupId != groupId) {
      throw StateError('Invalid invitation.');
    }

    final displayName = _getDisplayName(user);

    final groupRef = _groups.doc(groupId);
    final invitationRef = _invitationRef(groupId, invitationId);
    final claimRef = groupRef.collection('joinClaims').doc(user.uid);

    final batch = _db.batch();

    // 1. Mark the invitation as accepted.
    batch.update(invitationRef, {
      'status': 'accepted',
      'acceptedBy': user.uid,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // 2. Create the one-time join claim.
    batch.set(claimRef, {
      'userId': user.uid,
      'displayName': displayName,
      'invitationId': invitationId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3. Add the user to group membership.
    batch.update(groupRef, {
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'members': FieldValue.arrayUnion([
        {'userId': user.uid, 'displayName': displayName, 'role': 'member'},
      ]),
    });

    await batch.commit();
  }

  String _getDisplayName(User user) {
    String name = (user.displayName ?? '').trim();

    if (name.isEmpty) {
      name = (user.email?.split('@').first ?? '').trim();
    }

    if (name.length < 2) {
      name = 'Member';
    }

    if (name.length > 40) {
      name = name.substring(0, 40);
    }

    return name;
  }
}
