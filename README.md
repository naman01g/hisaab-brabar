# Hisaab Brabar Navigation Fix

This patch restores the Home notification bell, wires all four Home quick actions, and adds a Groups-page invitation-code entry screen.

## Files
- `lib/features/home/presentation/widgets/quick_action_tile.dart`
- `lib/features/home/presentation/screens/home_screen.dart`
- `lib/core/navigation/main_navigation.dart`
- `lib/features/groups/presentation/screens/groups_screen.dart`
- `lib/features/groups/presentation/screens/join_group_code_screen.dart` (new)

## Behavior
- Home bell opens `NotificationsScreen`.
- Add Expense selects the existing Add tab.
- Discover selects the existing People tab.
- Invite opens a group picker, then the existing `GroupInvitationScreen`.
- Settle Up opens a group picker, then that group's existing `GroupDetailsScreen` (balance and suggested-settlement view).
- Groups-page link icon opens a code input. The code is parsed using `GroupInvitation.parseInvitationCode`, validated using `GroupInvitationRepository.getInvitation`, then opens the existing `JoinGroupScreen`.

The invitation code format is the existing `groupId|invitationId`. This code-entry path is intended for general/link invitations. Direct targeted invitations should be accepted from the recipient's Notifications screen using `respondToGroupInvitation()`.

## Apply
Extract into the Flutter project root and allow replacement of the four existing files. The `join_group_code_screen.dart` file is new.

Then run:
```bash
dart format lib/
flutter analyze
flutter run
```

These files were assembled from the source pasted in the conversation; Flutter/Dart were not available here, so compile/analyzer/device behavior has not been run.
