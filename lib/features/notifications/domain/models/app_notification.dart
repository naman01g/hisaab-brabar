enum AppNotificationStatus {
  unread,
  read,
  dismissed,
  settled,
  accepted,
  rejected,
}

class AppNotification {
  final String id;
  final String groupId;
  final String groupName;
  final String fromUid;
  final String fromName;
  final String message;
  final AppNotificationStatus status;
  final DateTime createdAt;

  final String type;
  final String? settlementId;
  final int? amountPaise;
  final String? invitationId;

  const AppNotification({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.fromUid,
    required this.fromName,
    required this.message,
    required this.status,
    required this.createdAt,
    this.type = 'settle_up',
    this.settlementId,
    this.amountPaise,
    this.invitationId,
  });

  bool get isPaymentConfirmation => type == 'settlement_confirmation';

  bool get isGroupInvitation => type == 'group_invitation';
}
