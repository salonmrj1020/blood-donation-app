import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'blood_request', 'donation_match', 'chat_message', 'system'
  final String? relatedId; // ID of related blood request, chat, etc.
  final Map<String, dynamic>? data; // Additional data
  final bool isRead;
  final DateTime createdAt;
  final String priority; // 'low', 'normal', 'high', 'urgent'

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    this.data,
    required this.isRead,
    required this.createdAt,
    required this.priority,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'system',
      relatedId: data['relatedId'],
      data: data['data'] != null ? Map<String, dynamic>.from(data['data']) : null,
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      priority: data['priority'] ?? 'normal',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'relatedId': relatedId,
      'data': data,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'priority': priority,
    };
  }

  AppNotification copyWith({
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      relatedId: relatedId,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      priority: priority,
    );
  }

  // Helper methods
  bool get isUrgent => priority == 'urgent';
  bool get isHigh => priority == 'high';
  
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}