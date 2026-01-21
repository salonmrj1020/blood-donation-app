import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donation_record.dart';
import '../models/blood_request.dart';
import '../services/auth_service.dart';
import '../services/donor_service.dart';
import '../services/notification_service.dart';

class DonationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final DonorService _donorService = DonorService();
  final NotificationService _notificationService = NotificationService();

  // Create a donation record when donor commits to donate
  Future<String?> createDonationRecord({
    required String requestId,
    required BloodRequest bloodRequest,
    required String donorName,
    DateTime? scheduledDate,
    String? notes,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return 'User not authenticated';

      final donationRecord = DonationRecord(
        id: '',
        donorId: user.uid,
        donorName: donorName,
        requestId: requestId,
        requesterId: bloodRequest.requesterId,
        requesterName: bloodRequest.requesterName,
        bloodType: bloodRequest.bloodType,
        quantity: bloodRequest.quantity,
        hospitalName: bloodRequest.hospitalName,
        hospitalAddress: bloodRequest.hospitalAddress,
        donationDate: scheduledDate ?? DateTime.now(),
        status: 'pending',
        notes: notes,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('donations')
          .add(donationRecord.toFirestore());

      // Send notification to requester
      await _notificationService.createNotification(
        userId: bloodRequest.requesterId,
        title: '🩸 Donor Found!',
        message: '$donorName has committed to donate ${bloodRequest.bloodType} blood for your request.',
        type: 'donation_commitment',
        relatedId: docRef.id,
        data: {
          'donationId': docRef.id,
          'donorName': donorName,
          'bloodType': bloodRequest.bloodType,
          'hospitalName': bloodRequest.hospitalName,
        },
        priority: 'high',
      );

      return null; // Success
    } catch (e) {
      print('Error creating donation record: $e');
      return 'Failed to create donation record';
    }
  }

  // Mark donation as completed
  Future<String?> completeDonation(String donationId, {String? notes}) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return 'User not authenticated';

      // Get the donation record
      final donationDoc = await _firestore
          .collection('donations')
          .doc(donationId)
          .get();

      if (!donationDoc.exists) {
        return 'Donation record not found';
      }

      final donation = DonationRecord.fromFirestore(donationDoc);

      // Verify the current user is the donor
      if (donation.donorId != user.uid) {
        return 'You are not authorized to complete this donation';
      }

      // Update donation record
      await _firestore
          .collection('donations')
          .doc(donationId)
          .update({
        'status': 'completed',
        'completedAt': Timestamp.now(),
        'notes': notes ?? donation.notes,
      });

      // Update donor's last donation date and total donations
      await _donorService.updateLastDonationDate(DateTime.now());

      // Send notification to requester
      await _notificationService.createNotification(
        userId: donation.requesterId,
        title: '✅ Donation Completed!',
        message: '${donation.donorName} has successfully donated ${donation.bloodType} blood. Thank you for using our service!',
        type: 'donation_completed',
        relatedId: donationId,
        data: {
          'donationId': donationId,
          'donorName': donation.donorName,
          'bloodType': donation.bloodType,
        },
        priority: 'high',
      );

      // Send notification to donor
      await _notificationService.createNotification(
        userId: donation.donorId,
        title: '🎉 Thank You for Donating!',
        message: 'Your donation has been recorded. You\'ve helped save a life today!',
        type: 'donation_completed',
        relatedId: donationId,
        data: {
          'donationId': donationId,
          'bloodType': donation.bloodType,
        },
        priority: 'normal',
      );

      return null; // Success
    } catch (e) {
      print('Error completing donation: $e');
      return 'Failed to complete donation';
    }
  }

  // Cancel donation
  Future<String?> cancelDonation(String donationId, {String? reason}) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return 'User not authenticated';

      // Get the donation record
      final donationDoc = await _firestore
          .collection('donations')
          .doc(donationId)
          .get();

      if (!donationDoc.exists) {
        return 'Donation record not found';
      }

      final donation = DonationRecord.fromFirestore(donationDoc);

      // Verify the current user is the donor
      if (donation.donorId != user.uid) {
        return 'You are not authorized to cancel this donation';
      }

      // Update donation record
      await _firestore
          .collection('donations')
          .doc(donationId)
          .update({
        'status': 'cancelled',
        'notes': reason ?? 'Cancelled by donor',
      });

      // Send notification to requester
      await _notificationService.createNotification(
        userId: donation.requesterId,
        title: '❌ Donation Cancelled',
        message: '${donation.donorName} has cancelled their donation commitment. We\'ll help you find another donor.',
        type: 'donation_cancelled',
        relatedId: donationId,
        data: {
          'donationId': donationId,
          'donorName': donation.donorName,
          'bloodType': donation.bloodType,
          'reason': reason,
        },
        priority: 'high',
      );

      return null; // Success
    } catch (e) {
      print('Error cancelling donation: $e');
      return 'Failed to cancel donation';
    }
  }

  // Get donor's donation history (PRIVACY: Only returns data for authenticated user)
  Stream<List<DonationRecord>> getDonorDonationHistory() {
    final user = _authService.currentUser;
    if (user == null) return Stream.value([]);

    // SECURITY: Only return donations for the current authenticated user
    // This ensures users can only see their own donation history
    return _firestore
        .collection('donations')
        .where('donorId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DonationRecord.fromFirestore(doc))
            .toList());
  }

  // Get pending donations for donor (PRIVACY: Only for authenticated user)
  Stream<List<DonationRecord>> getPendingDonations() {
    final user = _authService.currentUser;
    if (user == null) return Stream.value([]);

    // SECURITY: Only return pending donations for the current authenticated user
    return _firestore
        .collection('donations')
        .where('donorId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('donationDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DonationRecord.fromFirestore(doc))
            .toList());
  }

  // Get donation statistics for donor (PRIVACY: Only for authenticated user)
  Future<Map<String, dynamic>> getDonationStats() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return {};

      // SECURITY: Only get statistics for the current authenticated user
      final snapshot = await _firestore
          .collection('donations')
          .where('donorId', isEqualTo: user.uid)
          .get();

      final donations = snapshot.docs
          .map((doc) => DonationRecord.fromFirestore(doc))
          .toList();

      final completedDonations = donations.where((d) => d.isCompleted).toList();
      final pendingDonations = donations.where((d) => d.isPending).toList();
      final cancelledDonations = donations.where((d) => d.isCancelled).toList();

      // Calculate total units donated
      final totalUnits = completedDonations.fold<int>(
        0, (sum, donation) => sum + donation.quantity);

      // Get last donation date
      DateTime? lastDonationDate;
      if (completedDonations.isNotEmpty) {
        completedDonations.sort((a, b) => b.donationDate.compareTo(a.donationDate));
        lastDonationDate = completedDonations.first.donationDate;
      }

      // Calculate blood types donated
      final bloodTypesMap = <String, int>{};
      for (final donation in completedDonations) {
        bloodTypesMap[donation.bloodType] = 
            (bloodTypesMap[donation.bloodType] ?? 0) + donation.quantity;
      }

      return {
        'totalDonations': completedDonations.length,
        'totalUnits': totalUnits,
        'pendingDonations': pendingDonations.length,
        'cancelledDonations': cancelledDonations.length,
        'lastDonationDate': lastDonationDate,
        'bloodTypesHelped': bloodTypesMap,
        'allDonations': donations.length,
      };
    } catch (e) {
      print('Error getting donation stats: $e');
      return {};
    }
  }

  // Get specific donation record
  Future<DonationRecord?> getDonationRecord(String donationId) async {
    try {
      final doc = await _firestore
          .collection('donations')
          .doc(donationId)
          .get();

      if (doc.exists) {
        return DonationRecord.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting donation record: $e');
      return null;
    }
  }

  // Check if user has pending donations for a specific request
  Future<bool> hasPendingDonationForRequest(String requestId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;

      final snapshot = await _firestore
          .collection('donations')
          .where('donorId', isEqualTo: user.uid)
          .where('requestId', isEqualTo: requestId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking pending donation: $e');
      return false;
    }
  }

  // Update donation notes
  Future<String?> updateDonationNotes(String donationId, String notes) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return 'User not authenticated';

      // Verify the user owns this donation
      final donationDoc = await _firestore
          .collection('donations')
          .doc(donationId)
          .get();

      if (!donationDoc.exists) {
        return 'Donation record not found';
      }

      final donation = DonationRecord.fromFirestore(donationDoc);
      if (donation.donorId != user.uid) {
        return 'You are not authorized to update this donation';
      }

      await _firestore
          .collection('donations')
          .doc(donationId)
          .update({'notes': notes});

      return null; // Success
    } catch (e) {
      print('Error updating donation notes: $e');
      return 'Failed to update notes';
    }
  }
}