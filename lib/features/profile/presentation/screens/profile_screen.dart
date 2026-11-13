import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final repository = ProfileRepository();

  final nameController = TextEditingController();
  final tagController = TextEditingController();

  static const Map<String, String> avatars = {
    'student': '🗿',
    'explorer': '😼',
    'traveler': '😽',
    'artist': '🐹',
    'gamer': '🐼',
    'reader': '🐨',
    'chick': '🐣',
    'octopus': '🐙',
  };

  String selectedAvatar = 'student';
  List<String> tags = [];

  bool discoverable = true;
  bool isLoading = true;
  bool isSaving = false;
  bool isEditing = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    tagController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await repository.getMyProfile();

      if (!mounted) return;

      if (profile == null) {
        final user = FirebaseAuth.instance.currentUser;

        nameController.text =
            user?.displayName ?? user?.email?.split('@').first ?? '';

        setState(() {
          isEditing = true;
          isLoading = false;
        });

        return;
      }

      _applyProfile(profile);

      setState(() {
        isEditing = false;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  void _applyProfile(UserProfile profile) {
    nameController.text = profile.displayName;
    selectedAvatar = profile.avatarId;
    tags = List<String>.from(profile.tags);
    discoverable = profile.discoverable;
  }

  void _addTag() {
    final tag = tagController.text
        .trim()
        .replaceFirst(RegExp(r'^#'), '')
        .toLowerCase();

    if (tag.isEmpty) return;

    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,19}$').hasMatch(tag)) {
      _showMessage(
        'Invalid tag',
        'Use only letters, numbers, hyphens and underscores. Maximum 20 characters.',
      );
      return;
    }

    if (tags.contains(tag)) {
      _showMessage('Already added', 'This tag already exists.');
      return;
    }

    if (tags.length >= 10) {
      _showMessage('Tag limit reached', 'You can add up to 10 tags.');
      return;
    }

    setState(() {
      tags.add(tag);
      tagController.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() {
      tags.remove(tag);
    });
  }

  void _showMessage(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    final name = nameController.text.trim();

    if (name.length < 2 || name.length > 40) {
      _showMessage(
        'Invalid Name',
        'Your name must contain between 2 and 40 characters.',
      );
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await repository.saveMyProfile(
        displayName: name,
        avatarId: selectedAvatar,
        tags: tags,
        discoverable: discoverable,
      );

      // Keep the Firebase Auth display name in sync.
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);

      if (!mounted) return;

      setState(() {
        isEditing = false;
      });

      _showMessage(
        'Profile Saved',
        'Your profile has been saved successfully.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _avatarWidget({
    required String avatarId,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          avatars[avatarId] ?? '🙂',
          style: const TextStyle(fontSize: 29),
        ),
      ),
    );
  }

  Widget _buildTags() {
    if (tags.isEmpty) {
      return const Text(
        'No tags added yet.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#$tag',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              if (isEditing) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _removeTag(tag),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    size: 13,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Choose Your Avatar'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: avatars.keys.map((avatarId) {
            return _avatarWidget(
              avatarId: avatarId,
              selected: selectedAvatar == avatarId,
              onTap: () {
                setState(() => selectedAvatar = avatarId);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            height: 88,
            width: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryLight, width: 2),
            ),
            child: Text(
              avatars[selectedAvatar] ?? '🙂',
              style: const TextStyle(fontSize: 43),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            nameController.text.isEmpty ? 'Your Name' : nameController.text,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            FirebaseAuth.instance.currentUser?.email ?? '',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatarSection(),

        const SizedBox(height: 28),

        _sectionTitle('Display Name'),
        const SizedBox(height: 10),

        CupertinoTextField(
          controller: nameController,
          placeholder: 'Enter your name',
          maxLength: 40,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 26),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('Your Tags'),
            Text(
              '${tags.length}/10',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        const Text(
          'Add interests, college, branch or other things people can discover you by.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: tagController,
                placeholder: 'e.g. AKGEC, SoS , Travel',
                textCapitalization: TextCapitalization.none,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              borderRadius: BorderRadius.circular(12),
              onPressed: isSaving ? null : _addTag,
              child: const Icon(CupertinoIcons.add, size: 18),
            ),
          ],
        ),

        const SizedBox(height: 14),

        _buildTags(),

        const SizedBox(height: 28),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discoverable Profile',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Allow people to find you through your tags.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: discoverable,
                activeTrackColor: AppColors.primary,
                onChanged: isSaving
                    ? null
                    : (value) {
                        setState(() => discoverable = value);
                      },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        if (errorMessage != null) ...[
          Text(
            errorMessage!,
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
          const SizedBox(height: 12),
        ],

        CupertinoButton.filled(
          borderRadius: BorderRadius.circular(14),
          onPressed: isSaving ? null : _saveProfile,
          child: isSaving
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : const Text('Save Profile'),
        ),
      ],
    );
  }

  Widget _buildProfileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileHeader(),

        const SizedBox(height: 28),

        _sectionTitle('Your Tags'),
        const SizedBox(height: 12),
        _buildTags(),

        const SizedBox(height: 28),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'People can discover your profile using your tags.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Icon(
                discoverable ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                discoverable ? 'On' : 'Off',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        CupertinoButton.filled(
          borderRadius: BorderRadius.circular(14),
          onPressed: () {
            setState(() => isEditing = true);
          },
          child: const Text('Edit Profile'),
        ),

        const SizedBox(height: 12),

        CupertinoButton(
          onPressed: _signOut,
          child: const Text(
            'Sign Out',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('My Profile'),
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
      ),
      child: SafeArea(
        child: isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : errorMessage != null && tags.isEmpty && !isEditing
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton.filled(
                        onPressed: _loadProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (isEditing) _buildEditForm() else _buildProfileView(),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}
