import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Group group;
  final ValueChanged<Group> onGroupUpdated;

  const GroupDetailsScreen({
    super.key,
    required this.group,
    required this.onGroupUpdated,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  late Group group;

  @override
  void initState() {
    super.initState();
    group = widget.group;
  }

  void _updateMembers(List<GroupMember> members) {
    final updatedGroup = Group(
      id: group.id,
      name: group.name,
      category: group.category,
      createdBy: group.createdBy,
      createdAt: group.createdAt,
      currencyCode: group.currencyCode,
      members: members,
    );

    setState(() {
      group = updatedGroup;
    });

    widget.onGroupUpdated(updatedGroup);
  }

  Future<void> _addMember() async {
    final controller = TextEditingController();

    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Add Member'),
          content: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: CupertinoTextField(
              controller: controller,
              autofocus: true,
              placeholder: 'Enter member name',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || name == null) return;

    if (name.isEmpty) {
      _showMessage('Please enter a member name.');
      return;
    }

    final alreadyExists = group.members.any(
      (member) => member.displayName.toLowerCase() == name.toLowerCase(),
    );

    if (alreadyExists) {
      _showMessage('This member is already in the group.');
      return;
    }

    final newMember = GroupMember(
      userId: 'local_${DateTime.now().microsecondsSinceEpoch}',
      displayName: name,
      role: GroupRole.member,
    );

    _updateMembers([...group.members, newMember]);
  }

  Future<void> _removeMember(GroupMember member) async {
    if (member.userId == group.createdBy || member.role == GroupRole.owner) {
      _showMessage('The group owner cannot be removed.');
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Remove Member?'),
          content: Text('Remove ${member.displayName} from this group?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    _updateMembers(
      group.members.where((item) => item.userId != member.userId).toList(),
    );
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _memberCard(GroupMember member) {
    final isOwner =
        member.userId == group.createdBy || member.role == GroupRole.owner;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.sage,
              shape: BoxShape.circle,
            ),
            child: Text(
              member.displayName[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.sageDark,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOwner ? 'Owner' : member.role.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          if (!isOwner)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 36,
              onPressed: () => _removeMember(member),
              child: const Icon(
                CupertinoIcons.minus_circle,
                color: AppColors.error,
                size: 21,
              ),
            )
          else
            const Icon(
              CupertinoIcons.checkmark_seal_fill,
              color: AppColors.sageDark,
              size: 20,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Group Details'),
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Group information
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${group.memberCount} members • ${group.currencyCode}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Members heading and add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle('Members'),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _addMember,
                  child: const Row(
                    children: [
                      Icon(
                        CupertinoIcons.add,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            ...group.members.map(_memberCard),

            const SizedBox(height: 24),

            // Group information
            _sectionTitle('About Group'),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _infoRow('Group ID', group.id),
                  const SizedBox(height: 14),
                  _infoRow('Category', group.category),
                  const SizedBox(height: 14),
                  _infoRow('Currency', group.currencyCode),
                  const SizedBox(height: 14),
                  _infoRow(
                    'Created',
                    '${group.createdAt.day}/${group.createdAt.month}/${group.createdAt.year}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
