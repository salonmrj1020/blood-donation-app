import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donor.dart';
import '../services/auth_service.dart';

class DonorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Create or update donor profile
  Future<String?> createOrUpdateDonorProfile({
    required String bloodType,
    required double latitude,
    required double longitude,
    required String address,
    DateTime? lastDonationDate,
    bool isAvailable = true,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return 'User not authenticated';

      // Get user data from users collection
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return 'User profile not found';

      final userData = userDoc.data()!;
      final name = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();

      final donor = Donor(
        userId: user.uid,
        name: name,
        email: user.email ?? '',
        phone: userData['phone'] ?? '',
        bloodType: bloodType,
        lastDonationDate: lastDonationDate,
        totalDonations: 0,
        isAvailable: false, // Set to false until verified by admin
        latitude: latitude,
        longitude: longitude,
        address: address,
        createdAt: DateTime.now(),
      );

      // Add verification status and admin fields
      final donorData = donor.toFirestore();
      donorData.addAll({
        'verificationStatus': 'pending', // pending, verified, rejected
        'verifiedAt': null,
        'verifiedBy': null,
        'rejectedAt': null,
        'rejectedBy': null,
        'rejectionReason': null,
        'adminNotes': null,
      });

      await _firestore
          .collection('donors')
          .doc(user.uid)
          .set(donorData, SetOptions(merge: true));

      return null; // Success
    } catch (e) {
      print('Error creating donor profile: $e');
      return 'Failed to create donor profile';
    }
  }

  // Get donor profile
  Future<Donor?> getDonorProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('donors')
          .doc(userId)
          .get();

      if (doc.exists) {
        return Donor.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting donor profile: $e');
      return null;
    }
  }

  // Get current user's donor profile
  Future<Donor?> getCurrentUserDonorProfile() async {
    final user = _authService.currentUser;
    if (user == null) return null;
    return getDonorProfile(user.uid);
  }

  // Update donor availability
  Future<bool> updateDonorAvailability(bool isAvailable) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('donors')
          .doc(user.uid)
          .update({
        'isAvailable': isAvailable,
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      print('Error updating donor availability: $e');
      return false;
    }
  }

  // Update last donation date
  Future<bool> updateLastDonationDate(DateTime donationDate) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;

      // Get current donor data to increment total donations
      final donorDoc = await _firestore
          .collection('donors')
          .doc(user.uid)
          .get();

      int currentTotal = 0;
      if (donorDoc.exists) {
        final data = donorDoc.data()!;
        currentTotal = data['totalDonations'] ?? 0;
      }

      await _firestore
          .collection('donors')
          .doc(user.uid)
          .update({
        'lastDonationDate': Timestamp.fromDate(donationDate),
        'totalDonations': currentTotal + 1,
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      print('Error updating last donation date: $e');
      return false;
    }
  }

  // Get donors by blood type
  Future<List<Donor>> getDonorsByBloodType(String bloodType) async {
    try {
      final snapshot = await _firestore
          .collection('donors')
          .where('bloodType', isEqualTo: bloodType)
          .where('isAvailable', isEqualTo: true)
          .where('verificationStatus', isEqualTo: 'verified') // Only verified donors
          .get();

      return snapshot.docs
          .map((doc) => Donor.fromFirestore(doc))
          .where((donor) => donor.isEligible) // Filter eligible donors
          .toList();
    } catch (e) {
      print('Error getting donors by blood type: $e');
      return [];
    }
  }

  // Get all available donors
  Future<List<Donor>> getAvailableDonors() async {
    try {
      final snapshot = await _firestore
          .collection('donors')
          .where('isAvailable', isEqualTo: true)
          .where('verificationStatus', isEqualTo: 'verified') // Only verified donors
          .get();

      return snapshot.docs
          .map((doc) => Donor.fromFirestore(doc))
          .where((donor) => donor.isEligible) // Filter eligible donors
          .toList();
    } catch (e) {
      print('Error getting available donors: $e');
      return [];
    }
  }

  // Get donors near location
  Future<List<Donor>> getDonorsNearLocation(
    double latitude,
    double longitude,
    double radiusInKm,
    {String? bloodType}
  ) async {
    try {
      Query query = _firestore
          .collection('donors')
          .where('isAvailable', isEqualTo: true)
          .where('verificationStatus', isEqualTo: 'verified'); // Only verified donors

      if (bloodType != null) {
        query = query.where('bloodType', isEqualTo: bloodType);
      }

      final snapshot = await query.get();
      
      List<Donor> nearbyDonors = [];

      for (var doc in snapshot.docs) {
        final donor = Donor.fromFirestore(doc);
        
        // Check eligibility
        if (!donor.isEligible) continue;
        
        // Calculate distance
        final distance = _calculateDistance(
          latitude, longitude, donor.latitude, donor.longitude);

        if (distance <= radiusInKm) {
          nearbyDonors.add(donor);
        }
      }

      // Sort by distance (closest first)
      nearbyDonors.sort((a, b) {
        final distanceA = _calculateDistance(
          latitude, longitude, a.latitude, a.longitude);
        final distanceB = _calculateDistance(
          latitude, longitude, b.latitude, b.longitude);
        return distanceA.compareTo(distanceB);
      });

      return nearbyDonors;
    } catch (e) {
      print('Error getting nearby donors: $e');
      return [];
    }
  }

  // Update donor blood type
  Future<bool> updateBloodType(String bloodType) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('donors')
          .doc(user.uid)
          .update({
        'bloodType': bloodType,
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      print('Error updating blood type: $e');
      return false;
    }
  }

  // Update donor location
  Future<bool> updateDonorLocation(
    double latitude,
    double longitude,
    String address,
  ) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('donors')
          .doc(user.uid)
          .update({
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      print('Error updating donor location: $e');
      return false;
    }
  }

  // Get donation statistics
  Future<Map<String, dynamic>> getDonationStats(String userId) async {
    try {
      final donor = await getDonorProfile(userId);
      if (donor == null) {
        return {
          'totalDonations': 0,
          'lastDonationDate': null,
          'isEligible': true,
          'daysUntilEligible': 0,
        };
      }

      return {
        'totalDonations': donor.totalDonations,
        'lastDonationDate': donor.lastDonationDate,
        'isEligible': donor.isEligible,
        'daysUntilEligible': donor.daysUntilEligible,
      };
    } catch (e) {
      print('Error getting donation stats: $e');
      return {
        'totalDonations': 0,
        'lastDonationDate': null,
        'isEligible': true,
        'daysUntilEligible': 0,
      };
    }
  }

  // Check if user has donor profile
  Future<bool> hasDonorProfile() async {
    final user = _authService.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('donors')
          .doc(user.uid)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking donor profile: $e');
      return false;
    }
  }

  // Delete donor profile
  Future<bool> deleteDonorProfile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('donors')
          .doc(user.uid)
          .delete();

      return true;
    } catch (e) {
      print('Error deleting donor profile: $e');
      return false;
    }
  }

  // Helper method to calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}