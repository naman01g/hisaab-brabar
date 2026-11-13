class GroupSettlement {
  final String id;
  final String groupId;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final int amountPaise;
  final String status;
  final DateTime createdAt;

  const GroupSettlement({
    required this.id,
    required this.groupId,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.amountPaise,
    required this.status,
    required this.createdAt,
  });

  bool get isConfirmed => status == 'confirmed';
}
