enum AppNotificationStatus { unread, read, dismissed, settled }

class AppNotification {
  final String id;
  final String groupId;
  final String groupName;
  final String fromUid;
  final String fromName;
  final String message;
  final AppNotificationStatus status;
  final DateTime createdAt;

  // Additional fields for payment confirmations.
  final String type;
  final String? settlementId;
  final int? amountPaise;

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
  });

  bool get isPaymentConfirmation => type == 'settlement_confirmation';
}
