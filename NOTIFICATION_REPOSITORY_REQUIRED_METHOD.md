# Required method for `NotificationRepository`

The Settle Now screen calls this existing repository method. Verify that your project's `notification_repository.dart` contains the equivalent implementation. The critical requirement is that the notification document ID equals `settlementRef.id`, and both documents are created in the same batch.

```dart
Future<String> sendPaymentConfirmationRequest({
  required Group group,
  required GroupMember recipient,
  required int amountPaise,
  String message = '',
}) async {
  final user = _auth.currentUser;
  if (user == null) throw StateError('Please sign in first.');
  if (amountPaise <= 0) throw ArgumentError('Payment amount must be positive.');

  final sender = _findMember(group, user.uid);
  if (sender == null) throw StateError('You are not a member of this group.');
  _validateRecipient(group, recipient, user.uid);
  _validateMemberName(sender.displayName);
  _validateMemberName(recipient.displayName);

  final cleanMessage = message.trim();
  if (cleanMessage.length > 200) {
    throw ArgumentError('Message cannot exceed 200 characters.');
  }

  final groupRef = _db.collection('groups').doc(group.id);
  final settlementRef = groupRef.collection('settlements').doc();

  // CRITICAL: notification ID must equal the settlement ID.
  final notificationRef = _db
      .collection('users')
      .doc(recipient.userId)
      .collection('notifications')
      .doc(settlementRef.id);

  final batch = _db.batch();
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
```

This method assumes the repository already has `_auth`, `_db`, `_findMember`, `_validateRecipient`, and `_validateMemberName` helpers from the current notification repository implementation. Do not add a second repository class; merge the method into the existing class if it is missing.
