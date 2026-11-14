import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/group_invitation_repository.dart';
import '../../domain/models/group_invitation.dart';
import 'join_group_screen.dart';

class JoinGroupCodeScreen extends StatefulWidget {
  const JoinGroupCodeScreen({super.key});

  @override
  State<JoinGroupCodeScreen> createState() => _JoinGroupCodeScreenState();
}

class _JoinGroupCodeScreenState extends State<JoinGroupCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final GroupInvitationRepository _repository = GroupInvitationRepository();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final parts = GroupInvitation.parseInvitationCode(_codeController.text);

      // Codes are generated as: groupId|invitationId.
      // getInvitation validates that it exists, is pending and is not expired.
      final invitation = await _repository.getInvitation(
        groupId: parts[0],
        invitationId: parts[1],
      );

      if (!mounted) return;

      final joined = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          builder: (_) => JoinGroupScreen(
            groupId: invitation.groupId,
            invitationId: invitation.id,
          ),
        ),
      );

      if (joined == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Join with Code'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 32),
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.link,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Join a group',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste the invitation code shared by your group member.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),
            CupertinoTextField(
              controller: _codeController,
              placeholder: 'Paste invitation code',
              padding: const EdgeInsets.all(16),
              clearButtonMode: OverlayVisibilityMode.editing,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _continue(),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: _loading ? null : _continue,
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: _loading
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text('Continue'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Invitation codes use the format groupId|invitationId.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
