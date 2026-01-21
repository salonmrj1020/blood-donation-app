import 'package:cloud_firestore/cloud_firestore.dart';

class Donor {
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String bloodType;
  final DateTime? lastDonationDate;
  final int totalDonations;
  final bool isAvailable;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Donor({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.bloodType,
    this.lastDonationDate,
    required this.totalDonations,
    required this.isAvailable,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.createdAt,
    this.updatedAt,
  });

  factory Donor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Donor(
      userId: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      bloodType: data['bloodType'] ?? '',
      lastDonationDate: data['lastDonationDate'] != null 
          ? (data['lastDonationDate'] as Timestamp).toDate() 
          : null,
      totalDonations: data['totalDonations'] ?? 0,
      isAvailable: data['isAvailable'] ?? true,
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      address: data['address'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'bloodType': bloodType,
      'lastDonationDate': lastDonationDate != null 
          ? Timestamp.fromDate(lastDonationDate!) 
          : null,
      'totalDonations': totalDonations,
      'isAvailable': isAvailable,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null 
          ? Timestamp.fromDate(updatedAt!) 
          : null,
    };
  }

  // Check if donor is eligible to donate (56 days gap)
  bool get isEligible {
    if (lastDonationDate == null) return true;
    final daysSinceLastDonation = DateTime.now().difference(lastDonationDate!).inDays;
    return daysSinceLastDonation >= 56;
  }

  // Get days until next eligible donation
  int get daysUntilEligible {
    if (lastDonationDate == null) return 0;
    final daysSinceLastDonation = DateTime.now().difference(lastDonationDate!).inDays;
    return daysSinceLastDonation >= 56 ? 0 : 56 - daysSinceLastDonation;
  }

  Donor copyWith({
    String? name,
    String? email,
    String? phone,
    String? bloodType,
    DateTime? lastDonationDate,
    int? totalDonations,
    bool? isAvailable,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? updatedAt,
  }) {
    return Donor(
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bloodType: bloodType ?? this.bloodType,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      totalDonations: totalDonations ?? this.totalDonations,
      isAvailable: isAvailable ?? this.isAvailable,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}