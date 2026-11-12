import 'group_member.dart';

class Group {
  final String id;
  final String name;
  final String category;
  final String createdBy;
  final DateTime createdAt;
  final String currencyCode;
  final List<GroupMember> members;

  Group({
    required this.id,
    required this.name,
    this.category = 'Other',
    required this.createdBy,
    required this.createdAt,
    this.currencyCode = 'INR',
    required List<GroupMember> members,
  }) : members = List.unmodifiable(members) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Group ID cannot be empty');
    }

    if (name.trim().isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }

    if (category.trim().isEmpty) {
      throw ArgumentError('Group category cannot be empty');
    }

    if (createdBy.trim().isEmpty) {
      throw ArgumentError('Creator ID cannot be empty');
    }

    if (this.members.isEmpty) {
      throw ArgumentError('A group must have at least one member');
    }

    final memberIds = this.members.map((member) => member.userId).toSet();

    if (memberIds.length != this.members.length) {
      throw ArgumentError('Duplicate members are not allowed');
    }

    if (!memberIds.contains(createdBy)) {
      throw ArgumentError('Group creator must be a member');
    }
  }

  int get memberCount => members.length;
}
