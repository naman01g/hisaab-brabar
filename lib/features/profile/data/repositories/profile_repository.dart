import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/user_profile.dart';

class ProfileRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const allowedAvatars = {
    'student',
    'explorer',
    'traveler',
    'artist',
    'gamer',
    'reader',
    'chick',
    'octopus',
  };

  DocumentReference<Map<String, dynamic>> _profileDocument(String uid) {
    return _db.collection('profiles').doc(uid);
  }

  // Load the currently signed-in user's profile.
  Future<UserProfile?> getMyProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final snapshot = await _profileDocument(user.uid).get();

    if (!snapshot.exists) return null;

    final data = snapshot.data()!;

    final createdAt = data['createdAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;

    return UserProfile(
      uid: user.uid,
      displayName: data['displayName'] as String,
      avatarId: data['avatarId'] as String,
      tags: List<String>.from(data['tags'] ?? []),
      discoverable: data['discoverable'] as bool? ?? true,
      createdAt: createdAt?.toDate() ?? DateTime.now(),
      updatedAt: updatedAt?.toDate() ?? DateTime.now(),
    );
  }

  // Normalize tags before saving.
  List<String> normalizeTags(List<String> input) {
    final tags = <String>{};

    for (final rawTag in input) {
      final tag = rawTag.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();

      if (tag.isEmpty) continue;

      if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,19}$').hasMatch(tag)) {
        throw ArgumentError(
          'Invalid tag: $rawTag. Use letters, numbers, _ or -.',
        );
      }

      tags.add(tag);
    }

    if (tags.length > 10) {
      throw ArgumentError('You can add a maximum of 10 tags.');
    }

    return tags.toList();
  }

  // Create or update the current user's public profile.
  Future<void> saveMyProfile({
    required String displayName,
    required String avatarId,
    required List<String> tags,
    required bool discoverable,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in first.');
    }

    final name = displayName.trim();

    if (name.length < 2 || name.length > 40) {
      throw ArgumentError('Name must contain between 2 and 40 characters.');
    }

    if (!allowedAvatars.contains(avatarId)) {
      throw ArgumentError('Invalid avatar selection.');
    }

    final normalizedTags = normalizeTags(tags);

    final document = _profileDocument(user.uid);
    final existing = await document.get();

    final previousCreatedAt = existing.data()?['createdAt'];

    await document.set({
      'displayName': name,
      'avatarId': avatarId,
      'tags': normalizedTags,
      'discoverable': discoverable,
      'createdAt': previousCreatedAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
