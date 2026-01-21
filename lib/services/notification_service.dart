import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:permission_handler/permission_handler.dart';  // Temporarily disabled
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  bool _isInitialized = false;

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Initialize Firebase messaging
      await _initializeFirebaseMessaging();

      // Subscribe to user's blood type topic
      await _subscribeToUserBloodType();

      _isInitialized = true;
      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    // Request Firebase messaging permission
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('Firebase messaging permission: ${settings.authorizationStatus}');
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'blood_donation_channel',
      'Blood Donation Notifications',
      description: 'Notifications for blood donation requests and updates',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    print('Local notifications initialized successfully');
  }

  // Initialize Firebase messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    // Save token to Firestore
    await _saveFCMToken(token);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app is terminated
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);
  }

  // Save FCM token to Firestore
  Future<void> _saveFCMToken(String? token) async {
    if (token == null) return;

    final user = _authService.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'tokenUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Subscribe to user's blood type notifications
  Future<void> _subscribeToUserBloodType() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Get user's donor profile
      final donorDoc = await _firestore
          .collection('donors')
          .doc(user.uid)
          .get();

      if (donorDoc.exists) {
        final bloodType = donorDoc.data()?['bloodType'];
        if (bloodType != null) {
          await _firebaseMessaging.subscribeToTopic('blood_type_$bloodType');
          await _firebaseMessaging.subscribeToTopic('emergency_requests');
          print('Subscribed to blood type: $bloodType');
        }
      }
    } catch (e) {
      print('Error subscribing to blood type: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');
    
    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'Blood Donation Alert',
      body: message.notification?.body ?? 'New blood request available',
      payload: message.data.toString(),
    );

    // Save notification to Firestore
    _saveNotificationToFirestore(message);
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Received background message: ${message.messageId}');
    // Background message handling is limited
    // Most processing should be done when app is opened
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.messageId}');
    
    // Navigate to appropriate screen based on notification data
    final data = message.data;
    if (data.containsKey('requestId')) {
      // Navigate to blood request detail screen
      // This would be handled by the main app navigation
    } else if (data.containsKey('chatId')) {
      // Navigate to chat screen
      // This would be handled by the main app navigation
    }
  }

  // Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Local notification tapped: ${response.payload}');
    // Handle local notification tap - could navigate to specific screens
    // For chat notifications, we could navigate directly to the chat screen
    // This would be handled by the main app navigation system
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'blood_donation_channel',
      'Blood Donation Notifications',
      channelDescription: 'Notifications for blood donation requests and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    print(' Local notification shown: $title');
  }

  // Send emergency notification to matched donors
  Future<void> sendEmergencyNotification({
    required String requestId,
    required String bloodType,
    required String hospitalName,
    required String urgency,
    required List<String> donorIds,
  }) async {
    try {
      // Create notification data
      final notificationData = {
        'requestId': requestId,
        'bloodType': bloodType,
        'hospitalName': hospitalName,
        'urgency': urgency,
        'timestamp': Timestamp.now(),
        'type': 'emergency_blood_request',
      };

      // Send to specific donors
      for (String donorId in donorIds) {
        await _sendNotificationToUser(
          userId: donorId,
          title: '🚨 Emergency Blood Request',
          body: 'Urgent $bloodType blood needed at $hospitalName',
          data: notificationData,
        );
      }

      // Also send to blood type topic for broader reach
      await _sendNotificationToTopic(
        topic: 'blood_type_$bloodType',
        title: '🩸 Blood Request - $bloodType',
        body: '$urgency blood request at $hospitalName',
        data: notificationData,
      );

    } catch (e) {
      print('Error sending emergency notification: $e');
    }
  }

  // Send notification to specific user
  Future<void> _sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken == null) return;

      // This would typically be done via Firebase Cloud Functions
      // For now, we'll save the notification to Firestore
      await _firestore
          .collection('notifications')
          .add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
        'fcmToken': fcmToken,
        'sent': false,
        'createdAt': Timestamp.now(),
      });

    } catch (e) {
      print('Error sending notification to user: $e');
    }
  }

  // Send notification to topic
  Future<void> _sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // This would typically be done via Firebase Cloud Functions
      // For now, we'll save the notification to Firestore
      await _firestore
          .collection('topicNotifications')
          .add({
        'topic': topic,
        'title': title,
        'body': body,
        'data': data,
        'sent': false,
        'createdAt': Timestamp.now(),
      });

    } catch (e) {
      print('Error sending notification to topic: $e');
    }
  }

  // Save notification to Firestore for history
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      await _firestore
          .collection('userNotifications')
          .add({
        'userId': user.uid,
        'messageId': message.messageId,
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data,
        'receivedAt': Timestamp.now(),
        'read': false,
      });

    } catch (e) {
      print('Error saving notification: $e');
    }
  }

  // Get user notifications using simplified query (excluding chat messages)
  Stream<List<AppNotification>> getUserNotifications() {
    final user = _authService.currentUser;
    if (user == null) return Stream.value([]);

    try {
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
            List<AppNotification> notifications = [];
            for (var doc in snapshot.docs) {
              try {
                final notification = AppNotification.fromFirestore(doc);
                // Include only non-chat notifications
                if (notification.type != 'chat_message' && 
                    notification.type != 'chat_started') {
                  notifications.add(notification);
                }
              } catch (e) {
                print('Error parsing notification document: $e');
              }
            }
            // Sort by creation date (newest first)
            notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return notifications.take(50).toList();
          })
          .handleError((error) {
            print('Error getting user notifications: $error');
            return <AppNotification>[];
          });
    } catch (e) {
      print('Error setting up notifications stream: $e');
      return Stream.value([]);
    }
  }

  // Get chat notifications separately for chat badge using simplified query
  Stream<List<AppNotification>> getChatNotifications() {
    final user = _authService.currentUser;
    if (user == null) return Stream.value([]);

    try {
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
            List<AppNotification> notifications = [];
            for (var doc in snapshot.docs) {
              try {
                final notification = AppNotification.fromFirestore(doc);
                // Include only chat notifications
                if (notification.type == 'chat_message' || 
                    notification.type == 'chat_started') {
                  notifications.add(notification);
                }
              } catch (e) {
                print('Error parsing chat notification document: $e');
              }
            }
            // Sort by creation date (newest first)
            notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return notifications.take(50).toList();
          })
          .handleError((error) {
            print('Error getting chat notifications: $error');
            return <AppNotification>[];
          });
    } catch (e) {
      print('Error setting up chat notifications stream: $e');
      return Stream.value([]);
    }
  }

  // Get unread notification count using simplified query (excluding chat messages)
  Stream<int> getUnreadCount() {
    final user = _authService.currentUser;
    if (user == null) return Stream.value(0);

    try {
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
            int count = 0;
            for (var doc in snapshot.docs) {
              try {
                final notification = AppNotification.fromFirestore(doc);
                // Count unread notifications that are not chat messages
                if (!notification.isRead && 
                    notification.type != 'chat_message' && 
                    notification.type != 'chat_started') {
                  count++;
                }
              } catch (e) {
                print('Error parsing notification document: $e');
              }
            }
            print('📊 General notification count: $count');
            return count;
          })
          .handleError((error) {
            print('Error getting unread count: $error');
            return 0;
          });
    } catch (e) {
      print('Error setting up unread count stream: $e');
      return Stream.value(0);
    }
  }

  // Get unread chat notification count using simplified query
  Stream<int> getUnreadChatNotificationCount() {
    final user = _authService.currentUser;
    if (user == null) return Stream.value(0);

    try {
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
            int count = 0;
            for (var doc in snapshot.docs) {
              try {
                final notification = AppNotification.fromFirestore(doc);
                // Count unread chat notifications
                if (!notification.isRead && 
                    (notification.type == 'chat_message' || 
                     notification.type == 'chat_started')) {
                  count++;
                }
              } catch (e) {
                print('Error parsing chat notification document: $e');
              }
            }
            print('💬 Chat notification count: $count');
            return count;
          })
          .handleError((error) {
            print('Error getting unread chat notification count: $error');
            return 0;
          });
    } catch (e) {
      print('Error setting up unread chat notification count stream: $e');
      return Stream.value(0);
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print('All notifications marked as read');
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Mark all chat notifications as read
  Future<void> markAllChatNotificationsAsRead() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        final notification = AppNotification.fromFirestore(doc);
        if (notification.type == 'chat_message' || notification.type == 'chat_started') {
          batch.update(doc.reference, {'isRead': true});
        }
      }

      await batch.commit();
      print('All chat notifications marked as read');
    } catch (e) {
      print('Error marking all chat notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }


  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    Map<String, dynamic>? data,
    String priority = 'normal',
  }) async {
    try {
      print('🔔 Creating notification for user: $userId');
      print('   Title: $title');
      print('   Type: $type, Priority: $priority');
      print('   Message: $message');

      final notification = AppNotification(
        id: '',
        userId: userId,
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        data: data,
        isRead: false,
        createdAt: DateTime.now(),
        priority: priority,
      );

      final docRef = await _firestore
          .collection('notifications')
          .add(notification.toFirestore());

      print('✅ Notification created successfully with ID: ${docRef.id}');

      // Show popup notification if it's for the current user
      final currentUser = _authService.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        await _showLocalNotification(
          title: title,
          body: message,
          payload: docRef.id,
        );
        print('📱 Popup notification shown for current user');
      } else {
        print('📱 Notification created for different user: $userId (current: ${currentUser?.uid})');
      }
    } catch (e) {
      print('❌ Error creating notification: $e');
      throw e; // Re-throw to let caller handle
    }
  }

  // Create chat notification with special handling
  Future<void> createChatNotification({
    required String userId,
    required String senderName,
    required String message,
    required String chatId,
    String type = 'chat_message',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('💬 Creating chat notification for user: $userId');
      print('   Sender: $senderName');
      print('   Chat ID: $chatId');
      print('   Message: $message');
      
      // Create notification with chat-specific formatting
      final data = {
        'chatId': chatId,
        'senderName': senderName,
        ...?additionalData,
      };

      await createNotification(
        userId: userId,
        title: '💬 $senderName',
        message: message,
        type: type,
        relatedId: chatId,
        data: data,
        priority: 'normal',
      );

      print('✅ Chat notification created for user: $userId');
    } catch (e) {
      print('❌ Error creating chat notification: $e');
    }
  }
  Future<void> updateNotificationPreferences({
    required bool emergencyAlerts,
    required bool regularRequests,
    required List<String> bloodTypesToReceive,
    required double locationRadius,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'notificationPreferences': {
          'emergencyAlerts': emergencyAlerts,
          'regularRequests': regularRequests,
          'bloodTypesToReceive': bloodTypesToReceive,
          'locationRadius': locationRadius,
          'updatedAt': Timestamp.now(),
        }
      });

      // Update topic subscriptions
      await _updateTopicSubscriptions(bloodTypesToReceive);

    } catch (e) {
      print('Error updating notification preferences: $e');
    }
  }

  // Update topic subscriptions based on preferences
  Future<void> _updateTopicSubscriptions(List<String> bloodTypes) async {
    try {
      // Unsubscribe from all blood type topics first
      final allBloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
      for (String bloodType in allBloodTypes) {
        await _firebaseMessaging.unsubscribeFromTopic('blood_type_$bloodType');
      }

      // Subscribe to selected blood types
      for (String bloodType in bloodTypes) {
        await _firebaseMessaging.subscribeToTopic('blood_type_$bloodType');
      }

    } catch (e) {
      print('Error updating topic subscriptions: $e');
    }
  }

  // Get notification preferences
  Future<Map<String, dynamic>?> getNotificationPreferences() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data()?['notificationPreferences'];
      }
      return null;
    } catch (e) {
      print('Error getting notification preferences: $e');
      return null;
    }
  }
}