import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/payment_details.dart';

class PaymentDetailsRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  PaymentDetailsRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String _currentUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in first.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _privateDocument(String uid) {
    return _db.collection('privatePaymentProfiles').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _groupPaymentDocument(
    String groupId,
    String uid,
  ) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('memberPaymentDetails')
        .doc(uid);
  }

  static String normalizeUpiId(String value) {
    final upiId = value.trim();
    if (upiId.isEmpty) return '';

    if (upiId.length > 100 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{1,}@[A-Za-z0-9][A-Za-z0-9.-]{1,}$')
            .hasMatch(upiId)) {
      throw ArgumentError('Enter a valid UPI ID, such as name@bank.');
    }

    return upiId;
  }

  static String normalizePhoneNumber(String value) {
    final phone = value.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (phone.isEmpty) return '';

    if (!RegExp(r'^\+?[0-9]{10,13}$').hasMatch(phone)) {
      throw ArgumentError('Enter a valid phone number with 10 to 13 digits.');
    }

    return phone;
  }

  Future<PaymentDetails> getMyPaymentDetails() async {
    final uid = _currentUid();
    final snapshot = await _privateDocument(uid).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return const PaymentDetails(upiId: '', phoneNumber: '');
    }

    return PaymentDetails(
      upiId: data['upiId'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
    );
  }

  /// Saves the private canonical record and a group-scoped copy for each
  /// current group. Group members can read the group copy; only its owner
  /// can write it.
  Future<void> saveMyPaymentDetails({
    required String upiId,
    required String phoneNumber,
  }) async {
    final uid = _currentUid();
    final cleanUpiId = normalizeUpiId(upiId);
    final cleanPhone = normalizePhoneNumber(phoneNumber);

    final privateRef = _privateDocument(uid);
    final existing = await privateRef.get();
    final createdAt =
        existing.data()?['createdAt'] ?? FieldValue.serverTimestamp();

    final groupsSnapshot = await _db
        .collection('groups')
        .where('memberIds', arrayContains: uid)
        .get();

    final groupDocs = groupsSnapshot.docs;
    const chunkSize =
        6; // Keep security-rule access calls below the 20-call batch limit.

    if (groupDocs.isEmpty) {
      final batch = _db.batch();
      batch.set(privateRef, {
        'upiId': cleanUpiId,
        'phoneNumber': cleanPhone,
        'createdAt': createdAt,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return;
    }

    for (var start = 0; start < groupDocs.length; start += chunkSize) {
      final end = (start + chunkSize < groupDocs.length)
          ? start + chunkSize
          : groupDocs.length;

      final batch = _db.batch();

      if (start == 0) {
        batch.set(privateRef, {
          'upiId': cleanUpiId,
          'phoneNumber': cleanPhone,
          'createdAt': createdAt,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      for (final groupDoc in groupDocs.sublist(start, end)) {
        batch.set(_groupPaymentDocument(groupDoc.id, uid), {
          'upiId': cleanUpiId,
          'phoneNumber': cleanPhone,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }

  Future<PaymentDetails?> getGroupMemberPaymentDetails({
    required String groupId,
    required String memberUid,
  }) async {
    // Firestore rules allow this direct read only to members of this group.
    final snapshot = await _groupPaymentDocument(groupId, memberUid).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return null;

    return PaymentDetails(
      upiId: data['upiId'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
    );
  }

  /// Ensures the signed-in user's saved details are available to members
  /// of a group they have just opened (for example, after joining a group).
  Future<void> syncMyPaymentDetailsToGroup(String groupId) async {
    final uid = _currentUid();
    final snapshot = await _privateDocument(uid).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) return;

    await _groupPaymentDocument(groupId, uid).set({
      'upiId': data['upiId'] as String? ?? '',
      'phoneNumber': data['phoneNumber'] as String? ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
