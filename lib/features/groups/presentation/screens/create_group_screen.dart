import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final nameController = TextEditingController();
  final membersController = TextEditingController();

  final categories = ['Flatmates', 'Trips', 'College', 'Hostel', 'Other'];

  String selectedCategory = 'Flatmates';

  @override
  void dispose() {
    nameController.dispose();
    membersController.dispose();
    super.dispose();
  }

  void _selectCategory() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Category'),
        actions: categories.map((category) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => selectedCategory = category);
              Navigator.pop(context);
            },
            child: Text(category),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _createGroup() {
    final name = nameController.text.trim();

    final memberNames = membersController.text
        .split(RegExp(r'[\n,]'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (name.isEmpty) {
      _showError('Please enter a group name.');
      return;
    }

    final normalizedNames = memberNames
        .map((name) => name.toLowerCase())
        .toList();

    if (normalizedNames.contains('you') ||
        normalizedNames.toSet().length != normalizedNames.length) {
      _showError('Remove duplicate names. "You" is already included.');
      return;
    }

    final now = DateTime.now();
    final groupId = now.microsecondsSinceEpoch.toString();

    const ownerId = 'local_current_user';

    final members = [
      GroupMember(
        userId: ownerId,
        displayName: 'You',
        role: GroupRole.owner,
        joinedAt: now,
      ),
      ...memberNames.asMap().entries.map((entry) {
        return GroupMember(
          userId: '${groupId}_member_${entry.key}',
          displayName: entry.value,
          role: GroupRole.member,
          joinedAt: now,
        );
      }),
    ];

    final group = Group(
      id: groupId,
      name: name,
      category: selectedCategory,
      createdBy: ownerId,
      createdAt: now,
      members: members,
    );

    Navigator.pop(context, group);
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Check Group Details'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(middle: Text('Create Group')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionTitle('Group Name'),
            const SizedBox(height: 10),

            CupertinoTextField(
              controller: nameController,
              placeholder: 'e.g. Flat 402 Friends',
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
            ),

            const SizedBox(height: 24),

            _sectionTitle('Category'),
            const SizedBox(height: 10),

            CupertinoButton(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              onPressed: _selectCategory,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedCategory,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _sectionTitle('Add Members'),
            const SizedBox(height: 6),

            const Text(
              'Enter names separated by commas or new lines. You are included automatically as the owner.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 10),

            CupertinoTextField(
              controller: membersController,
              placeholder: 'Aarav, Meera, Kabir',
              minLines: 3,
              maxLines: 5,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    CupertinoIcons.person_crop_circle,
                    color: AppColors.sageDark,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You will be the group owner.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.sageDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(14),
              onPressed: _createGroup,
              child: const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}
