import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/group.dart';
import '../../data/repositories/group_invitation_repository.dart';
import '../../../people/data/repositories/people_repository.dart';
import '../../../people/domain/models/discoverable_profile.dart';

class GroupInvitationScreen extends StatefulWidget {
  final Group group;

  const GroupInvitationScreen({super.key, required this.group});

  @override
  State<GroupInvitationScreen> createState() => _GroupInvitationScreenState();
}

class _GroupInvitationScreenState extends State<GroupInvitationScreen> {
  final GroupInvitationRepository _repository = GroupInvitationRepository();

  // Use the SAME repository as People Discovery.
  final PeopleRepository _peopleRepository = PeopleRepository();

  final TextEditingController _tagSearchController = TextEditingController();

  String? _shareLink;
  String? _invitationCode;
  DateTime? _expiresAt;

  bool _loading = false;
  bool _searchingPeople = false;
  bool _sharingPersonInvite = false;

  String? _error;
  String? _peopleError;
  String _searchedTag = '';

  List<DiscoverableProfile> _people = [];

  static const Map<String, String> _avatars = {
    'student': '🗿',
    'explorer': '😼',
    'traveler': '😽',
    'artist': '🐹',
    'gamer': '🐼',
    'reader': '🐨',
    'chick': '🐣',
    'octopus': '🐙',
  };

  @override
  void dispose() {
    _tagSearchController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // CREATE INVITATION LINK
  // --------------------------------------------------

  String _createShareLink({
    required String groupId,
    required String invitationId,
  }) {
    return Uri(
      scheme: 'hisaabbrabar',
      host: 'join',
      queryParameters: {'groupId': groupId, 'inviteId': invitationId},
    ).toString();
  }

  Future<void> _createInvitation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final invitation = await _repository.createInvitation(widget.group);

      final link = _createShareLink(
        groupId: invitation.groupId,
        invitationId: invitation.id,
      );

      if (!mounted) return;

      setState(() {
        _shareLink = link;
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

  // --------------------------------------------------
  // SEARCH PEOPLE - SAME LOGIC AS PEOPLE DISCOVERY
  // --------------------------------------------------

  Future<void> _searchPeople() async {
    final tag = PeopleRepository.normalizeTag(_tagSearchController.text);

    if (tag == null) {
      setState(() {
        _peopleError =
            'Enter a valid tag using letters, numbers, _ or - '
            '(maximum 20 characters).';
        _people = [];
        _searchedTag = '';
      });
      return;
    }

    setState(() {
      _searchingPeople = true;
      _peopleError = null;
      _searchedTag = tag;
      _people = [];
    });

    try {
      // This is exactly the method used by PeopleDiscoveryScreen.
      final results = await _peopleRepository.searchByTag(tag);

      if (!mounted) return;

      setState(() {
        _people = results;
        _searchingPeople = false;

        if (results.isEmpty) {
          _peopleError = 'No discoverable profiles found for #$tag.';
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _searchingPeople = false;
        _peopleError = error is ArgumentError
            ? error.message.toString()
            : 'Unable to search right now. Please try again.';
      });
    }
  }

  // --------------------------------------------------
  // INVITE SELECTED PERSON
  // --------------------------------------------------

  Future<void> _invitePerson(DiscoverableProfile person) async {
    if (_sharingPersonInvite) return;

    if (widget.group.members.length >= 50) {
      _showMessage(
        'Group is full',
        'This group has reached its 50-member limit.',
      );
      return;
    }

    setState(() {
      _sharingPersonInvite = true;
      _error = null;
    });

    try {
      final invitation = await _repository.createInvitation(widget.group);

      final link = _createShareLink(
        groupId: invitation.groupId,
        invitationId: invitation.id,
      );

      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          title: 'Join ${widget.group.name}',
          subject: 'Group invitation',
          text:
              'Hi ${person.displayName}!\n\n'
              'I would like to invite you to join '
              '"${widget.group.name}" on Hisaab Brabar.\n\n'
              'Invitation link: $link\n\n'
              'Invitation code: ${invitation.invitationCode}\n\n'
              'This invitation expires in 7 days.\n\n'
              'Open the link and accept the invitation to join.',
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Unable to create invitation', error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _sharingPersonInvite = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // PERSON CARD
  // --------------------------------------------------

  Widget _personCard(DiscoverableProfile person, ThemeData theme) {
    final avatar = _avatars[person.avatarId] ?? '🧑‍🎓';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25,
              child: Text(avatar, style: const TextStyle(fontSize: 25)),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: person.tags.map((tag) {
                      return Chip(
                        label: Text(
                          '#$tag',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _sharingPersonInvite
                          ? null
                          : () => _invitePerson(person),
                      icon: const Icon(Icons.person_add_alt_1, size: 17),
                      label: Text(
                        _sharingPersonInvite
                            ? 'Preparing invitation...'
                            : 'Invite',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // GENERAL INVITATION: COPY AND SHARE
  // --------------------------------------------------

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
            'Join my group "${widget.group.name}" '
            'on Hisaab Brabar!\n\n'
            'Invitation link: $link\n\n'
            'Invitation code: $code\n\n'
            'This invitation expires in 7 days.',
      ),
    );
  }

  // --------------------------------------------------
  // MESSAGE
  // --------------------------------------------------

  void _showMessage(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------

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
              const SizedBox(height: 12),

              Icon(
                Icons.group_add_rounded,
                size: 58,
                color: theme.colorScheme.primary,
              ),

              const SizedBox(height: 16),

              Text(
                'Invite friends to your group',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Find people by their interests, college '
                'or profile tags.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 28),

              // ======================================
              // SEARCH PEOPLE
              // ======================================
              Text(
                'Find People',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _tagSearchController,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  hintText: 'Search by tag e.g. #lord',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onSubmitted: (_) => _searchPeople(),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _searchingPeople ? null : _searchPeople,
                  child: _searchingPeople
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search People'),
                ),
              ),

              const SizedBox(height: 16),

              if (_searchedTag.isNotEmpty)
                Text(
                  'Results for #$_searchedTag',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

              if (_peopleError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _peopleError!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),

              if (_people.isNotEmpty) ...[
                const SizedBox(height: 12),

                ..._people.map((person) => _personCard(person, theme)),

                const SizedBox(height: 8),
              ],

              Text(
                'Selecting Invite creates a unique invitation '
                'link and opens the share sheet. The person '
                'must accept before joining.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: 28),

              const Divider(),

              const SizedBox(height: 16),

              // ======================================
              // GENERAL INVITATION
              // ======================================
              Text(
                'Share Invitation Link',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

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
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
