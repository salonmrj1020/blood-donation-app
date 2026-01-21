import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'package:blood_donation_app/Screens/create_blood_request_screen.dart';
import 'package:blood_donation_app/Screens/become_donor_screen.dart';
import 'package:blood_donation_app/Screens/inbox_screen.dart';
import 'package:blood_donation_app/Screens/login_screen.dart';
import 'package:blood_donation_app/Screens/settings_screen.dart';
import 'package:blood_donation_app/Screens/profile_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _userData;
  String? _userBloodType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getCurrentUserData();
      
      // Try to get blood type from donor profile
      String? bloodType;
      final user = _authService.currentUser;
      if (user != null) {
        try {
          final donorDoc = await FirebaseFirestore.instance
              .collection('donors')
              .doc(user.uid)
              .get();
          
          if (donorDoc.exists) {
            bloodType = donorDoc.data()?['bloodType'];
          }
        } catch (e) {
          print('Error getting donor blood type: $e');
        }
      }
      
      setState(() {
        _userData = userData;
        _userBloodType = bloodType;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'More',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 24),
                  _buildMenuItems(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard() {
    final firstName = _userData?['firstName'] ?? 'User';
    final lastName = _userData?['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    
    return GestureDetector(
      onTap: () => _navigateToProfile(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _userData?['profileImage'] != null
                    ? Image.network(
                        _userData!['profileImage'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          );
                        },
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userBloodType != null 
                        ? 'Blood Group: $_userBloodType'
                        : 'Tap to edit profile',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.8),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItems() {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.bloodtype,
          title: 'Create Request Blood',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateBloodRequestScreen()),
            );
          },
        ),
        _buildMenuItem(
          icon: Icons.favorite,
          title: 'Create Donor Blood',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BecomeDonorScreen()),
            );
          },
        ),
        _buildMenuItem(
          icon: Icons.inbox,
          title: 'Inbox',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InboxScreen()),
            );
          },
        ),
        _buildMenuItem(
          icon: Icons.help_outline,
          title: 'FAQ',
          onTap: () {
            _showFAQScreen();
          },
        ),
        _buildMenuItem(
          icon: Icons.settings,
          title: 'Settings',
          onTap: () {
            _showSettingsScreen();
          },
        ),
        _buildMenuItem(
          icon: Icons.people_outline,
          title: 'Compatibility',
          onTap: () {
            _showCompatibilityScreen();
          },
        ),
        const SizedBox(height: 20),
        _buildLogoutButton(),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _showLogoutDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFAQScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'FAQ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFAQItem(
                'Who can donate blood?',
                'Anyone between 18-65 years old, weighing at least 50kg, and in good health can donate blood.',
              ),
              _buildFAQItem(
                'How often can I donate blood?',
                'You can donate whole blood every 56 days (8 weeks). This allows your body to replenish the donated blood.',
              ),
              _buildFAQItem(
                'Is blood donation safe?',
                'Yes, blood donation is completely safe. All equipment is sterile and used only once.',
              ),
              _buildFAQItem(
                'How long does blood donation take?',
                'The entire process takes about 45 minutes to 1 hour, with the actual donation taking 8-10 minutes.',
              ),
              _buildFAQItem(
                'What should I do before donating?',
                'Eat a healthy meal, drink plenty of water, get adequate sleep, and avoid alcohol 24 hours before donation.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Text(
            question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  void _showCompatibilityScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Blood Compatibility',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompatibilityCard('O-', 'Universal Donor', 
                  'Can donate to: All blood types\nCan receive from: O- only', Colors.green),
                _buildCompatibilityCard('AB+', 'Universal Recipient', 
                  'Can donate to: AB+ only\nCan receive from: All blood types', Colors.blue),
                _buildCompatibilityCard('A+', 'Common Type', 
                  'Can donate to: A+, AB+\nCan receive from: A+, A-, O+, O-', Colors.orange),
                _buildCompatibilityCard('B+', 'Common Type', 
                  'Can donate to: B+, AB+\nCan receive from: B+, B-, O+, O-', Colors.purple),
                _buildCompatibilityCard('A-', 'Rare Type', 
                  'Can donate to: A+, A-, AB+, AB-\nCan receive from: A-, O-', Colors.red),
                _buildCompatibilityCard('B-', 'Rare Type', 
                  'Can donate to: B+, B-, AB+, AB-\nCan receive from: B-, O-', Colors.indigo),
                _buildCompatibilityCard('AB-', 'Rare Type', 
                  'Can donate to: AB+, AB-\nCan receive from: AB-, A-, B-, O-', Colors.teal),
                _buildCompatibilityCard('O+', 'Common Type', 
                  'Can donate to: O+, A+, B+, AB+\nCan receive from: O+, O-', Colors.brown),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompatibilityCard(String bloodType, String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                bloodType,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _navigateToProfile() async {
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
}