import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/donor.dart';
import '../services/donor_service.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'donor_profile_screen.dart';

class DonorListScreen extends StatefulWidget {
  final String? bloodType;
  
  const DonorListScreen({
    super.key,
    this.bloodType,
  });

  @override
  State<DonorListScreen> createState() => _DonorListScreenState();
}

class _DonorListScreenState extends State<DonorListScreen> {
  final _donorService = DonorService();
  final _chatService = ChatService();
  final _authService = AuthService();
  
  List<Donor> _donors = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadDonors();
  }

  Future<void> _loadDonors() async {
    setState(() => _isLoading = true);
    
    try {
      List<Donor> donors;
      
      // Load donors based on blood type filter
      if (widget.bloodType != null) {
        // If a specific blood type is requested, get only those donors
        donors = await _donorService.getDonorsByBloodType(widget.bloodType!);
      } else {
        // Otherwise get all available donors
        donors = await _donorService.getAvailableDonors();
      }
      
      // Apply additional filters based on selected filter
      List<Donor> filteredDonors = donors;
      
      switch (_selectedFilter) {
        case 'available':
          filteredDonors = donors.where((d) => d.isAvailable).toList();
          break;
        case 'eligible':
          filteredDonors = donors.where((d) => d.isEligible).toList();
          break;
        case 'nearby':
          // For now, show all donors. In future, implement actual location filtering
          filteredDonors = donors;
          break;
        default:
          filteredDonors = donors;
      }
      
      setState(() {
        _donors = filteredDonors;
        _isLoading = false;
      });
      
      print('=== DONOR LOADING DEBUG ===');
      print('Requested blood type: ${widget.bloodType}');
      print('Total donors loaded: ${donors.length}');
      print('Filtered donors: ${filteredDonors.length}');
      for (var donor in filteredDonors.take(3)) {
        print('Donor: ${donor.name}, Blood Type: ${donor.bloodType}, Phone: ${donor.phone.isNotEmpty ? "Available" : "Not Available"}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading donors: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading donors: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.bloodType != null 
              ? '${widget.bloodType} Donors'
              : 'Available Donors',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _donors.isEmpty
                    ? _buildEmptyState()
                    : _buildDonorsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Available', 'available'),
            const SizedBox(width: 8),
            _buildFilterChip('Eligible', 'eligible'),
            const SizedBox(width: 8),
            _buildFilterChip('Nearby', 'nearby'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
        _loadDonors();
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.red.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.red : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No donors found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search criteria',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _donors.length,
      itemBuilder: (context, index) {
        return _buildDonorCard(_donors[index]);
      },
    );
  }

  Widget _buildDonorCard(Donor donor) {
    return GestureDetector(
      onTap: () => _viewDonorProfile(donor),
      child: Container(
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
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.red.withOpacity(0.1),
                  child: Text(
                    donor.name.isNotEmpty ? donor.name[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 20,
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
                        donor.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              donor.bloodType,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: donor.isAvailable 
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              donor.isAvailable ? 'Available' : 'Not Available',
                              style: TextStyle(
                                color: donor.isAvailable ? Colors.green : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: donor.isEligible 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    donor.isEligible ? 'Eligible' : '${donor.daysUntilEligible} days',
                    style: TextStyle(
                      color: donor.isEligible ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    donor.address.isNotEmpty ? donor.address : 'Address not provided',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: donor.address.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.bloodtype, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Total donations: ${donor.totalDonations}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (donor.phone.isNotEmpty) ...[
                  Icon(Icons.phone, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Available',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  Icon(Icons.phone_disabled, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'No contact',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: donor.phone.isNotEmpty ? () => _callDonor(donor) : null,
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: donor.phone.isNotEmpty ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: donor.phone.isNotEmpty ? () => _messageDonor(donor) : null,
                    icon: const Icon(Icons.message, size: 16),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: donor.phone.isNotEmpty ? Colors.blue : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _callDonor(Donor donor) async {
    try {
      if (donor.phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number not available for this donor'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await _chatService.callDonor(donor.phone);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not make call: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _messageDonor(Donor donor) async {
    try {
      if (donor.phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number not available for this donor'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to send messages'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userData = await _authService.getCurrentUserData();
      if (userData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load user data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      final userBloodType = widget.bloodType ?? 'blood';
      
      final message = '''Hi ${donor.name},

I hope you're doing well. I'm ${userName.isNotEmpty ? userName : 'someone'} and I urgently need $userBloodType blood donation.

Could you please help me? I would be very grateful for your assistance.

Thank you for your time and consideration.

Best regards,
${userName.isNotEmpty ? userName : 'Blood Donation App User'}''';

      // Show options dialog
      _showMessageOptions(donor, message);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMessageOptions(Donor donor, String message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Contact ${donor.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.message, color: Colors.green),
              ),
              title: const Text('Send WhatsApp Message'),
              subtitle: const Text('Send via WhatsApp with pre-written message'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _chatService.openWhatsApp(donor.phone, message);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not open WhatsApp: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sms, color: Colors.blue),
              ),
              title: const Text('Send SMS'),
              subtitle: const Text('Send via SMS with pre-written message'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _chatService.sendSMS(donor.phone, message);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not send SMS: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _viewDonorProfile(Donor donor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DonorProfileScreen(donor: donor),
      ),
    );
  }
}