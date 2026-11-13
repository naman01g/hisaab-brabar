import 'package:cloud_firestore/cloud_firestore.dart';

class GroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final String createdBy;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? acceptedBy;
  final DateTime? acceptedAt;

  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.createdBy,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedBy,
    this.acceptedAt,
  });

  String get invitationCode => '$groupId|$id';

  String get shareLink => Uri(
    scheme: 'hisaabbrabar',
    host: 'join',
    queryParameters: {'groupId': groupId, 'inviteId': id},
  ).toString();

  bool get isPending =>
      status == 'pending' && expiresAt.isAfter(DateTime.now());

  // Parse a copied invitation code.
  static List<String> parseInvitationCode(String code) {
    final parts = code.trim().split('|');

    if (parts.length != 2 || parts.any((part) => part.trim().isEmpty)) {
      throw const FormatException('Invalid invitation code.');
    }

    return parts.map((part) => part.trim()).toList();
  }

  factory GroupInvitation.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Invitation does not exist.');
    }

    final createdAt = data['createdAt'];
    final expiresAt = data['expiresAt'];
    final acceptedAt = data['acceptedAt'];

    if (createdAt is! Timestamp || expiresAt is! Timestamp) {
      throw const FormatException('Invalid invitation timestamps.');
    }

    return GroupInvitation(
      id: document.id,
      groupId: data['groupId'] as String,
      groupName: data['groupName'] as String,
      createdBy: data['createdBy'] as String,
      status: data['status'] as String,
      createdAt: createdAt.toDate(),
      expiresAt: expiresAt.toDate(),
      acceptedBy: data['acceptedBy'] as String?,
      acceptedAt: acceptedAt is Timestamp ? acceptedAt.toDate() : null,
    );
  }
}
