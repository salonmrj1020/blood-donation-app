import 'package:cloud_firestore/cloud_firestore.dart';

class DonationRecord {
  final String id;
  final String donorId;
  final String donorName;
  final String requestId;
  final String requesterId;
  final String requesterName;
  final String bloodType;
  final int quantity;
  final String hospitalName;
  final String hospitalAddress;
  final DateTime donationDate;
  final String status; // 'pending', 'completed', 'cancelled'
  final String? notes;
  final DateTime createdAt;
  final DateTime? completedAt;

  DonationRecord({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.requestId,
    required this.requesterId,
    required this.requesterName,
    required this.bloodType,
    required this.quantity,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.donationDate,
    required this.status,
    this.notes,
    required this.createdAt,
    this.completedAt,
  });

  factory DonationRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DonationRecord(
      id: doc.id,
      donorId: data['donorId'] ?? '',
      donorName: data['donorName'] ?? '',
      requestId: data['requestId'] ?? '',
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      bloodType: data['bloodType'] ?? '',
      quantity: data['quantity'] ?? 1,
      hospitalName: data['hospitalName'] ?? '',
      hospitalAddress: data['hospitalAddress'] ?? '',
      donationDate: (data['donationDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'donorId': donorId,
      'donorName': donorName,
      'requestId': requestId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'bloodType': bloodType,
      'quantity': quantity,
      'hospitalName': hospitalName,
      'hospitalAddress': hospitalAddress,
      'donationDate': Timestamp.fromDate(donationDate),
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  DonationRecord copyWith({
    String? status,
    String? notes,
    DateTime? completedAt,
  }) {
    return DonationRecord(
      id: id,
      donorId: donorId,
      donorName: donorName,
      requestId: requestId,
      requesterId: requesterId,
      requesterName: requesterName,
      bloodType: bloodType,
      quantity: quantity,
      hospitalName: hospitalName,
      hospitalAddress: hospitalAddress,
      donationDate: donationDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // Helper methods
  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  String get statusDisplayText {
    switch (status) {
      case 'pending':
        return 'Pending Donation';
      case 'completed':
        return 'Donated';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get formattedDonationDate {
    final now = DateTime.now();
    final difference = now.difference(donationDate);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }
}