import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import 'admin_login_screen.dart';
import 'admin_blood_requests_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  
  late TabController _tabController;
  Map<String, dynamic> _dashboardStats = {};
  List<Map<String, dynamic>> _pendingApplications = [];
  List<Map<String, dynamic>> _verifiedDonors = [];
  List<Map<String, dynamic>> _rejectedApplications = [];
  List<Map<String, dynamic>> _verificationLogs = [];
  
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminAndLoadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAndLoadData() async {
    final isAdmin = await _adminService.isCurrentUserAdmin();
    
    if (!isAdmin) {
      // If not admin, show error and go back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access denied: Admin privileges required'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isAdmin = true;
    });

    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await _adminService.getAdminDashboardStats();
      final pending = await _adminService.getPendingDonorApplications();
      final verified = await _adminService.getVerifiedDonors();
      final rejected = await _adminService.getRejectedDonorApplications();
      final logs = await _adminService.getVerificationLogs();

      setState(() {
        _dashboardStats = stats;
        _pendingApplications = pending;
        _verifiedDonors = verified;
        _rejectedApplications = rejected;
        _verificationLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading dashboard data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: _buildAdminDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Pending'),
            Tab(text: 'Verified'),
            Tab(text: 'Logs'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildPendingTab(),
                _buildVerifiedTab(),
                _buildLogsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3, // Increased from 1.2 to 1.3 to fix overflow
            children: [
              _buildStatCard(
                'Pending Applications',
                _dashboardStats['pendingApplications']?.toString() ?? '0',
                Icons.pending_actions,
                Colors.orange,
                onTap: () => _tabController.animateTo(1), // Navigate to pending tab
              ),
              _buildStatCard(
                'Verified Donors',
                _dashboardStats['verifiedDonors']?.toString() ?? '0',
                Icons.verified_user,
                Colors.green,
                onTap: () => _tabController.animateTo(2), // Navigate to verified tab
              ),
              _buildStatCard(
                'Total Donors',
                _dashboardStats['totalDonors']?.toString() ?? '0',
                Icons.people,
                Colors.blue,
                onTap: () => _tabController.animateTo(2), // Navigate to verified tab
              ),
              _buildStatCard(
                'Blood Requests',
                _dashboardStats['totalBloodRequests']?.toString() ?? '0',
                Icons.bloodtype,
                Colors.red,
                onTap: () => _showBloodRequests(), // Navigate to blood requests
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14), // Reduced from 16 to 14
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10), // Reduced from 12 to 10
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22, // Reduced from 24 to 22
              ),
            ),
            const SizedBox(height: 10), // Reduced from 12 to 10
            Text(
              value,
              style: TextStyle(
                fontSize: 22, // Reduced from 24 to 22
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2), // Reduced from 4 to 2
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11, // Reduced from 12 to 11
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2, // Allow text to wrap to prevent overflow
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
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
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _tabController.animateTo(1); // Go to pending tab
                  },
                  icon: const Icon(Icons.pending_actions),
                  label: const Text('Review Pending'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _tabController.animateTo(2); // Go to verified tab
                  },
                  icon: const Icon(Icons.verified_user),
                  label: const Text('View Verified'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Manual refresh button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                print('Manual refresh triggered');
                await _loadDashboardData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dashboard data refreshed'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_pendingApplications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No pending applications',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingApplications.length,
      itemBuilder: (context, index) {
        final application = _pendingApplications[index];
        return _buildApplicationCard(application, 'pending');
      },
    );
  }

  Widget _buildVerifiedTab() {
    if (_verifiedDonors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No verified donors yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _verifiedDonors.length,
      itemBuilder: (context, index) {
        final donor = _verifiedDonors[index];
        return _buildApplicationCard(donor, 'verified');
      },
    );
  }

  Widget _buildLogsTab() {
    if (_verificationLogs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No verification logs',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _verificationLogs.length,
      itemBuilder: (context, index) {
        final log = _verificationLogs[index];
        return _buildLogCard(log);
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application, String status) {
    final donorData = application['donorData'] as Map<String, dynamic>;
    final userData = application['userData'] as Map<String, dynamic>;
    
    final name = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    final email = userData['email'] ?? '';
    final phone = userData['phone'] ?? '';
    final bloodType = donorData['bloodType'] ?? '';
    final address = donorData['address'] ?? '';
    final weight = donorData['weight']?.toString() ?? 'N/A';
    final gender = donorData['gender'] ?? 'N/A';
    final occupation = donorData['occupation'] ?? 'N/A';
    final attachmentUrl = donorData['attachmentUrl'];
    
    // Format date of birth
    String dateOfBirth = 'N/A';
    if (donorData['dateOfBirth'] != null) {
      final dob = (donorData['dateOfBirth'] as Timestamp).toDate();
      dateOfBirth = '${dob.day}/${dob.month}/${dob.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Header with blood type and status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bloodType,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'pending')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (status == 'verified')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'VERIFIED',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Detailed Information
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personal Details Section
                const Text(
                  'Personal Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Contact Information
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(Icons.phone, 'Phone', phone),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailItem(Icons.cake, 'DOB', dateOfBirth),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(Icons.person, 'Gender', gender),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailItem(Icons.monitor_weight, 'Weight', '${weight} kg'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                _buildDetailItem(Icons.work, 'Occupation', occupation),
                const SizedBox(height: 8),
                _buildDetailItem(Icons.location_on, 'Address', address),
                
                // Attachment Photo Section
                if (attachmentUrl != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Verification Document',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showAttachmentDialog(attachmentUrl),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          attachmentUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error, color: Colors.grey),
                                    SizedBox(height: 4),
                                    Text('Failed to load image', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to view full size',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Action Buttons for Pending Applications
          if (status == 'pending') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showVerificationDialog(application['donorId'], true),
                      icon: const Icon(Icons.check),
                      label: const Text('Verify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showVerificationDialog(application['donorId'], false),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showAttachmentDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 200,
                          height: 200,
                          color: Colors.white,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 200,
                          color: Colors.white,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Failed to load image'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 40,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final action = log['action'] as String;
    final donorName = log['donorName'] as String;
    final adminName = log['adminName'] as String;
    final timestamp = (log['timestamp'] as Timestamp).toDate();
    
    final isVerified = action == 'verified';
    final color = isVerified ? Colors.green : Colors.red;
    final icon = isVerified ? Icons.check_circle : Icons.cancel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$adminName ${isVerified ? 'verified' : 'rejected'} $donorName',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVerificationDialog(String donorId, bool isVerifying) {
    final TextEditingController notesController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isVerifying ? 'Verify Donor' : 'Reject Application'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isVerifying) ...[
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Admin Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                String? error;
                if (isVerifying) {
                  error = await _adminService.verifyDonorApplication(
                    donorId,
                    notesController.text.trim(),
                  );
                } else {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a rejection reason'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  error = await _adminService.rejectDonorApplication(
                    donorId,
                    reasonController.text.trim(),
                    notesController.text.trim(),
                  );
                }

                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isVerifying 
                          ? 'Donor verified successfully!' 
                          : 'Application rejected successfully!'),
                      backgroundColor: isVerifying ? Colors.green : Colors.orange,
                    ),
                  );
                  _loadDashboardData(); // Refresh data
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isVerifying ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(isVerifying ? 'Verify' : 'Reject'),
            ),
          ],
        );
      },
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
            'Are you sure you want to logout from admin panel?',
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
                  MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
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

  Widget _buildAdminDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Admin Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF5252)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Blood Donation Management',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildAdminDrawerMenuItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard Overview',
                    onTap: () {
                      Navigator.pop(context);
                      _tabController.animateTo(0);
                    },
                  ),
                  _buildAdminDrawerMenuItem(
                    icon: Icons.pending_actions,
                    title: 'Pending Applications',
                    subtitle: '${_dashboardStats['pendingApplications'] ?? 0} pending',
                    onTap: () {
                      Navigator.pop(context);
                      _tabController.animateTo(1);
                    },
                  ),
                  _buildAdminDrawerMenuItem(
                    icon: Icons.verified_user,
                    title: 'Verified Donors',
                    subtitle: '${_dashboardStats['verifiedDonors'] ?? 0} verified',
                    onTap: () {
                      Navigator.pop(context);
                      _tabController.animateTo(2);
                    },
                  ),
                  _buildAdminDrawerMenuItem(
                    icon: Icons.bloodtype,
                    title: 'Blood Requests',
                    subtitle: '${_dashboardStats['totalBloodRequests'] ?? 0} requests',
                    onTap: () {
                      Navigator.pop(context);
                      _showBloodRequests();
                    },
                  ),
                  _buildAdminDrawerMenuItem(
                    icon: Icons.history,
                    title: 'Verification Logs',
                    onTap: () {
                      Navigator.pop(context);
                      _tabController.animateTo(3);
                    },
                  ),
                  const Divider(height: 32),
                  _buildAdminDrawerMenuItem(
                    icon: Icons.analytics,
                    title: 'Analytics',
                    onTap: () {
                      Navigator.pop(context);
                      _showComingSoon('Analytics');
                    },
                  ),
                  _buildAdminDrawerMenuItem(
                    icon: Icons.settings,
                    title: 'Admin Settings',
                    onTap: () {
                      Navigator.pop(context);
                      _showComingSoon('Admin Settings');
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

  Widget _buildAdminDrawerMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
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
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            )
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    );
  }

  void _showBloodRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminBloodRequestsScreen(),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}