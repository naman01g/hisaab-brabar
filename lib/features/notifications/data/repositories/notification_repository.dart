import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../groups/domain/models/group.dart';
import '../../../groups/domain/models/group_member.dart';
import '../../domain/models/app_notification.dart';

class NotificationRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  NotificationRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _myNotifications() {
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      throw StateError('Please sign in first.');
    }

    return _db.collection('users').doc(uid).collection('notifications');
  }

  // Existing ordinary settle-up reminder.
  // Keep its random notification ID.
  Future<void> sendSettleUpRequest({
    required Group group,
    required GroupMember recipient,
    String message = '',
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final sender = _findMember(group, user.uid);

    if (sender == null) {
      throw StateError('You are not a member of this group.');
    }

    _validateRecipient(group, recipient, user.uid);

    final cleanMessage = message.trim();

    if (cleanMessage.length > 200) {
      throw ArgumentError('Message cannot exceed 200 characters.');
    }

    await _db
        .collection('users')
        .doc(recipient.userId)
        .collection('notifications')
        .add({
          'type': 'settle_up',
          'groupId': group.id,
          'groupName': group.name,
          'fromUid': user.uid,
          'fromName': sender.displayName,
          'toUid': recipient.userId,
          'toName': recipient.displayName,
          'message': cleanMessage,
          'status': 'unread',
          'createdAt': FieldValue.serverTimestamp(),
          'readAt': null,
        });
  }

  // Create a settlement and matching notification atomically.
  Future<String> sendPaymentConfirmationRequest({
    required Group group,
    required GroupMember recipient,
    required int amountPaise,
    String message = '',
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    if (amountPaise <= 0) {
      throw ArgumentError('Payment amount must be positive.');
    }

    final sender = _findMember(group, user.uid);

    if (sender == null) {
      throw StateError('You are not a member of this group.');
    }

    _validateRecipient(group, recipient, user.uid);

    _validateMemberName(sender.displayName);
    _validateMemberName(recipient.displayName);

    final cleanMessage = message.trim();

    if (cleanMessage.length > 200) {
      throw ArgumentError('Message cannot exceed 200 characters.');
    }

    final groupRef = _db.collection('groups').doc(group.id);

    // Generate settlement ID first.
    final settlementRef = groupRef.collection('settlements').doc();

    // IMPORTANT:
    // Notification document ID MUST equal settlement ID.
    final notificationRef = _db
        .collection('users')
        .doc(recipient.userId)
        .collection('notifications')
        .doc(settlementRef.id);

    final batch = _db.batch();

    // 1. Create pending settlement.
    batch.set(settlementRef, {
      'groupId': group.id,
      'groupName': group.name,
      'fromUid': user.uid,
      'fromName': sender.displayName,
      'toUid': recipient.userId,
      'toName': recipient.displayName,
      'amountPaise': amountPaise,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
    });

    // 2. Create matching recipient notification.
    batch.set(notificationRef, {
      'type': 'settlement_confirmation',
      'settlementId': settlementRef.id,
      'amountPaise': amountPaise,
      'groupId': group.id,
      'groupName': group.name,
      'fromUid': user.uid,
      'fromName': sender.displayName,
      'toUid': recipient.userId,
      'toName': recipient.displayName,
      'message': cleanMessage,
      'status': 'unread',
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });

    await batch.commit();

    return settlementRef.id;
  }

  // Recipient confirms or rejects the payment.
  Future<void> respondToSettlement({
    required AppNotification notification,
    required bool confirm,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final settlementId = notification.settlementId;

    if (!notification.isPaymentConfirmation ||
        settlementId == null ||
        settlementId != notification.id) {
      throw ArgumentError('Invalid settlement notification.');
    }

    final settlementRef = _db
        .collection('groups')
        .doc(notification.groupId)
        .collection('settlements')
        .doc(settlementId);

    final notificationRef = _myNotifications().doc(notification.id);

    final batch = _db.batch();

    // 1. Resolve settlement.
    batch.update(settlementRef, {
      'status': confirm ? 'confirmed' : 'rejected',
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    // 2. Resolve matching notification.
    batch.update(notificationRef, {
      'status': confirm ? 'settled' : 'dismissed',
      'readAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Listen to notifications.
  Stream<List<AppNotification>> watchMyNotifications() {
    return _myNotifications()
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final timestamp = data['createdAt'] as Timestamp?;

            return AppNotification(
              id: doc.id,
              type: data['type'] as String? ?? 'settle_up',
              settlementId: data['settlementId'] as String?,
              amountPaise: (data['amountPaise'] as num?)?.toInt(),
              groupId: data['groupId'] as String? ?? '',
              groupName: data['groupName'] as String? ?? 'Group',
              fromUid: data['fromUid'] as String? ?? '',
              fromName: data['fromName'] as String? ?? 'Member',
              message: data['message'] as String? ?? '',
              status: AppNotificationStatus.values.firstWhere(
                (value) => value.name == data['status'],
                orElse: () => AppNotificationStatus.unread,
              ),
              createdAt: timestamp?.toDate() ?? DateTime.now(),
            );
          }).toList();
        });
  }

  // Watch unread notification count.
  Stream<int> watchUnreadCount() {
    return _myNotifications()
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Update ordinary notification status.
  Future<void> updateStatus(
    String notificationId,
    AppNotificationStatus status,
  ) async {
    if (status == AppNotificationStatus.unread) {
      throw ArgumentError('Invalid notification status.');
    }

    await _myNotifications().doc(notificationId).update({
      'status': status.name,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  GroupMember? _findMember(Group group, String uid) {
    for (final member in group.members) {
      if (member.userId == uid) {
        return member;
      }
    }

    return null;
  }

  void _validateRecipient(
    Group group,
    GroupMember recipient,
    String currentUid,
  ) {
    if (recipient.userId == currentUid) {
      throw ArgumentError('You cannot send a request to yourself.');
    }

    if (!group.members.any((member) => member.userId == recipient.userId)) {
      throw StateError('Recipient is not a group member.');
    }
  }

  void _validateMemberName(String name) {
    final cleanName = name.trim();

    if (cleanName.length < 2 || cleanName.length > 40) {
      throw ArgumentError('Member name must contain 2 to 40 characters.');
    }
  }
}
