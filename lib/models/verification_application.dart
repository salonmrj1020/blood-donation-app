import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationApplication {
  final String userId;
  final Map<String, dynamic> personalInfo;
  final Map<String, dynamic> medicalInfo;
  final List<String> documentUrls;
  final String status; // pending, approved, rejected
  final DateTime? submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? adminNotes;

  VerificationApplication({
    required this.userId,
    required this.personalInfo,
    required this.medicalInfo,
    required this.documentUrls,
    required this.status,
    this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.adminNotes,
  });

  factory VerificationApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return VerificationApplication(
      userId: data['userId'] ?? '',
      personalInfo: Map<String, dynamic>.from(data['personalInfo'] ?? {}),
      medicalInfo: Map<String, dynamic>.from(data['medicalInfo'] ?? {}),
      documentUrls: List<String>.from(data['documentUrls'] ?? []),
      status: data['status'] ?? 'pending',
      submittedAt: data['submittedAt'] != null 
          ? (data['submittedAt'] as Timestamp).toDate()
          : null,
      reviewedBy: data['reviewedBy'],
      reviewedAt: data['reviewedAt'] != null 
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: data['rejectionReason'],
      adminNotes: data['adminNotes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'personalInfo': personalInfo,
      'medicalInfo': medicalInfo,
      'documentUrls': documentUrls,
      'status': status,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'rejectionReason': rejectionReason,
      'adminNotes': adminNotes,
    };
  }

  // Helper getters
  String get applicantName => personalInfo['fullName'] ?? 'Unknown';
  String get bloodType => personalInfo['bloodType'] ?? 'Unknown';
  String get phoneNumber => personalInfo['phoneNumber'] ?? 'Not provided';
  String get email => personalInfo['email'] ?? 'Not provided';
  int get age => medicalInfo['age'] ?? 0;
  double get weight => (medicalInfo['weight'] ?? 0).toDouble();
  
  bool get isEligible {
    return age >= 18 && age <= 65 && weight >= 45;
  }

  String get statusDisplayText {
    switch (status) {
      case 'pending':
        return 'Under Review';
      case 'approved':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  String get submittedTimeAgo {
    if (submittedAt == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(submittedAt!);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}

class AdminAction {
  final String adminId;
  final String action;
  final String targetUserId;
  final DateTime timestamp;
  final String? notes;
  final String? reason;

  AdminAction({
    required this.adminId,
    required this.action,
    required this.targetUserId,
    required this.timestamp,
    this.notes,
    this.reason,
  });

  factory AdminAction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AdminAction(
      adminId: data['adminId'] ?? '',
      action: data['action'] ?? '',
      targetUserId: data['targetUserId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      notes: data['notes'],
      reason: data['reason'],
    );
  }

  String get actionDisplayText {
    switch (action) {
      case 'approve_verification':
        return 'Approved Verification';
      case 'reject_verification':
        return 'Rejected Verification';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}