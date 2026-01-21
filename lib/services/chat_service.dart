import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  // Create or get existing chat between donor and requester
  Future<String?> createOrGetChat({
    required String requestId,
    required String requesterId,
    required String requesterName,
    required String donorId,
    required String donorName,
  }) async {
    try {
      // Check if chat already exists using proper query
      final existingChats = await _firestore
          .collection('chats')
          .where('requestId', isEqualTo: requestId)
          .where('participants', arrayContains: donorId)
          .limit(1)
          .get();

      if (existingChats.docs.isNotEmpty) {
        return existingChats.docs.first.id;
      }

      // Create new chat
      final chat = Chat(
        id: '',
        requestId: requestId,
        requesterId: requesterId,
        donorId: donorId,
        requesterName: requesterName,
        donorName: donorName,
        lastMessage: 'Chat started',
        lastMessageTime: DateTime.now(),
        participants: [requesterId, donorId],
        isActive: true,
      );

      final docRef = await _firestore
          .collection('chats')
          .add(chat.toFirestore());

      // Send notification to requester that a donor wants to chat
      final currentUser = _authService.currentUser;
      if (currentUser != null && currentUser.uid == donorId) {
        await _notificationService.createNotification(
          userId: requesterId,
          title: '💬 New Chat Request',
          message: '$donorName wants to chat about your blood request',
          type: 'chat_started',
          relatedId: docRef.id,
          data: {
            'chatId': docRef.id,
            'donorName': donorName,
            'requestId': requestId,
          },
          priority: 'normal',
        );
      }

      return docRef.id;
    } catch (e) {
      print('Error creating chat: $e');
      return null;
    }
  }

  // Send message
  Future<bool> sendMessage({
    required String chatId,
    required String message,
    String type = 'text',
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;

      final userData = await _authService.getCurrentUserData();
      final senderName = '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}'.trim();

      final chatMessage = ChatMessage(
        id: '',
        chatId: chatId,
        senderId: user.uid,
        senderName: senderName,
        message: message,
        timestamp: DateTime.now(),
        type: type,
      );

      // Add message to subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(chatMessage.toFirestore());

      // Update chat's last message
      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({
        'lastMessage': message,
        'lastMessageTime': Timestamp.fromDate(DateTime.now()),
      });

      // Send notification to other participant
      final chat = await getChat(chatId);
      if (chat != null) {
        final otherUserId = chat.participants.firstWhere((id) => id != user.uid);
        
        // Use the specialized chat notification method
        await _notificationService.createChatNotification(
          userId: otherUserId,
          senderName: senderName,
          message: message.length > 50 ? '${message.substring(0, 50)}...' : message,
          chatId: chatId,
          type: 'chat_message',
          additionalData: {
            'senderId': user.uid,
            'messageType': type,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        
        print('✅ Chat notification sent to $otherUserId from $senderName');
      }

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Get chat messages stream
  Stream<List<ChatMessage>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  // Get user's chats using proper server-side filtering
  Stream<List<Chat>> getUserChats() {
    final user = _authService.currentUser;
    if (user == null) return Stream.value([]);

    try {
      return _firestore
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .where('isActive', isEqualTo: true)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Chat.fromFirestore(doc))
              .toList())
          .handleError((error) {
            print('Error getting user chats: $error');
            // If index is still building, use a simpler query
            if (error.toString().contains('failed-precondition')) {
              return _firestore
                  .collection('chats')
                  .where('participants', arrayContains: user.uid)
                  .snapshots()
                  .map((snapshot) => snapshot.docs
                      .map((doc) => Chat.fromFirestore(doc))
                      .where((chat) => chat.isActive)
                      .toList()
                      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime)));
            }
            throw error;
          });
    } catch (e) {
      print('Error setting up chats stream: $e');
      return Stream.value([]);
    }
  }

  // Get specific chat
  Future<Chat?> getChat(String chatId) async {
    try {
      final doc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();

      if (doc.exists) {
        return Chat.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting chat: $e');
      return null;
    }
  }

  // Send SMS
  Future<void> sendSMS(String phoneNumber, String message) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      throw Exception('Could not send SMS');
    }
  }

  // Open WhatsApp
  Future<void> openWhatsApp(String phoneNumber, String message) async {
    // Remove any non-digit characters and ensure proper format
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add country code if not present (assuming Nepal +977)
    if (!cleanNumber.startsWith('977') && cleanNumber.length == 10) {
      cleanNumber = '977$cleanNumber';
    }

    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$cleanNumber?text=${Uri.encodeComponent(message)}'
    );

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not open WhatsApp');
    }
  }

  // Create test chat for debugging
  Future<void> createTestChat() async {
    final user = _authService.currentUser;
    if (user == null) {
      print('No authenticated user for test chat');
      return;
    }

    try {
      final testChat = Chat(
        id: '',
        requestId: 'test_request_123',
        requesterId: user.uid,
        donorId: 'test_donor_456',
        requesterName: 'Test Requester',
        donorName: 'Test Donor',
        lastMessage: 'This is a test chat message for debugging purposes.',
        lastMessageTime: DateTime.now(),
        participants: [user.uid, 'test_donor_456'],
        isActive: true,
      );

      await _firestore
          .collection('chats')
          .add(testChat.toFirestore());

      print('Test chat created successfully');
    } catch (e) {
      print('Error creating test chat: $e');
    }
  }

  // Close chat
  Future<bool> closeChat(String chatId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({'isActive': false});
      return true;
    } catch (e) {
      print('Error closing chat: $e');
      return false;
    }
  }

  // Mark chat as read (update last read timestamp for user)
  Future<void> markChatAsRead(String chatId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('readStatus')
          .doc(user.uid)
          .set({
        'lastReadAt': Timestamp.now(),
        'userId': user.uid,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }

  // Get unread chat count for current user
  Stream<int> getUnreadChatCount() {
    final user = _authService.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      int unreadCount = 0;
      
      for (var doc in snapshot.docs) {
        final chat = Chat.fromFirestore(doc);
        
        // Get the last message to check if it was sent by current user
        final lastMessageQuery = await _firestore
            .collection('chats')
            .doc(chat.id)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
            
        if (lastMessageQuery.docs.isEmpty) continue;
        
        final lastMessage = ChatMessage.fromFirestore(lastMessageQuery.docs.first);
        
        // Don't count as unread if current user sent the last message
        if (lastMessage.senderId == user.uid) continue;
        
        // Get last read timestamp for this user
        final readStatusDoc = await _firestore
            .collection('chats')
            .doc(chat.id)
            .collection('readStatus')
            .doc(user.uid)
            .get();
            
        DateTime? lastReadAt;
        if (readStatusDoc.exists) {
          lastReadAt = (readStatusDoc.data()?['lastReadAt'] as Timestamp?)?.toDate();
        }
        
        // If no read status or last message is after last read time, count as unread
        if (lastReadAt == null || lastMessage.timestamp.isAfter(lastReadAt)) {
          unreadCount++;
        }
      }
      
      return unreadCount;
    }).handleError((error) {
      print('Error getting unread chat count: $error');
      return 0;
    });
  }
  Future<void> callDonor(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      throw Exception('Could not make phone call');
    }
  }
}