import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final String requestId;
  final String requesterId;
  final String donorId;
  final String requesterName;
  final String donorName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final List<String> participants;
  final bool isActive;

  Chat({
    required this.id,
    required this.requestId,
    required this.requesterId,
    required this.donorId,
    required this.requesterName,
    required this.donorName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.participants,
    required this.isActive,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      requestId: data['requestId'] ?? '',
      requesterId: data['requesterId'] ?? '',
      donorId: data['donorId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      donorName: data['donorName'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      participants: List<String>.from(data['participants'] ?? []),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requestId': requestId,
      'requesterId': requesterId,
      'donorId': donorId,
      'requesterName': requesterName,
      'donorName': donorName,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'participants': participants,
      'isActive': isActive,
    };
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final String type; // 'text', 'image', 'location'

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.type,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'] ?? 'text',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
    };
  }
}