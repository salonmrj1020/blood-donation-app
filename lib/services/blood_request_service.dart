import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/blood_request.dart';
import '../models/donor.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class BloodRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Blood type compatibility mapping
  static const Map<String, List<String>> _bloodCompatibility = {
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], // Universal receiver
    'AB-': ['A-', 'B-', 'AB-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'], // Universal donor
  };

  // Create a new blood request
  Future<String?> createBloodRequest({
    required String requesterId,
    required String requesterName,
    required String requesterPhone,
    required String bloodType,
    required int quantity,
    required String urgency,
    required String hospitalName,
    required String hospitalAddress,
    required double latitude,
    required double longitude,
    required String patientName,
    required String description,
  }) async {
    try {
      print('Creating blood request for user: $requesterId');
      
      final bloodRequest = BloodRequest(
        id: '',
        requesterId: requesterId,
        requesterName: requesterName,
        requesterPhone: requesterPhone,
        bloodType: bloodType,
        quantity: quantity,
        urgency: urgency,
        hospitalName: hospitalName,
        hospitalAddress: hospitalAddress,
        latitude: latitude,
        longitude: longitude,
        patientName: patientName,
        description: description,
        status: 'pending',
        createdAt: DateTime.now(),
        matchedDonors: [],
      );

      print('Blood request data: ${bloodRequest.toFirestore()}');

      final docRef = await _firestore
          .collection('bloodRequests')
          .add(bloodRequest.toFirestore());

      print('Blood request created with ID: ${docRef.id}');

      // Find and match compatible donors
      await _findAndMatchDonors(docRef.id, bloodType, latitude, longitude, urgency);

      return docRef.id;
    } catch (e) {
      print('Error creating blood request: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('permission-denied')) {
        throw Exception('Permission denied. Please check your authentication.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Failed to create blood request: ${e.toString()}');
      }
    }
  }

  // Find compatible donors for a blood request
  Future<void> _findAndMatchDonors(
    String requestId,
    String bloodType,
    double latitude,
    double longitude,
    String urgency, // Add urgency parameter
  ) async {
    try {
      print('=== DONOR MATCHING DEBUG ===');
      print('Request location: $latitude, $longitude');
      print('Blood type needed: $bloodType');
      print('Urgency: $urgency');

      final compatibleBloodTypes = _bloodCompatibility[bloodType] ?? [bloodType];
      print('Compatible blood types: $compatibleBloodTypes');
      
      // Query donors with compatible blood types
      final donorsQuery = await _firestore
          .collection('donors')
          .where('bloodType', whereIn: compatibleBloodTypes)
          .where('isAvailable', isEqualTo: true)
          .get();

      print('Found ${donorsQuery.docs.length} potentially compatible donors');

      List<String> matchedDonorIds = [];
      List<Map<String, dynamic>> donorDistances = [];
      
      for (var doc in donorsQuery.docs) {
        final donor = Donor.fromFirestore(doc);
        print('Checking donor: ${donor.name} (${donor.bloodType}) at ${donor.latitude}, ${donor.longitude}');
        
        // Check if donor is eligible (56 days since last donation)
        if (!donor.isEligible) {
          print('  → Donor not eligible (recent donation)');
          continue;
        }
        
        // Skip donors with invalid locations (0.0, 0.0)
        if (donor.latitude == 0.0 && donor.longitude == 0.0) {
          print('  → Donor has invalid location (0.0, 0.0)');
          continue;
        }

        // Skip requests with invalid locations
        if (latitude == 0.0 && longitude == 0.0) {
          print('  → Request has invalid location, including all valid donors');
          matchedDonorIds.add(donor.userId);
          continue;
        }
        
        // Calculate distance (within 50km for now)
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          donor.latitude,
          donor.longitude,
        );
        
        final distanceKm = distance / 1000;
        print('  → Distance: ${distanceKm.toStringAsFixed(2)} km');
        
        if (distance <= 50000) { // 50km radius
          matchedDonorIds.add(donor.userId);
          donorDistances.add({
            'donorId': donor.userId,
            'name': donor.name,
            'distance': distanceKm,
            'bloodType': donor.bloodType,
          });
          print('  →  MATCHED! (within 50km)');
        } else {
          print('  →  Too far (${distanceKm.toStringAsFixed(2)} km > 50km)');
        }
      }

      // Sort donors by distance (closest first)
      donorDistances.sort((a, b) => a['distance'].compareTo(b['distance']));
      
      print('=== MATCHING RESULTS ===');
      print('Total matched donors: ${matchedDonorIds.length}');
      for (var donor in donorDistances) {
        print('  - ${donor['name']} (${donor['bloodType']}) - ${donor['distance'].toStringAsFixed(2)} km');
      }

      // Update blood request with matched donors
      await _firestore
          .collection('bloodRequests')
          .doc(requestId)
          .update({'matchedDonors': matchedDonorIds});

      // Determine notification priority and message based on urgency
      String notificationTitle;
      String notificationMessage;
      String priority;

      if (urgency == 'emergency') {
        notificationTitle = '🚨 EMERGENCY Blood Request';
        notificationMessage = 'URGENT: $bloodType blood needed immediately! A life depends on your help!';
        priority = 'urgent';
      } else if (urgency == 'urgent') {
        notificationTitle = '⚡ Urgent Blood Request';
        notificationMessage = 'Urgent: $bloodType blood needed soon. Your help can save a life!';
        priority = 'high';
      } else {
        notificationTitle = '🩸 Blood Request Match';
        notificationMessage = 'Your blood type $bloodType is needed. Help save a life!';
        priority = 'normal';
      }

      print('Sending notifications to ${matchedDonorIds.length} matched donors for $urgency request');

      // Send notifications to matched donors
      for (String donorId in matchedDonorIds) {
        await _notificationService.createNotification(
          userId: donorId,
          title: notificationTitle,
          message: notificationMessage,
          type: 'blood_request',
          relatedId: requestId,
          data: {
            'bloodType': bloodType,
            'urgency': urgency,
            'requestId': requestId,
            'distance': '< 50km',
          },
          priority: priority,
        );
        print('Notification sent to donor: $donorId');
      }

      // For emergency requests, also send to emergency notification service
      if (urgency == 'emergency') {
        // Get hospital name from the blood request
        final requestDoc = await _firestore
            .collection('bloodRequests')
            .doc(requestId)
            .get();
        
        String hospitalName = 'Hospital';
        if (requestDoc.exists) {
          hospitalName = requestDoc.data()?['hospitalName'] ?? 'Hospital';
        }

        await _notificationService.sendEmergencyNotification(
          requestId: requestId,
          bloodType: bloodType,
          hospitalName: hospitalName,
          urgency: urgency,
          donorIds: matchedDonorIds,
        );
        print('Emergency notification broadcast sent for $hospitalName');
      }

    } catch (e) {
      print('Error matching donors: $e');
    }
  }

  // Get all blood requests (simplified query while indexes are building)
  Stream<List<BloodRequest>> getBloodRequestsStream() {
    return _firestore
        .collection('bloodRequests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BloodRequest.fromFirestore(doc))
            .where((request) => request.status == 'pending')
            .toList());
  }

  // Get blood requests by urgency (simplified query while indexes are building)
  Stream<List<BloodRequest>> getBloodRequestsByUrgency(String urgency) {
    return _firestore
        .collection('bloodRequests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BloodRequest.fromFirestore(doc))
            .where((request) => request.status == 'pending' && request.urgency == urgency)
            .toList());
  }

  // Get blood requests by blood type (simplified query while indexes are building)
  Stream<List<BloodRequest>> getBloodRequestsByBloodType(String bloodType) {
    return _firestore
        .collection('bloodRequests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BloodRequest.fromFirestore(doc))
            .where((request) => request.status == 'pending' && request.bloodType == bloodType)
            .toList());
  }

  // Get blood requests near location
  Future<List<BloodRequest>> getBloodRequestsNearLocation(
    double latitude,
    double longitude,
    double radiusInKm,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('bloodRequests')
          .where('status', isEqualTo: 'pending')
          .get();

      List<BloodRequest> nearbyRequests = [];

      for (var doc in snapshot.docs) {
        final request = BloodRequest.fromFirestore(doc);
        
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          request.latitude,
          request.longitude,
        );

        if (distance <= radiusInKm * 1000) {
          nearbyRequests.add(request);
        }
      }

      // Sort by distance (closest first)
      nearbyRequests.sort((a, b) {
        final distanceA = Geolocator.distanceBetween(
          latitude, longitude, a.latitude, a.longitude);
        final distanceB = Geolocator.distanceBetween(
          latitude, longitude, b.latitude, b.longitude);
        return distanceA.compareTo(distanceB);
      });

      return nearbyRequests;
    } catch (e) {
      print('Error getting nearby requests: $e');
      return [];
    }
  }

  // Get single blood request
  Future<BloodRequest?> getBloodRequest(String requestId) async {
    try {
      final doc = await _firestore
          .collection('bloodRequests')
          .doc(requestId)
          .get();
      
      if (doc.exists) {
        return BloodRequest.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting blood request: $e');
      return null;
    }
  }

  // Update blood request status
  Future<bool> updateBloodRequestStatus(String requestId, String status) async {
    try {
      await _firestore
          .collection('bloodRequests')
          .doc(requestId)
          .update({
        'status': status,
        'fulfilledAt': status == 'fulfilled' ? Timestamp.now() : null,
      });
      return true;
    } catch (e) {
      print('Error updating request status: $e');
      return false;
    }
  }

  // Get user's blood requests (simplified query while indexes are building)
  Stream<List<BloodRequest>> getUserBloodRequests(String userId) {
    return _firestore
        .collection('bloodRequests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BloodRequest.fromFirestore(doc))
            .where((request) => request.requesterId == userId)
            .toList());
  }

  // Delete blood request
  Future<bool> deleteBloodRequest(String requestId) async {
    try {
      await _firestore
          .collection('bloodRequests')
          .doc(requestId)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting blood request: $e');
      return false;
    }
  }

  // Get compatible blood types for a given blood type
  static List<String> getCompatibleBloodTypes(String bloodType) {
    return _bloodCompatibility[bloodType] ?? [bloodType];
  }

  // Calculate distance between two points
  static double calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Get blood requests with optional filters (for home screen and search)
  Future<List<BloodRequest>> getBloodRequests({
    String? bloodType,
    String? urgency,
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection('bloodRequests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      
      List<BloodRequest> requests = snapshot.docs
          .map((doc) => BloodRequest.fromFirestore(doc))
          .toList();

      // Apply filters in memory (since we can't use multiple where clauses without indexes)
      if (bloodType != null) {
        requests = requests.where((r) => r.bloodType == bloodType).toList();
      }
      
      if (urgency != null) {
        requests = requests.where((r) => r.urgency.toLowerCase() == urgency.toLowerCase()).toList();
      }

      return requests;
    } catch (e) {
      print('Error getting blood requests: $e');
      return [];
    }
  }

  // Search blood requests
  Future<List<BloodRequest>> searchBloodRequests({
    String? query,
    String? bloodType,
    String? urgency,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('bloodRequests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      List<BloodRequest> requests = snapshot.docs
          .map((doc) => BloodRequest.fromFirestore(doc))
          .toList();

      // Apply filters
      if (bloodType != null) {
        requests = requests.where((r) => r.bloodType == bloodType).toList();
      }
      
      if (urgency != null) {
        requests = requests.where((r) => r.urgency.toLowerCase() == urgency.toLowerCase()).toList();
      }

      // Apply text search
      if (query != null && query.isNotEmpty) {
        final searchQuery = query.toLowerCase();
        requests = requests.where((r) => 
          r.patientName.toLowerCase().contains(searchQuery) ||
          r.hospitalName.toLowerCase().contains(searchQuery) ||
          r.hospitalAddress.toLowerCase().contains(searchQuery) ||
          r.description.toLowerCase().contains(searchQuery)
        ).toList();
      }

      return requests;
    } catch (e) {
      print('Error searching blood requests: $e');
      return [];
    }
  }

  // Get all blood requests (for admin)
  Future<List<BloodRequest>> getAllBloodRequests() async {
    try {
      final snapshot = await _firestore
          .collection('bloodRequests')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BloodRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting all blood requests: $e');
      return [];
    }
  }
}