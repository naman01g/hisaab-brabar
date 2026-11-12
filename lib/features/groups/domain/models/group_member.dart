enum GroupRole { owner, admin, member }

class GroupMember {
  final String userId;
  final String displayName;
  final GroupRole role;
  final DateTime joinedAt;

  GroupMember({
    required this.userId,
    required this.displayName,
    this.role = GroupRole.member,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now() {
    if (userId.trim().isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    if (displayName.trim().isEmpty) {
      throw ArgumentError('Member name cannot be empty');
    }
  }
}
