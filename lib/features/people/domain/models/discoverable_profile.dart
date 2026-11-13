class DiscoverableProfile {
  final String uid;
  final String displayName;
  final String avatarId;
  final List<String> tags;

  DiscoverableProfile({
    required this.uid,
    required this.displayName,
    required this.avatarId,
    required List<String> tags,
  }) : tags = List.unmodifiable(tags);
}
