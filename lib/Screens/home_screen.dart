import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/donor_service.dart';
import '../services/blood_request_service.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';
import '../models/blood_request.dart';
import 'package:blood_donation_app/Screens/notifications_screen.dart';
import 'package:blood_donation_app/Screens/inbox_screen.dart';
import 'package:blood_donation_app/Screens/search_screen.dart';
import 'package:blood_donation_app/Screens/blood_request_list_screen.dart';
import 'package:blood_donation_app/Screens/blood_request_detail_screen.dart';
import 'package:blood_donation_app/Screens/create_blood_request_screen.dart';
import 'package:blood_donation_app/Screens/become_donor_screen.dart';
import 'package:blood_donation_app/Screens/donor_list_screen.dart';
import 'package:blood_donation_app/Screens/more_screen.dart';
import 'package:blood_donation_app/Screens/login_screen.dart';
import 'package:blood_donation_app/Screens/settings_screen.dart';
import 'package:blood_donation_app/Screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _donorService = DonorService();
  final _bloodRequestService = BloodRequestService();
  final _notificationService = NotificationService();
  final _chatService = ChatService();
  
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _donationStats;
  Map<String, dynamic>? _donorStatus;
  List<BloodRequest> _recentRequests = [];
  List<BloodRequest> _recentlyViewed = [];
  bool _isLoading = true;
  bool _hasDonorProfile = false;
  int _currentIndex = 0;
  
  // Badge counts
  int _unreadNotificationCount = 0;
  int _unreadChatCount = 0;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupUnreadCountListeners();
  }

  void _setupUnreadCountListeners() {
    print('🔔 Setting up notification badge listeners...');
    
    // Listen for unread notification count (excluding chat)
    _notificationService.getUnreadCount().listen((count) {
      print('📊 Received general notification count: $count');
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
        print('📊 Updated general notification badge: $count');
      }
    }).onError((error) {
      print('❌ Error in notification count listener: $error');
      if (mounted) {
        setState(() {
          _unreadNotificationCount = 0;
        });
      }
    });

    // Listen for unread chat notification count
    _notificationService.getUnreadChatNotificationCount().listen((count) {
      print('💬 Received chat notification count: $count');
      if (mounted) {
        setState(() {
          _unreadChatCount = count;
        });
        print('💬 Updated chat notification badge: $count');
      }
    }).onError((error) {
      print('❌ Error in chat notification count listener: $error');
      if (mounted) {
        setState(() {
          _unreadChatCount = 0;
        });
      }
    });
    
    print('✅ Notification badge listeners set up successfully');
  }



  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        // Load user data
        final userData = await _authService.getCurrentUserData();
        
        if (userData != null && mounted) {
          setState(() {
            _userData = userData;
          });
        }

        // Check if user has donor profile and get status
        final hasDonorProfile = await _donorService.hasDonorProfile();
        if (mounted) {
          setState(() {
            _hasDonorProfile = hasDonorProfile;
          });
        }

        // Load donor status if user has donor profile
        if (hasDonorProfile) {
          // Load donor status directly from Firestore to get verification fields
          final donorDoc = await FirebaseFirestore.instance
              .collection('donors')
              .doc(user.uid)
              .get();
              
          if (donorDoc.exists && mounted) {
            final donorData = donorDoc.data()!;
            setState(() {
              _donorStatus = {
                'verificationStatus': donorData['verificationStatus'] ?? 'pending',
                'bloodType': donorData['bloodType'] ?? '',
                'isAvailable': donorData['isAvailable'] ?? false,
                'rejectionReason': donorData['rejectionReason'],
              };
            });
            
            print('=== DONOR STATUS DEBUG ===');
            print('User: ${user.email}');
            print('Verification Status: ${donorData['verificationStatus']}');
            print('Blood Type: ${donorData['bloodType']}');
            print('Rejection Reason: ${donorData['rejectionReason']}');
          }
        }

        // Load donation stats if user is a donor
        if (hasDonorProfile) {
          final stats = await _donorService.getDonationStats(user.uid);
          if (mounted) {
            setState(() {
              _donationStats = stats;
            });
          }
        }

        // Load recent blood requests using stream
        _bloodRequestService.getBloodRequestsStream().listen((requests) {
          if (mounted) {
            setState(() {
              _recentRequests = requests.take(5).toList();
            });
          }
        });

        // Load recently viewed requests (you can implement this based on user's view history)
        final recentlyViewed = await _bloodRequestService.getBloodRequests(limit: 3);
        if (mounted) {
          setState(() {
            _recentlyViewed = recentlyViewed;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: _buildSideDrawer(), // Add side drawer
      body: _currentIndex == 0 ? _buildHomeContent() : _buildOtherScreens(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildSideDrawer() {
    final firstName = _userData?['firstName'] ?? 'User';
    final lastName = _userData?['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showProfileScreen(),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: _userData?['profileImage'] != null && !_userData!['profileImage'].toString().startsWith('placeholder_')
                            ? Image.network(
                                _userData!['profileImage'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    color: Colors.grey[600],
                                    size: 30,
                                  );
                                },
                              )
                            : Icon(
                                Icons.person,
                                color: Colors.grey[600],
                                size: 30,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showProfileScreen(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'View Profile',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Donor Action Button (dynamic based on verification status)
            Container(
              margin: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: _buildDrawerDonorButton(),
              ),
            ),
            
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildDrawerMenuItem(
                    icon: Icons.bloodtype,
                    title: 'Add Blood Need',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateBloodRequestScreen()),
                      );
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.list_alt,
                    title: 'Request Blood',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BloodRequestListScreen()),
                      );
                    },
                  ),
                  _buildDrawerMenuItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                  // Test notification button (for debugging)
                  _buildDrawerMenuItem(
                    icon: Icons.bug_report,
                    title: 'Test Notifications',
                    onTap: () {
                      Navigator.pop(context);
                      _testNotificationSystem();
                    },
                  ),
                ],
              ),
            ),
            
            // Logout Button
            Container(
              margin: const EdgeInsets.all(16),
              child: ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: const Text(
                  'LOGOUT',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutDialog();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildSearchBar(),
              const SizedBox(height: 24),
              _buildActivitySection(),
              const SizedBox(height: 24),
              _buildBloodGroupSection(),
              const SizedBox(height: 24),
              _buildRecentlyViewedSection(),
              const SizedBox(height: 24),
              _buildContributionSection(),
              const SizedBox(height: 24),
              _buildRecentPostsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final firstName = _userData?['firstName'] ?? 'User';
    final lastName = _userData?['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    
    // Get donor status for display
    String statusText = 'Welcome back!';
    Color statusColor = Colors.grey[600]!;
    
    if (_hasDonorProfile && _donorStatus != null) {
      final verificationStatus = _donorStatus!['verificationStatus'];
      final bloodType = _donorStatus!['bloodType'] ?? '';
      
      switch (verificationStatus) {
        case 'verified':
          statusText = 'Donor • $bloodType';
          statusColor = Colors.green;
          break;
        case 'pending':
          statusText = 'Verification Pending';
          statusColor = Colors.orange;
          break;
        case 'rejected':
          statusText = 'Verification Rejected';
          statusColor = Colors.red;
          break;
        default:
          statusText = 'Blood Donor';
          statusColor = Colors.grey[600]!;
      }
    }
    
    return Row(
      children: [
        // Hamburger Menu
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Profile Image
        GestureDetector(
          onTap: () => _showProfileScreen(),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.grey[300],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: _userData?['profileImage'] != null && !_userData!['profileImage'].toString().startsWith('placeholder_')
                  ? Image.network(
                      _userData!['profileImage'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 30,
                        );
                      },
                    )
                  : Icon(
                      Icons.person,
                      color: Colors.grey[600],
                      size: 30,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // User Info
        Expanded(
          child: GestureDetector(
            onTap: () => _showProfileScreen(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Notification Icons
        Row(
          children: [
            _buildNotificationIcon(
              icon: Icons.chat_bubble_outline,
              count: _unreadChatCount,
              onTap: () async {
                // Mark all chat notifications as read when opening inbox
                await _notificationService.markAllChatNotificationsAsRead();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InboxScreen()),
                );
              },
            ),
            const SizedBox(width: 8),
            _buildNotificationIcon(
              icon: Icons.notifications_outlined,
              count: _unreadNotificationCount,
              onTap: () async {
                // Mark all notifications as read when opening notifications screen
                await _notificationService.markAllAsRead();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationIcon({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.black,
              size: 20,
            ),
          ),
          if (count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search Blood Requests',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity As',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        
        // Donor Status Card (if user has donor profile)
        if (_donorStatus != null) ...[
          _buildDonorStatusCard(),
          const SizedBox(height: 16),
        ],
        
        /*// Debug button for testing (remove in production)
        ElevatedButton(
          onPressed: _createTestDonorApplication,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Test Donor Application (Debug)'),
        ),
        const SizedBox(height: 16),*/
        
        Row(
          children: [
            Expanded(
              child: _buildDonorActivityCard(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActivityCard(
                icon: Icons.local_hospital,
                title: 'Blood Recipient',
                subtitle: 'Find Donors',
                color: const Color(0xFF1976D2), // Professional blue
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DonorListScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActivityCard(
                icon: Icons.add,
                title: 'Create Post',
                subtitle: 'Request Blood',
                color: const Color(0xFF4CAF50), // Professional green
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateBloodRequestScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActivityCard(
                icon: Icons.bloodtype,
                title: 'Blood Given',
                subtitle: _donationStats != null 
                    ? '${_donationStats!['totalDonations'] ?? 0} donations'
                    : 'Track donations',
                color: const Color(0xFFFF9800), // Professional orange
                onTap: () {
                  // Navigate to donation history screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Donation history coming soon!')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDonorActivityCard() {
    // Determine the donor verification status
    String? verificationStatus = _donorStatus?['verificationStatus'];
    
    // Handle different verification states
    if (!_hasDonorProfile || verificationStatus == 'rejected') {
      // No donor profile or rejected - show "Become Blood Donor"
      return _buildActivityCard(
        icon: Icons.favorite,
        title: 'Become Blood Donor',
        subtitle: 'Become Donor',
        color: const Color(0xFFD32F2F), // Professional red
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BecomeDonorScreen(),
            ),
          );
        },
      );
    } else if (verificationStatus == 'pending') {
      // Pending verification - show disabled state
      return _buildActivityCard(
        icon: Icons.hourglass_empty,
        title: 'Application Pending',
        subtitle: 'Under Review',
        color: const Color(0xFFFF9800), // Professional orange
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your donor application is under review. Please wait for admin approval.'),
              backgroundColor: Color(0xFFFF9800),
            ),
          );
        },
      );
    } else if (verificationStatus == 'verified') {
      // Verified donor - show "Blood Donor" and allow viewing requests
      return _buildActivityCard(
        icon: Icons.verified_user,
        title: 'Blood Donor',
        subtitle: 'View Requests',
        color: const Color(0xFF4CAF50), // Professional green
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BloodRequestListScreen(),
            ),
          );
        },
      );
    } else {
      // Default fallback
      return _buildActivityCard(
        icon: Icons.favorite,
        title: 'Become Blood Donor',
        subtitle: 'Become Donor',
        color: const Color(0xFFD32F2F), // Professional red
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BecomeDonorScreen(),
            ),
          );
        },
      );
    }
  }

  Widget _buildActivityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorStatusCard() {
    if (_donorStatus == null) return const SizedBox.shrink();
    
    final status = _donorStatus!['verificationStatus'] as String;
    final bloodType = _donorStatus!['bloodType'] as String;
    final rejectionReason = _donorStatus!['rejectionReason'] as String?;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusSubtitle;
    
    switch (status) {
      case 'pending':
        statusColor = const Color(0xFFFF9800); // Professional orange
        statusIcon = Icons.hourglass_empty;
        statusText = 'Donor Application Pending';
        statusSubtitle = 'Your application is under review for security verification';
        break;
      case 'verified':
        statusColor = const Color(0xFF4CAF50); // Professional green
        statusIcon = Icons.verified_user;
        statusText = 'Verified Donor';
        statusSubtitle = 'You are now eligible to donate blood';
        break;
      case 'rejected':
        statusColor = const Color(0xFFF44336); // Professional red
        statusIcon = Icons.cancel;
        statusText = 'Application Rejected';
        statusSubtitle = rejectionReason ?? 'Please contact support for more information';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = 'Unknown Status';
        statusSubtitle = 'Please contact support';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (bloodType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD), // Light blue
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          bloodType,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2), // Professional blue
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                if (status == 'rejected') ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BecomeDonorScreen(),
                        ),
                      ).then((_) => _loadUserData()); // Refresh after returning
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Tap to Re-apply',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Blood Group',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _bloodTypes.length,
          itemBuilder: (context, index) {
            return _buildBloodTypeCard(_bloodTypes[index]);
          },
        ),
      ],
    );
  }

  Widget _buildBloodTypeCard(String bloodType) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BloodRequestListScreen(bloodType: bloodType),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.bloodtype,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bloodType,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyViewedSection() {
    if (_recentlyViewed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recently Viewed',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        ..._recentlyViewed.take(2).map((request) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRecentlyViewedCard(request),
        )),
      ],
    );
  }

  Widget _buildRecentlyViewedCard(BloodRequest request) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BloodRequestDetailScreen(request: request),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request.bloodType,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Blood needed for ${request.patientName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.local_hospital,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.hospitalName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(request.createdAt),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionSection() {
    // Calculate real statistics
    final totalDonors = 1000; // You can get this from a service
    final todayPosts = _recentRequests.where((r) => 
      DateTime.now().difference(r.createdAt).inDays == 0).length;
    final totalRequests = _recentRequests.length;
    final userDonations = _donationStats?['totalDonations'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Our Contribution',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10, // Reduced from 12 to 10
          mainAxisSpacing: 10, // Reduced from 12 to 10
          childAspectRatio: 1.3, // Increased from 1.2 to 1.3 to fix overflow
          children: [
            _buildContributionCard('${totalDonors}+', 'Blood Donors', Colors.blue),
            _buildContributionCard('$todayPosts', 'Today\'s Posts', Colors.green),
            _buildContributionCard('$totalRequests', 'Total Requests', Colors.purple),
            _buildContributionCard('$userDonations', 'Your Donations', Colors.pink),
            _buildContributionCard('24/7', 'Available', Colors.red),
            _buildContributionCard('100%', 'Free Service', Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildContributionCard(String number, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16 to 12
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 18, // Reduced from 20 to 18
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6), // Reduced from 8 to 6
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11, // Reduced from 12 to 11
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2, // Allow text to wrap to prevent overflow
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPostsSection() {
    if (_recentRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BloodRequestListScreen(),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140, // Increased from 120 to 140 to prevent overflow
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recentRequests.take(5).length,
            itemBuilder: (context, index) {
              final request = _recentRequests[index];
              return Padding(
                padding: EdgeInsets.only(right: index < _recentRequests.length - 1 ? 12 : 0),
                child: _buildRecentPostCard(request),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPostCard(BloodRequest request) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BloodRequestDetailScreen(request: request),
          ),
        );
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 70, // Reduced from 80 to 70 to give more space for text
              decoration: BoxDecoration(
                color: _getUrgencyColor(request.urgency).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      request.bloodType,
                      style: TextStyle(
                        fontSize: 18, // Reduced from 20 to 18
                        fontWeight: FontWeight.bold,
                        color: _getUrgencyColor(request.urgency),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.urgency.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9, // Reduced from 10 to 9
                        fontWeight: FontWeight.w600,
                        color: _getUrgencyColor(request.urgency),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded( // Use Expanded to take remaining space
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Blood needed for ${request.patientName}',
                  style: const TextStyle(
                    fontSize: 11, // Reduced from 12 to 11
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherScreens() {
    switch (_currentIndex) {
      case 1:
        return const BloodRequestListScreen(); // Requests tab
      case 2:
        return const DonorListScreen(); // Donors tab
      case 3:
        return const MoreScreen(); // Profile tab (using More screen as profile)
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bloodtype),
            label: 'Donors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'emergency':
        return Colors.red;
      case 'urgent':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inMinutes} minutes ago';
    }
  }

  Widget _buildDrawerDonorButton() {
    String? verificationStatus = _donorStatus?['verificationStatus'];
    
    if (!_hasDonorProfile || verificationStatus == 'rejected') {
      // No donor profile or rejected - show "Become a Donor"
      return ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BecomeDonorScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Become a Donor',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (verificationStatus == 'pending') {
      // Pending verification - show disabled state
      return ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your donor application is under review. Please wait for admin approval.'),
              backgroundColor: Color(0xFFFF9800),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF9800),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Application Pending',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (verificationStatus == 'verified') {
      // Verified donor - show "View Requests"
      return ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BloodRequestListScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'View Blood Requests',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      // Default fallback
      return ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BecomeDonorScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Become a Donor',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.grey[600],
        size: 22,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    );
  }

  void _showProfileScreen() async {
    Navigator.pop(context); // Close drawer
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userData: _userData),
      ),
    );
    
    // Refresh user data if profile was updated
    if (result == true) {
      _loadUserData();
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _authService.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Test method to create sample notifications for debugging
  Future<void> _testNotificationSystem() async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    try {
      print('🧪 Testing notification system...');
      
      // Test 1: Create a blood request notification
      await _notificationService.createNotification(
        userId: user.uid,
        title: '🩸 Test Blood Request',
        message: 'This is a test blood request notification to verify the badge system is working.',
        type: 'blood_request',
        relatedId: 'test_request_123',
        priority: 'urgent',
        data: {
          'bloodType': 'A+',
          'hospitalName': 'Test Hospital',
          'urgency': 'urgent',
        },
      );
      
      // Test 2: Create a chat notification
      await _notificationService.createChatNotification(
        userId: user.uid,
        senderName: 'Test User',
        message: 'This is a test chat message to verify the chat badge system is working.',
        chatId: 'test_chat_123',
        type: 'chat_message',
        additionalData: {
          'senderId': 'test_sender_123',
          'messageType': 'text',
        },
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Test notifications created! Check the badges in the header.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      print('✅ Test notifications created successfully');
    } catch (e) {
      print('❌ Error creating test notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error creating test notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createTestDonorApplication() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      print('=== CREATING TEST DONOR APPLICATION ===');
      print('User ID: ${user.uid}');
      print('User Email: ${user.email}');

      // Get user data
      final userData = await _authService.getCurrentUserData();
      final name = userData != null 
          ? '${userData['firstName'] ?? 'Test'} ${userData['lastName'] ?? 'User'}'.trim()
          : 'Test User';

      // Create test donor application directly in Firestore
      await FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .set({
        'name': name,
        'email': user.email ?? 'test@example.com',
        'phone': userData?['phone'] ?? '+1234567890',
        'bloodType': 'A+',
        'lastDonationDate': null,
        'totalDonations': 0,
        'isAvailable': false,
        'latitude': 0.0,
        'longitude': 0.0,
        'address': 'Test Address',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'verificationStatus': 'pending',
        'verifiedAt': null,
        'verifiedBy': null,
        'rejectedAt': null,
        'rejectedBy': null,
        'rejectionReason': null,
        'adminNotes': null,
      });

      print('Test donor application created successfully');

      // Verify it was created
      final doc = await FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        print('Verification successful:');
        print('  - Document ID: ${doc.id}');
        print('  - verificationStatus: ${data['verificationStatus']}');
        print('  - bloodType: ${data['bloodType']}');
        print('  - name: ${data['name']}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test donor application created! Check admin dashboard.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Reload user data to show the donor status card
        _loadUserData();
      } else {
        print('ERROR: Document was not created');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to create test application'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error creating test donor application: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}