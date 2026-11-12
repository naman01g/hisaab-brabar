import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/group_repository.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final nameController = TextEditingController();
  final repository = GroupRepository();

  final categories = ['Flatmates', 'Trips', 'College', 'Hostel', 'Other'];

  String selectedCategory = 'Flatmates';
  bool isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    nameController.dispose();
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

  Future<void> _createGroup() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      setState(() => errorMessage = 'Please enter a group name.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await repository.createGroup(name: name, category: selectedCategory);

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Firebase error: ${error.message ?? error.code}';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
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
            const Text(
              'Group Name',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

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

            const Text(
              'Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 10),

            CupertinoButton(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              onPressed: isLoading ? null : _selectCategory,
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

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'You will automatically become the group owner. '
                'Invitations for other members will be added separately.',
                style: TextStyle(fontSize: 12, color: AppColors.sageDark),
              ),
            ),

            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],

            const SizedBox(height: 28),

            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(14),
              onPressed: isLoading ? null : _createGroup,
              child: isLoading
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }
}
