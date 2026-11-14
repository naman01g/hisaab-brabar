import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../notifications/domain/models/app_notification.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_invitation.dart';

class GroupInvitationRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Firestore rules require expiresAt <= server time + 7 days. The phone's
  // clock can run slightly ahead of the server, so keep a 5-minute safety
  // margin below the 7-day limit.
  static const Duration _invitationLifetime = Duration(
    days: 6,
    hours: 23,
    minutes: 55,
  );

  GroupInvitationRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _invitations(String groupId) {
    return _db.collection('groups').doc(groupId).collection('invitations');
  }

  CollectionReference<Map<String, dynamic>> _notifications(String userId) {
    return _db.collection('users').doc(userId).collection('notifications');
  }

  // --------------------------------------------------
  // CREATE GENERAL/LINK INVITATION
  // --------------------------------------------------

  Future<GroupInvitation> createInvitation(Group group) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');

    final groupRef = _db.collection('groups').doc(group.id);
    final groupSnapshot = await groupRef.get();
    if (!groupSnapshot.exists) throw StateError('Group not found.');

    final groupData = groupSnapshot.data()!;
    final memberIds = groupData['memberIds'];
    if (memberIds is! List || !memberIds.contains(user.uid)) {
      throw StateError('Only group members can invite others.');
    }

    final groupName = groupData['name'];
    if (groupName is! String) {
      throw StateError('Invalid group information.');
    }
    if (memberIds.length >= 50) {
      throw StateError('Group has reached its 50-member limit.');
    }

    final now = DateTime.now();
    final expiresAt = now.add(_invitationLifetime);
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
      'invitedToUid': null,
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

  // --------------------------------------------------
  // CREATE TARGETED INVITATION + RECIPIENT NOTIFICATION
  // --------------------------------------------------

  Future<String> sendDirectInvitation({
    required Group group,
    required String recipientUid,
    required String recipientName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');
    if (recipientUid.trim().isEmpty || recipientUid == user.uid) {
      throw ArgumentError('Choose another person to invite.');
    }

    final cleanRecipientName = recipientName.trim();
    if (cleanRecipientName.length < 2 || cleanRecipientName.length > 40) {
      throw ArgumentError('Recipient name must contain 2 to 40 characters.');
    }

    final groupRef = _db.collection('groups').doc(group.id);
    final groupSnapshot = await groupRef.get();
    if (!groupSnapshot.exists) throw StateError('Group not found.');

    final groupData = groupSnapshot.data()!;
    final memberIds = groupData['memberIds'];
    final members = groupData['members'];
    final groupName = groupData['name'];

    if (memberIds is! List || !memberIds.contains(user.uid)) {
      throw StateError('Only group members can invite others.');
    }
    if (memberIds.contains(recipientUid)) {
      throw StateError('This person is already a group member.');
    }
    if (memberIds.length >= 50) {
      throw StateError('Group has reached its 50-member limit.');
    }
    if (groupName is! String || members is! List) {
      throw StateError('Invalid group information.');
    }

    String? senderName;
    for (final member in members) {
      if (member is Map &&
          member['userId'] == user.uid &&
          member['displayName'] is String) {
        senderName = (member['displayName'] as String).trim();
        break;
      }
    }
    if (senderName == null || senderName.length < 2 || senderName.length > 40) {
      throw StateError('Your group member profile is invalid.');
    }

    // Recheck the recipient is still discoverable at send time.
    final recipientProfile = await _db
        .collection('profiles')
        .doc(recipientUid)
        .get();
    final profileData = recipientProfile.data();
    if (!recipientProfile.exists ||
        profileData?['discoverable'] != true ||
        profileData?['displayName'] != cleanRecipientName) {
      throw StateError('This profile is no longer available for invitations.');
    }

    final expiresAt = DateTime.now().add(_invitationLifetime);
    final invitationRef = _invitations(group.id).doc();
    final notificationRef = _notifications(recipientUid).doc(invitationRef.id);

    final batch = _db.batch();
    batch.set(invitationRef, {
      'groupId': group.id,
      'groupName': groupName,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': 'pending',
      'acceptedBy': null,
      'acceptedAt': null,
      'invitedToUid': recipientUid,
    });

    batch.set(notificationRef, {
      'type': 'group_invitation',
      'invitationId': invitationRef.id,
      'groupId': group.id,
      'groupName': groupName,
      'fromUid': user.uid,
      'fromName': senderName,
      'toUid': recipientUid,
      'toName': cleanRecipientName,
      'message': 'invited you to join $groupName.',
      'status': 'unread',
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });

    await batch.commit();
    return invitationRef.id;
  }

  // --------------------------------------------------
  // GET INVITATION
  // --------------------------------------------------

  Future<GroupInvitation> getInvitation({
    required String groupId,
    required String invitationId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');

    final document = await _invitations(groupId)
        .doc(invitationId)
        .get(const GetOptions(source: Source.server));

    if (!document.exists) throw StateError('Invitation not found.');

    final data = document.data()!;
    final invitedToUid = data['invitedToUid'];
    if (invitedToUid != null && invitedToUid != user.uid) {
      throw StateError('This invitation is addressed to another user.');
    }

    final invitation = GroupInvitation.fromDocument(document);
    if (!invitation.isPending) {
      throw StateError('Invitation has expired or was already used.');
    }
    return invitation;
  }

  // --------------------------------------------------
  // ACCEPT GENERAL/LINK INVITATION
  // --------------------------------------------------

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

    await getInvitation(groupId: groupId, invitationId: invitationId);

    final groupRef = _db.collection('groups').doc(groupId);
    final invitationRef = _invitations(groupId).doc(invitationId);
    final claimRef = groupRef.collection('joinClaims').doc(user.uid);

    final batch = _db.batch();
    batch.update(invitationRef, {
      'status': 'accepted',
      'acceptedBy': user.uid,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    batch.set(claimRef, {
      'userId': user.uid,
      'displayName': cleanName,
      'invitationId': invitationId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(groupRef, {
      'memberIds': FieldValue.arrayUnion([user.uid]),
      'members': FieldValue.arrayUnion([
        {'userId': user.uid, 'displayName': cleanName, 'role': 'member'},
      ]),
    });
    await batch.commit();
  }

  // --------------------------------------------------
  // ACCEPT OR REJECT TARGETED IN-APP INVITATION
  // --------------------------------------------------

  Future<void> respondToGroupInvitation({
    required AppNotification notification,
    required bool accept,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');

    final invitationId = notification.invitationId;
    if (!notification.isGroupInvitation ||
        invitationId == null ||
        invitationId != notification.id) {
      throw ArgumentError('Invalid group invitation notification.');
    }
    if (notification.status != AppNotificationStatus.unread &&
        notification.status != AppNotificationStatus.read) {
      throw StateError('This invitation has already been answered.');
    }

    final invitationRef = _invitations(notification.groupId).doc(invitationId);
    final notificationRef = _notifications(user.uid).doc(notification.id);

    final invitationSnapshot = await invitationRef.get(
      const GetOptions(source: Source.server),
    );
    if (!invitationSnapshot.exists) {
      throw StateError('Invitation no longer exists.');
    }

    final invitation = invitationSnapshot.data()!;
    if (invitation['invitedToUid'] != user.uid) {
      throw StateError('This invitation belongs to another user.');
    }
    if (invitation['status'] != 'pending') {
      throw StateError('This invitation has already been resolved.');
    }
    final expiry = invitation['expiresAt'];
    if (expiry is! Timestamp || !expiry.toDate().isAfter(DateTime.now())) {
      throw StateError('This invitation has expired.');
    }

    // Ensure the recipient's inbox document exists and points to this invite.
    final notificationSnapshot = await notificationRef.get(
      const GetOptions(source: Source.server),
    );
    final notificationData = notificationSnapshot.data();
    if (!notificationSnapshot.exists ||
        notificationData?['type'] != 'group_invitation' ||
        notificationData?['invitationId'] != invitationId ||
        notificationData?['toUid'] != user.uid) {
      throw StateError('Invitation notification is no longer valid.');
    }

    final batch = _db.batch();

    if (accept) {
      final profileSnapshot = await _db
          .collection('profiles')
          .doc(user.uid)
          .get();
      final profileName =
          profileSnapshot.data()?['displayName'] as String? ??
          user.displayName ??
          '';
      final cleanName = profileName.trim();
      if (cleanName.length < 2 || cleanName.length > 40) {
        throw StateError(
          'Please complete your profile name before joining this group.',
        );
      }

      final groupRef = _db.collection('groups').doc(notification.groupId);
      final claimRef = groupRef.collection('joinClaims').doc(user.uid);

      // All four writes are committed atomically. Security rules verify
      // the invitation, one-time claim, group membership and notification.
      batch.update(invitationRef, {
        'status': 'accepted',
        'acceptedBy': user.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      batch.set(claimRef, {
        'userId': user.uid,
        'displayName': cleanName,
        'invitationId': invitationId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(groupRef, {
        'memberIds': FieldValue.arrayUnion([user.uid]),
        'members': FieldValue.arrayUnion([
          {'userId': user.uid, 'displayName': cleanName, 'role': 'member'},
        ]),
      });
      batch.update(notificationRef, {
        'status': 'accepted',
        'readAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(invitationRef, {
        'status': 'rejected',
        'rejectedBy': user.uid,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      batch.update(notificationRef, {
        'status': 'rejected',
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
