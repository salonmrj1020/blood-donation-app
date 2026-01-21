import 'package:cloud_firestore/cloud_firestore.dart';

class BloodRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String requesterPhone;
  final String bloodType;
  final int quantity;
  final String urgency; // 'normal', 'urgent', 'emergency'
  final String hospitalName;
  final String hospitalAddress;
  final double latitude;
  final double longitude;
  final String patientName;
  final String description;
  final String status; // 'pending', 'fulfilled', 'cancelled'
  final DateTime createdAt;
  final DateTime? fulfilledAt;
  final List<String> matchedDonors;

  BloodRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterPhone,
    required this.bloodType,
    required this.quantity,
    required this.urgency,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.latitude,
    required this.longitude,
    required this.patientName,
    required this.description,
    required this.status,
    required this.createdAt,
    this.fulfilledAt,
    required this.matchedDonors,
  });

  factory BloodRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BloodRequest(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      requesterPhone: data['requesterPhone'] ?? '',
      bloodType: data['bloodType'] ?? '',
      quantity: data['quantity'] ?? 1,
      urgency: data['urgency'] ?? 'normal',
      hospitalName: data['hospitalName'] ?? '',
      hospitalAddress: data['hospitalAddress'] ?? '',
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      patientName: data['patientName'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      fulfilledAt: data['fulfilledAt'] != null 
          ? (data['fulfilledAt'] as Timestamp).toDate() 
          : null,
      matchedDonors: List<String>.from(data['matchedDonors'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterPhone': requesterPhone,
      'bloodType': bloodType,
      'quantity': quantity,
      'urgency': urgency,
      'hospitalName': hospitalName,
      'hospitalAddress': hospitalAddress,
      'latitude': latitude,
      'longitude': longitude,
      'patientName': patientName,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'fulfilledAt': fulfilledAt != null ? Timestamp.fromDate(fulfilledAt!) : null,
      'matchedDonors': matchedDonors,
    };
  }

  BloodRequest copyWith({
    String? status,
    DateTime? fulfilledAt,
    List<String>? matchedDonors,
  }) {
    return BloodRequest(
      id: id,
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
      status: status ?? this.status,
      createdAt: createdAt,
      fulfilledAt: fulfilledAt ?? this.fulfilledAt,
      matchedDonors: matchedDonors ?? this.matchedDonors,
    );
  }
}