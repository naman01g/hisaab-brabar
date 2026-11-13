import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/discoverable_profile.dart';

class PeopleRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  PeopleRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static final RegExp _tagPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,19}$');

  static String? normalizeTag(String input) {
    final tag = input.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();

    if (!_tagPattern.hasMatch(tag)) {
      return null;
    }

    return tag;
  }

  Future<List<DiscoverableProfile>> searchByTag(String input) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to discover people.');
    }

    final tag = normalizeTag(input);

    if (tag == null) {
      throw ArgumentError('Enter a valid tag using letters, numbers, _ or -.');
    }

    final snapshot = await _db
        .collection('profiles')
        .where('discoverable', isEqualTo: true)
        .where('tags', arrayContains: tag)
        .limit(21)
        .get();

    return snapshot.docs.where((doc) => doc.id != user.uid).take(20).map((doc) {
      final data = doc.data();

      final rawTags = data['tags'];
      final tags = rawTags is List
          ? rawTags.whereType<String>().toList()
          : <String>[];

      return DiscoverableProfile(
        uid: doc.id,
        displayName: data['displayName'] as String? ?? 'Student',
        avatarId: data['avatarId'] as String? ?? 'student',
        tags: tags,
      );
    }).toList();
  }
}
