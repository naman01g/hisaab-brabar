import 'package:flutter_test/flutter_test.dart';

import 'package:hisaab_brabar/features/groups/domain/models/group.dart';
import 'package:hisaab_brabar/features/groups/domain/models/group_member.dart';

void main() {
  group('Group model', () {
    final owner = GroupMember(
      userId: 'user_1',
      displayName: 'You',
      role: GroupRole.owner,
    );

    final member = GroupMember(userId: 'user_2', displayName: 'Aarav');

    test('creates a group with valid members', () {
      final group = Group(
        id: 'group_1',
        name: 'Flat 304',
        category: 'Flatmates',
        createdBy: 'user_1',
        createdAt: DateTime(2026, 11, 12),
        members: [owner, member],
      );

      expect(group.name, 'Flat 304');
      expect(group.category, 'Flatmates');
      expect(group.memberCount, 2);
    });

    test('rejects duplicate members', () {
      expect(
        () => Group(
          id: 'group_1',
          name: 'Flat 304',
          createdBy: 'user_1',
          createdAt: DateTime(2026, 11, 12),
          members: [owner, owner],
        ),
        throwsArgumentError,
      );
    });

    test('creator must belong to the group', () {
      expect(
        () => Group(
          id: 'group_1',
          name: 'Flat 304',
          createdBy: 'unknown_user',
          createdAt: DateTime(2026, 11, 12),
          members: [owner, member],
        ),
        throwsArgumentError,
      );
    });
  });
}
