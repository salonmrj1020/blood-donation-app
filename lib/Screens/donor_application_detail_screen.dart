import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import '../widgets/cloudinary_image_widget.dart';

class DonorApplicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> application;

  const DonorApplicationDetailScreen({
    super.key,
    required this.application,
  });

  @override
  State<DonorApplicationDetailScreen> createState() => _DonorApplicationDetailScreenState();
}

class _DonorApplicationDetailScreenState extends State<DonorApplicationDetailScreen> {
  final AdminService _adminService = AdminService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final donorData = widget.application['donorData'] as Map<String, dynamic>;
    final userData = widget.application['userData'] as Map<String, dynamic>;
    final donorId = widget.application['donorId'] as String;
    
    final name = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    final email = userData['email'] ?? '';
    final phone = userData['phone'] ?? '';
    final bloodType = donorData['bloodType'] ?? 'Unknown';
    final age = donorData['age'] ?? 0;
    final weight = donorData['weight'] ?? 0;
    final address = donorData['address'] ?? '';
    final occupation = donorData['occupation'] ?? '';
    
    final applicationDate = widget.application['applicationDate'] as Timestamp?;
    final documentUrls = donorData['documentUrls'] as List<dynamic>? ?? [];
    final profileImageUrl = userData['profileImageUrl'] as String?;
    
    // Check basic eligibility
    bool isEligible = true;
    List<String> eligibilityIssues = [];
    
    if (age < 18 || age > 65) {
      isEligible = false;
      eligibilityIssues.add('Age must be between 18-65 years');
    }
    if (weight < 45) {
      isEligible = false;
      eligibilityIssues.add('Weight must be at least 45kg');
    }
    if (donorData['hasChronicIllness'] == true) {
      isEligible = false;
      eligibilityIssues.add('Has chronic illness');
    }
    if (donorData['isPregnant'] == true) {
      isEligible = false;
      eligibilityIssues.add('Currently pregnant');
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        title: const Text('Donor Application Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            _buildProfileHeader(name, bloodType, profileImageUrl),
            const SizedBox(height: 24),
            
            // Personal Information
            _buildSection(
              'Personal Information',
              Icons.person,
              [
                _buildInfoRow('Full Name', name),
                _buildInfoRow('Email', email),
                _buildInfoRow('Phone', phone),
                _buildInfoRow('Blood Type', bloodType),
                _buildInfoRow('Age', '$age years'),
                _buildInfoRow('Weight', '$weight kg'),
                _buildInfoRow('Address', address),
                _buildInfoRow('Occupation', occupation),
                if (applicationDate != null)
                  _buildInfoRow('Applied On', _formatDate(applicationDate.toDate())),
              ],
            ),
            const SizedBox(height: 24),
            
            // Medical Information
            _buildSection(
              'Medical Information',
              Icons.medical_services,
              [
                _buildInfoRow('Chronic Illness', donorData['hasChronicIllness'] == true ? 'Yes' : 'No'),
                if (donorData['gender'] == 'Female')
                  _buildInfoRow('Currently Pregnant', donorData['isPregnant'] == true ? 'Yes' : 'No'),
                _buildInfoRow('Previous Donations', donorData['hasDonatedBefore'] == true ? 'Yes' : 'No'),
                if (donorData['lastDonationDate'] != null)
                  _buildInfoRow('Last Donation', _formatDate((donorData['lastDonationDate'] as Timestamp).toDate())),
              ],
            ),
            const SizedBox(height: 24),
            
            // Eligibility Status
            _buildEligibilitySection(isEligible, eligibilityIssues),
            const SizedBox(height: 24),
            
            // Uploaded Documents
            if (documentUrls.isNotEmpty) ...[
              _buildDocumentsSection(documentUrls),
              const SizedBox(height: 24),
            ],
            
            // Action Buttons
            _buildActionButtons(donorId, name),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String name, String bloodType, String? profileImageUrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: profileImageUrl != null && profileImageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(37),
                    child: CloudinaryImageWidget(
                      imageUrl: profileImageUrl,
                      width: 74,
                      height: 74,
                      fit: BoxFit.cover,
                    ),
                  )
                : CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 37,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
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
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Blood Type: $bloodType',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PENDING REVIEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(icon, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilitySection(bool isEligible, List<String> issues) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEligible ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEligible ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEligible ? Icons.check_circle : Icons.warning,
                color: isEligible ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isEligible ? 'Meets Basic Eligibility Criteria' : 'Eligibility Issues Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isEligible ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (!isEligible) ...[
            const SizedBox(height: 12),
            ...issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      issue,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(List<dynamic> documentUrls) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Row(
            children: [
              Icon(Icons.document_scanner, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                'Uploaded Documents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: documentUrls.length,
            itemBuilder: (context, index) {
              final documentUrl = documentUrls[index] as String;
              return _buildDocumentThumbnail(documentUrl, index + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentThumbnail(String documentUrl, int index) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(documentUrl, 'Document $index'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                child: CloudinaryImageWidget(
                  imageUrl: documentUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.document_scanner, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Document $index',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String donorId, String donorName) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _approveDonorApplication(donorId, donorName),
            icon: _isProcessing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _rejectDonorApplication(donorId, donorName),
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(String imageUrl, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title),
            centerTitle: true,
          ),
          body: Center(
            child: InteractiveViewer(
              child: CloudinaryImageWidget(
                imageUrl: imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approveDonorApplication(String donorId, String donorName) async {
    setState(() => _isProcessing = true);
    
    try {
      await _adminService.verifyDonorApplication(donorId, 'Approved by admin after document review');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$donorName has been approved as a verified donor'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate approval
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _rejectDonorApplication(String donorId, String donorName) async {
    final reason = await _showRejectionDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() => _isProcessing = true);
    
    try {
      await _adminService.rejectDonorApplication(donorId, reason, 'Rejected by admin after document review');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$donorName\'s application has been rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate rejection
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<String?> _showRejectionDialog() async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}