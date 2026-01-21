import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donor.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  // Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;

      // Check if user email matches admin email
      const String ADMIN_EMAIL = 'demo2026@gmail.com';
      return user.email == ADMIN_EMAIL;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Create admin user (simplified for single admin)
  Future<String?> createAdmin(String email) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return 'User not authenticated';

      // Only allow creating admin for the specific email
      const String ADMIN_EMAIL = 'demo2026@gmail.com';
      if (email != ADMIN_EMAIL) {
        return 'Unauthorized admin email';
      }

      // Check if admin record already exists
      final adminDoc = await _firestore.collection('admins').doc(user.uid).get();
      if (adminDoc.exists) {
        print('Admin record already exists');
        return null; // Success - admin already exists
      }

      // Get user data
      final userData = await _authService.getCurrentUserData();
      if (userData == null) {
        // Create basic user data for admin
        await _authService.updateUserProfile(
          firstName: 'Admin',
          lastName: 'User',
          phone: '+1234567890',
        );
      }

      // Create admin record
      await _firestore.collection('admins').doc(user.uid).set({
        'email': email,
        'name': 'Admin User',
        'createdAt': Timestamp.now(),
        'role': 'admin',
        'permissions': [
          'verify_donors',
          'reject_donors',
          'view_all_donors',
          'manage_blood_requests',
          'view_analytics'
        ],
      });

      print('Admin record created successfully');
      return null; // Success
    } catch (e) {
      print('Error creating admin: $e');
      return 'Failed to create admin';
    }
  }

  // Get all pending donor applications
  Future<List<Map<String, dynamic>>> getPendingDonorApplications() async {
    try {
      print('Fetching pending donor applications...');
      
      // First, let's get ALL donors to see what's in the database
      final allDonorsSnapshot = await _firestore
          .collection('donors')
          .get();
      
      print('Total donors in database: ${allDonorsSnapshot.docs.length}');
      for (var doc in allDonorsSnapshot.docs) {
        final data = doc.data();
        print('Donor ${doc.id}: status = ${data['verificationStatus']}, createdAt = ${data['createdAt']}');
      }
      
      // Now try the specific query WITHOUT orderBy to avoid index issues
      final snapshot = await _firestore
          .collection('donors')
          .where('verificationStatus', isEqualTo: 'pending')
          .get();

      print('Found ${snapshot.docs.length} pending applications with query');
      
      List<Map<String, dynamic>> applications = [];

      for (var doc in snapshot.docs) {
        final donorData = doc.data();
        print('Processing pending donor: ${doc.id}, status: ${donorData['verificationStatus']}');
        
        // Get user data for additional information
        final userDoc = await _firestore
            .collection('users')
            .doc(doc.id)
            .get();

        Map<String, dynamic> userData = {};
        if (userDoc.exists) {
          userData = userDoc.data()!;
          print('Found user data for ${doc.id}: ${userData['firstName']} ${userData['lastName']}');
        } else {
          print('No user data found for ${doc.id}');
          // Create minimal user data if not found
          userData = {
            'firstName': 'Unknown',
            'lastName': 'User',
            'email': donorData['email'] ?? 'unknown@email.com',
            'phone': donorData['phone'] ?? 'Unknown',
          };
        }

        applications.add({
          'donorId': doc.id,
          'donorData': donorData,
          'userData': userData,
          'applicationDate': donorData['createdAt'],
        });
      }

      print('Returning ${applications.length} applications');
      return applications;
    } catch (e) {
      print('Error getting pending applications: $e');
      return [];
    }
  }

  // Get all verified donors
  Future<List<Map<String, dynamic>>> getVerifiedDonors() async {
    try {
      final snapshot = await _firestore
          .collection('donors')
          .where('verificationStatus', isEqualTo: 'verified')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> donors = [];

      for (var doc in snapshot.docs) {
        final donorData = doc.data();
        
        // Get user data for additional information
        final userDoc = await _firestore
            .collection('users')
            .doc(doc.id)
            .get();

        Map<String, dynamic> userData = {};
        if (userDoc.exists) {
          userData = userDoc.data()!;
        }

        donors.add({
          'donorId': doc.id,
          'donorData': donorData,
          'userData': userData,
          'verificationDate': donorData['verifiedAt'],
        });
      }

      return donors;
    } catch (e) {
      print('Error getting verified donors: $e');
      return [];
    }
  }

  // Get all rejected donor applications
  Future<List<Map<String, dynamic>>> getRejectedDonorApplications() async {
    try {
      final snapshot = await _firestore
          .collection('donors')
          .where('verificationStatus', isEqualTo: 'rejected')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> applications = [];

      for (var doc in snapshot.docs) {
        final donorData = doc.data();
        
        // Get user data for additional information
        final userDoc = await _firestore
            .collection('users')
            .doc(doc.id)
            .get();

        Map<String, dynamic> userData = {};
        if (userDoc.exists) {
          userData = userDoc.data()!;
        }

        applications.add({
          'donorId': doc.id,
          'donorData': donorData,
          'userData': userData,
          'rejectionDate': donorData['rejectedAt'],
          'rejectionReason': donorData['rejectionReason'],
        });
      }

      return applications;
    } catch (e) {
      print('Error getting rejected applications: $e');
      return [];
    }
  }

  // Verify donor application
  Future<String?> verifyDonorApplication(String donorId, String adminNotes) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return 'Admin not authenticated';

      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) return 'Unauthorized: Admin access required';

      await _firestore.collection('donors').doc(donorId).update({
        'verificationStatus': 'verified',
        'verifiedAt': Timestamp.now(),
        'verifiedBy': user.uid,
        'adminNotes': adminNotes,
        'isAvailable': true, // Make donor available after verification
      });

      // Create verification log
      await _firestore.collection('verification_logs').add({
        'donorId': donorId,
        'action': 'verified',
        'adminId': user.uid,
        'adminNotes': adminNotes,
        'timestamp': Timestamp.now(),
      });

      // Send professional verification notification
      await _sendVerificationNotification(donorId, true, adminNotes);

      return null; // Success
    } catch (e) {
      print('Error verifying donor: $e');
      return 'Failed to verify donor';
    }
  }

  // Reject donor application
  Future<String?> rejectDonorApplication(String donorId, String reason, String adminNotes) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return 'Admin not authenticated';

      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) return 'Unauthorized: Admin access required';

      await _firestore.collection('donors').doc(donorId).update({
        'verificationStatus': 'rejected',
        'rejectedAt': Timestamp.now(),
        'rejectedBy': user.uid,
        'rejectionReason': reason,
        'adminNotes': adminNotes,
        'isAvailable': false, // Make donor unavailable after rejection
      });

      // Create verification log
      await _firestore.collection('verification_logs').add({
        'donorId': donorId,
        'action': 'rejected',
        'adminId': user.uid,
        'rejectionReason': reason,
        'adminNotes': adminNotes,
        'timestamp': Timestamp.now(),
      });

      // Send professional rejection notification
      await _sendVerificationNotification(donorId, false, adminNotes, reason);

      return null; // Success
    } catch (e) {
      print('Error rejecting donor: $e');
      return 'Failed to reject donor';
    }
  }

  // Send professional notification after verification/rejection
  Future<void> _sendVerificationNotification(String donorId, bool isVerified, String adminNotes, [String? rejectionReason]) async {
    try {
      // Get donor information
      final donorDoc = await _firestore.collection('donors').doc(donorId).get();
      if (!donorDoc.exists) return;
      
      final donorData = donorDoc.data()!;
      final donorName = donorData['name'] ?? 'Donor';
      
      String title;
      String message;
      String type;
      
      if (isVerified) {
        title = '🎉 Donor Application Approved';
        message = '''Dear $donorName,

Congratulations! Your blood donor application has been successfully verified and approved by our medical team.

✅ Verification Status: APPROVED
🩸 Blood Type: ${donorData['bloodType'] ?? 'N/A'}
📅 Approved Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}

You are now an official blood donor in our network and can start helping save lives! Your profile is now visible to those in need of blood donations.

What's Next:
• Your donor profile is now active
• You'll receive notifications for blood requests matching your blood type
• You can view and respond to blood requests in the app
• Remember to maintain good health and follow donation guidelines

Thank you for your commitment to saving lives through blood donation. Your generosity makes a real difference in our community.

Best regards,
Blood Donation App Medical Team

${adminNotes.isNotEmpty ? '\nAdmin Notes: $adminNotes' : ''}''';
        type = 'verification_approved';
      } else {
        title = '❌ Donor Application Status Update';
        message = '''Dear $donorName,

Thank you for your interest in becoming a blood donor. After careful review by our medical team, we regret to inform you that your donor application could not be approved at this time.

❌ Verification Status: NOT APPROVED
📅 Review Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}
📋 Reason: ${rejectionReason ?? 'Please contact support for details'}

This decision is made to ensure the safety and well-being of both donors and recipients, following strict medical guidelines and regulations.

What You Can Do:
• Contact our support team if you have questions about this decision
• You may reapply in the future if your circumstances change
• Consider other ways to support our blood donation community

We appreciate your willingness to help save lives and encourage you to stay connected with our community.

For questions or support, please contact us through the app.

Best regards,
Blood Donation App Medical Team

${adminNotes.isNotEmpty ? '\nAdmin Notes: $adminNotes' : ''}''';
        type = 'verification_rejected';
      }

      // Use NotificationService to create notification with popup
      await _notificationService.createNotification(
        userId: donorId,
        title: title,
        message: message,
        type: type,
        priority: isVerified ? 'high' : 'normal',
        data: {
          'donorId': donorId,
          'verificationStatus': isVerified ? 'verified' : 'rejected',
          'rejectionReason': rejectionReason,
          'adminNotes': adminNotes,
        },
      );

      print('✅ Professional notification with popup sent successfully!');
      print('   → Recipient: $donorName (ID: $donorId)');
      print('   → Type: ${isVerified ? 'APPROVED' : 'REJECTED'}');
      print('   → Title: $title');
      print('Professional notification sent to donor $donorId: ${isVerified ? 'Approved' : 'Rejected'}');
    } catch (e) {
      print('Error sending verification notification: $e');
    }
  }

  // Get admin dashboard statistics
  Future<Map<String, dynamic>> getAdminDashboardStats() async {
    try {
      print('Fetching admin dashboard stats...');
      
      // Get counts for different donor statuses
      final pendingSnapshot = await _firestore
          .collection('donors')
          .where('verificationStatus', isEqualTo: 'pending')
          .get();
      print('Pending donors: ${pendingSnapshot.docs.length}');

      final verifiedSnapshot = await _firestore
          .collection('donors')
          .where('verificationStatus', isEqualTo: 'verified')
          .get();
      print('Verified donors: ${verifiedSnapshot.docs.length}');

      final rejectedSnapshot = await _firestore
          .collection('donors')
          .where('verificationStatus', isEqualTo: 'rejected')
          .get();
      print('Rejected donors: ${rejectedSnapshot.docs.length}');

      // Get total blood requests
      final bloodRequestsSnapshot = await _firestore
          .collection('bloodRequests')
          .get();
      print('Blood requests: ${bloodRequestsSnapshot.docs.length}');

      // Get recent activity (last 7 days)
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentApplicationsSnapshot = await _firestore
          .collection('donors')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .get();
      print('Recent applications: ${recentApplicationsSnapshot.docs.length}');

      final stats = {
        'pendingApplications': pendingSnapshot.docs.length,
        'verifiedDonors': verifiedSnapshot.docs.length,
        'rejectedApplications': rejectedSnapshot.docs.length,
        'totalBloodRequests': bloodRequestsSnapshot.docs.length,
        'recentApplications': recentApplicationsSnapshot.docs.length,
        'totalDonors': pendingSnapshot.docs.length + verifiedSnapshot.docs.length + rejectedSnapshot.docs.length,
      };
      
      print('Final stats: $stats');
      return stats;
    } catch (e) {
      print('Error getting admin stats: $e');
      return {
        'pendingApplications': 0,
        'verifiedDonors': 0,
        'rejectedApplications': 0,
        'totalBloodRequests': 0,
        'recentApplications': 0,
        'totalDonors': 0,
      };
    }
  }

  // Get verification logs
  Future<List<Map<String, dynamic>>> getVerificationLogs({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('verification_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> logs = [];

      for (var doc in snapshot.docs) {
        final logData = doc.data();
        
        // Get admin data
        final adminDoc = await _firestore
            .collection('users')
            .doc(logData['adminId'])
            .get();

        String adminName = 'Unknown Admin';
        if (adminDoc.exists) {
          final adminData = adminDoc.data()!;
          adminName = '${adminData['firstName'] ?? ''} ${adminData['lastName'] ?? ''}'.trim();
        }

        // Get donor data
        final donorDoc = await _firestore
            .collection('users')
            .doc(logData['donorId'])
            .get();

        String donorName = 'Unknown Donor';
        if (donorDoc.exists) {
          final donorData = donorDoc.data()!;
          donorName = '${donorData['firstName'] ?? ''} ${donorData['lastName'] ?? ''}'.trim();
        }

        logs.add({
          'logId': doc.id,
          'donorId': logData['donorId'],
          'donorName': donorName,
          'adminId': logData['adminId'],
          'adminName': adminName,
          'action': logData['action'],
          'timestamp': logData['timestamp'],
          'adminNotes': logData['adminNotes'],
          'rejectionReason': logData['rejectionReason'],
        });
      }

      return logs;
    } catch (e) {
      print('Error getting verification logs: $e');
      return [];
    }
  }
}