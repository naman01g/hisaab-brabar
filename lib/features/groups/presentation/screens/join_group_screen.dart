import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/repositories/group_invitation_repository.dart';
import '../../domain/models/group_invitation.dart';

class JoinGroupScreen extends StatefulWidget {
  final String groupId;
  final String invitationId;

  const JoinGroupScreen({
    super.key,
    required this.groupId,
    required this.invitationId,
  });

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final GroupInvitationRepository _repository = GroupInvitationRepository();

  GroupInvitation? _invitation;

  bool _loading = true;
  bool _joining = false;
  bool _joined = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvitation();
  }

  Future<void> _loadInvitation() async {
    if (FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _error = 'Please sign in before opening an invitation.';
        _loading = false;
      });
      return;
    }

    try {
      final invitation = await _repository.getInvitation(
        groupId: widget.groupId,
        invitationId: widget.invitationId,
      );

      if (!mounted) return;

      setState(() {
        _invitation = invitation;
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

  Future<void> _joinGroup() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _error = 'Please sign in before joining.';
      });
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      var displayName = (user.displayName ?? '').trim();

      if (displayName.isEmpty) {
        displayName = (user.email?.split('@').first ?? '').trim();
      }

      if (displayName.length < 2) {
        displayName = 'Member';
      }

      if (displayName.length > 40) {
        displayName = displayName.substring(0, 40);
      }

      await _repository.acceptInvitation(
        groupId: widget.groupId,
        invitationId: widget.invitationId,
        displayName: displayName,
      );

      if (!mounted) return;

      setState(() {
        _joined = true;
        _joining = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _joining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildContent(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_loading) {
      return const CircularProgressIndicator();
    }

    if (_joined) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'You joined successfully!',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'You can now view the group and its expenses.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Done'),
          ),
        ],
      );
    }

    if (_invitation == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Invitation unavailable.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadInvitation();
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final invitation = _invitation!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.groups_rounded, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'You are invited!',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Join ${invitation.groupName}',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'This invitation is valid until '
          '${invitation.expiresAt.toLocal()}',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _joining ? null : _joinGroup,
          child: _joining
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Accept Invitation'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
