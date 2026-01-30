import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get pending verification applications
  Stream<QuerySnapshot> getPendingVerifications() {
    return _firestore
        .collection('pendingVerifications')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Get verification statistics
  Future<Map<String, int>> getVerificationStats() async {
    try {
      final pendingQuery = await _firestore
          .collection('pendingVerifications')
          .where('status', isEqualTo: 'pending')
          .get();

      final approvedQuery = await _firestore
          .collection('users')
          .where('verificationStatus', isEqualTo: 'verified')
          .get();

      final rejectedQuery = await _firestore
          .collection('pendingVerifications')
          .where('status', isEqualTo: 'rejected')
          .get();

      return {
        'pending': pendingQuery.docs.length,
        'approved': approvedQuery.docs.length,
        'rejected': rejectedQuery.docs.length,
      };
    } catch (e) {
      print('Error getting verification stats: $e');
      return {'pending': 0, 'approved': 0, 'rejected': 0};
    }
  }

  // Submit verification application
  Future<void> submitVerificationApplication({
    required String userId,
    required Map<String, dynamic> personalInfo,
    required Map<String, dynamic> medicalInfo,
    List<String>? documentUrls,
  }) async {
    try {
      await _firestore.collection('pendingVerifications').doc(userId).set({
        'userId': userId,
        'personalInfo': personalInfo,
        'medicalInfo': medicalInfo,
        'documentUrls': documentUrls ?? [],
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
        'rejectionReason': null,
      });

      // Update user verification status
      await _firestore.collection('users').doc(userId).update({
        'verificationStatus': 'pending',
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
      });

      print('Verification application submitted successfully');
    } catch (e) {
      print('Error submitting verification application: $e');
      throw e;
    }
  }

  // Upload verification document
  Future<String> uploadVerificationDocument(String userId, File file, String documentType) async {
    try {
      final ref = _storage
          .ref()
          .child('verification_documents')
          .child(userId)
          .child('${documentType}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading document: $e');
      throw e;
    }
  }

  // Admin approve verification
  Future<void> approveVerification(String userId, String adminId, {String? notes}) async {
    try {
      final batch = _firestore.batch();

      // Update pending verification
      batch.update(
        _firestore.collection('pendingVerifications').doc(userId),
        {
          'status': 'approved',
          'reviewedBy': adminId,
          'reviewedAt': FieldValue.serverTimestamp(),
          'adminNotes': notes,
        },
      );

      // Update user status
      batch.update(
        _firestore.collection('users').doc(userId),
        {
          'verificationStatus': 'verified',
          'verifiedAt': FieldValue.serverTimestamp(),
          'verifiedBy': adminId,
        },
      );

      // Log admin action
      batch.set(
        _firestore.collection('adminActions').doc(),
        {
          'adminId': adminId,
          'action': 'approve_verification',
          'targetUserId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'notes': notes,
        },
      );

      await batch.commit();
      print('Verification approved successfully');
    } catch (e) {
      print('Error approving verification: $e');
      throw e;
    }
  }

  // Admin reject verification
  Future<void> rejectVerification(String userId, String adminId, String reason) async {
    try {
      final batch = _firestore.batch();

      // Update pending verification
      batch.update(
        _firestore.collection('pendingVerifications').doc(userId),
        {
          'status': 'rejected',
          'reviewedBy': adminId,
          'reviewedAt': FieldValue.serverTimestamp(),
          'rejectionReason': reason,
        },
      );

      // Update user status
      batch.update(
        _firestore.collection('users').doc(userId),
        {
          'verificationStatus': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': reason,
        },
      );

      // Log admin action
      batch.set(
        _firestore.collection('adminActions').doc(),
        {
          'adminId': adminId,
          'action': 'reject_verification',
          'targetUserId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'reason': reason,
        },
      );

      await batch.commit();
      print('Verification rejected successfully');
    } catch (e) {
      print('Error rejecting verification: $e');
      throw e;
    }
  }

  // Get user verification status
  Stream<DocumentSnapshot> getUserVerificationStatus(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Check eligibility based on medical info
  bool checkBasicEligibility(Map<String, dynamic> medicalInfo) {
    try {
      final age = medicalInfo['age'] ?? 0;
      final weight = medicalInfo['weight'] ?? 0;
      final hasChronicIllness = medicalInfo['hasChronicIllness'] ?? false;
      final isPregnant = medicalInfo['isPregnant'] ?? false;
      final recentDonation = medicalInfo['lastDonationDate'];

      // Basic eligibility criteria
      if (age < 18 || age > 65) return false;
      if (weight < 45) return false;
      if (hasChronicIllness) return false;
      if (isPregnant) return false;

      // Check recent donation (should be at least 56 days ago)
      if (recentDonation != null) {
        final lastDonation = (recentDonation as Timestamp).toDate();
        final daysSinceLastDonation = DateTime.now().difference(lastDonation).inDays;
        if (daysSinceLastDonation < 56) return false;
      }

      return true;
    } catch (e) {
      print('Error checking eligibility: $e');
      return false;
    }
  }

  // Get admin actions log
  Stream<QuerySnapshot> getAdminActionsLog({int limit = 50}) {
    return _firestore
        .collection('adminActions')
        .limit(limit)
        .snapshots();
  }
}