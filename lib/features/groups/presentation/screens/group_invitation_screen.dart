import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/group.dart';
import '../../data/repositories/group_invitation_repository.dart';

class GroupInvitationScreen extends StatefulWidget {
  final Group group;

  const GroupInvitationScreen({super.key, required this.group});

  @override
  State<GroupInvitationScreen> createState() => _GroupInvitationScreenState();
}

class _GroupInvitationScreenState extends State<GroupInvitationScreen> {
  final GroupInvitationRepository _repository = GroupInvitationRepository();

  String? _shareLink;
  String? _invitationCode;
  DateTime? _expiresAt;

  bool _loading = false;
  String? _error;

  Future<void> _createInvitation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final invitation = await _repository.createInvitation(widget.group);

      final shareLink = Uri(
        scheme: 'hisaabbrabar',
        host: 'join',
        queryParameters: {
          'groupId': invitation.groupId,
          'inviteId': invitation.id,
        },
      ).toString();

      if (!mounted) return;

      setState(() {
        _shareLink = shareLink;
        _invitationCode = invitation.invitationCode;
        _expiresAt = invitation.expiresAt;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copyInvitation() async {
    final link = _shareLink;

    if (link == null) return;

    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Invitation link copied!')));
  }

  Future<void> _shareInvitation() async {
    final link = _shareLink;
    final code = _invitationCode;

    if (link == null || code == null) return;

    await SharePlus.instance.share(
      ShareParams(
        title: 'Join ${widget.group.name}',
        subject: 'Group invitation',
        text:
            'Join my group "${widget.group.name}" on Hisaab Brabar!\n\n'
            'Invitation link: $link\n\n'
            'Invitation code: $code\n\n'
            'This invitation expires in 7 days.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Members')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              Icon(
                Icons.group_add_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),

              const SizedBox(height: 20),

              Text(
                'Invite friends to your group',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Share an invitation with your friends '
                'so they can join "${widget.group.name}".',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 32),

              if (_shareLink == null) ...[
                FilledButton.icon(
                  onPressed: _loading ? null : _createInvitation,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_link),
                  label: Text(
                    _loading ? 'Creating invitation...' : 'Generate Invitation',
                  ),
                ),
              ] else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Your invitation link',
                          style: theme.textTheme.titleMedium,
                        ),

                        const SizedBox(height: 12),

                        SelectableText(_shareLink!),

                        const SizedBox(height: 20),

                        Text(
                          'Invitation code',
                          style: theme.textTheme.titleSmall,
                        ),

                        const SizedBox(height: 8),

                        SelectableText(
                          _invitationCode!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (_expiresAt != null)
                          Text(
                            'Expires: ${_expiresAt!.toLocal()}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: _shareInvitation,
                  icon: const Icon(Icons.share),
                  label: const Text('Share Invitation'),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: _copyInvitation,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Link'),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
