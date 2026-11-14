import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/people_repository.dart';
import '../../domain/models/discoverable_profile.dart';

class PeopleDiscoveryScreen extends StatefulWidget {
  const PeopleDiscoveryScreen({super.key});

  @override
  State<PeopleDiscoveryScreen> createState() => _PeopleDiscoveryScreenState();
}

class _PeopleDiscoveryScreenState extends State<PeopleDiscoveryScreen> {
  final PeopleRepository _repository = PeopleRepository();
  final TextEditingController _searchController = TextEditingController();

  List<DiscoverableProfile> _people = [];

  bool _isSearching = false;
  bool _hasSearched = false;

  String? _errorMessage;
  String _searchedTag = '';

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final tag = PeopleRepository.normalizeTag(_searchController.text);

    if (tag == null) {
      setState(() {
        _errorMessage = 'Enter a valid tag using letters, numbers, _ or - (maximum 20 characters).';
        _people = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _searchedTag = tag;
      _hasSearched = true;
      _people = [];
    });

    try {
      final results = await _repository.searchByTag(tag);

      if (!mounted) return;

      setState(() {
        _people = results;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _errorMessage = error is ArgumentError
            ? error.message.toString()
            : 'Unable to search right now. Please try again.';
      });
    }
  }

  Widget _buildPersonCard(DiscoverableProfile person) {
    final avatar = _avatars[person.avatarId] ?? '🧑‍🎓';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: Text(avatar, style: const TextStyle(fontSize: 27)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: person.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Discover People'),
      ),
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find your people.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Discover students who share your interests, '
                    'college or skills.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Search by tag e.g. flutter',
                    backgroundColor: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _isSearching ? null : _search,
                      borderRadius: BorderRadius.circular(14),
                      child: _isSearching
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : const Text('Search People'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Try tags like - SoS , Akgec, or BH3.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            if (_hasSearched && !_isSearching && _errorMessage == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Results for #$_searchedTag',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CupertinoActivityIndicator())
                  : !_hasSearched
                  ? const Center(
                      child: Text(
                        'Search a tag to discover people.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : _people.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No discoverable profiles found for this tag.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: _people.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildPersonCard(_people[index]);
                      },
                    ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: Text(
                'Discovering someone does not add them to your groups. '
                'Group invitations will be handled separately.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
