class UserProfile {
  final String uid;
  final String displayName;
  final String avatarId;
  final List<String> tags;
  final bool discoverable;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.avatarId,
    required List<String> tags,
    required this.discoverable,
    required this.createdAt,
    required this.updatedAt,
  }) : tags = List.unmodifiable(tags);
}
