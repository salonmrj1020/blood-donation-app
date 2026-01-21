import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../services/donor_service.dart';
import '../services/auth_service.dart';

class BecomeDonorScreen extends StatefulWidget {
  const BecomeDonorScreen({super.key});

  @override
  State<BecomeDonorScreen> createState() => _BecomeDonorScreenState();
}

class _BecomeDonorScreenState extends State<BecomeDonorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _donorService = DonorService();
  final _authService = AuthService();
  final _imagePicker = ImagePicker();

  // Form controllers
  final _weightController = TextEditingController();
  final _occupationController = TextEditingController();

  // Form values
  String? _selectedBloodGroup;
  DateTime? _selectedDOB;
  String? _selectedGender;
  File? _attachmentImage;
  bool _isLoading = false;
  Position? _currentPosition;

  final List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadExistingUserData();
    _getCurrentLocation();
    _checkExistingDonorStatus();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingDonorStatus() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // Check if user has an existing donor profile
      final donorDoc = await FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .get();

      if (donorDoc.exists) {
        final data = donorDoc.data()!;
        final verificationStatus = data['verificationStatus'] as String?;
        
        if (verificationStatus == 'rejected') {
          // Show dialog explaining re-application
          if (mounted) {
            _showReapplicationDialog(data['rejectionReason'] as String?);
          }
        } else if (verificationStatus == 'pending') {
          // User already has a pending application, redirect them
          if (mounted) {
            _showExistingApplicationDialog();
          }
        } else if (verificationStatus == 'verified') {
          // User is already a verified donor, redirect them
          if (mounted) {
            _showAlreadyVerifiedDialog();
          }
        }
      }
    } catch (e) {
      print('Error checking existing donor status: $e');
    }
  }

  void _showReapplicationDialog(String? rejectionReason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info, color: Color(0xFFD32F2F)),
              SizedBox(width: 8),
              Text('Re-application'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your previous donor application was not approved.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              if (rejectionReason != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Reason:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  rejectionReason,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'You can submit a new application with updated information.',
                style: TextStyle(color: Colors.green),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to home
              },
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Continue with new application
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _showExistingApplicationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.hourglass_empty, color: Color(0xFFFF9800)),
              SizedBox(width: 8),
              Text('Application Pending'),
            ],
          ),
          content: const Text(
            'You already have a donor application under review. Please wait for admin approval before submitting a new application.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showAlreadyVerifiedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFF4CAF50)),
              SizedBox(width: 8),
              Text('Already a Donor'),
            ],
          ),
          content: const Text(
            'You are already a verified blood donor! You can view and respond to blood requests from the home screen.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadExistingUserData() async {
    // Pre-fill with existing user data if available
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final userData = await _authService.getCurrentUserData();
        if (userData != null) {
          setState(() {
            _selectedBloodGroup = userData['bloodGroup'];
            _selectedGender = userData['gender'];
            if (userData['dateOfBirth'] != null) {
              _selectedDOB = DateTime.parse(userData['dateOfBirth']);
            }
          });
        }
      } catch (e) {
        print('Error loading existing user data: $e');
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Location services are disabled. Please enable them for better donor matching.');
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permissions are denied. This may affect donor matching.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar('Location permissions are permanently denied. Please enable them in app settings.');
        return;
      }

      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        print('Donor location obtained: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      print('Error getting donor location: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to get location. You can still register, but location-based matching may be limited.');
      }
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Document Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _pickImageFromSource(ImageSource.camera),
                ),
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _pickImageFromSource(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFD32F2F).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFFD32F2F)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    Navigator.pop(context);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _attachmentImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBloodGroup == null) {
      _showErrorSnackBar('Please select your blood group');
      return;
    }

    if (_selectedDOB == null) {
      _showErrorSnackBar('Please select your date of birth');
      return;
    }

    if (_selectedGender == null) {
      _showErrorSnackBar('Please select your gender');
      return;
    }

    // Make attachment optional with a warning if not provided
    if (_attachmentImage == null) {
      final shouldContinue = await _showAttachmentWarningDialog();
      if (!shouldContinue) {
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Create donor profile using direct Firestore write (bypass model for testing)
      print('=== DONOR SUBMISSION DEBUG ===');
      print('Creating donor profile with:');
      print('  - bloodType: $_selectedBloodGroup');
      print('  - user: ${_authService.currentUser?.uid}');
      
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get user data
      final userData = await _authService.getCurrentUserData();
      if (userData == null) {
        throw Exception('User data not found');
      }

      final name = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();

      // Upload attachment image to Firebase Storage
      String? attachmentUrl;
      if (_attachmentImage != null) {
        try {
          print('Starting attachment upload...');
          
          // Create storage reference
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('donor_attachments')
              .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          
          print('Storage reference created: ${storageRef.fullPath}');
          
          // Upload file with metadata
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'uploadedBy': user.uid,
              'uploadedAt': DateTime.now().toIso8601String(),
              'purpose': 'donor_verification',
            },
          );
          
          final uploadTask = storageRef.putFile(_attachmentImage!, metadata);
          
          // Monitor upload progress
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
            print('Upload progress: ${progress.toStringAsFixed(2)}%');
          });
          
          // Wait for upload to complete
          final taskSnapshot = await uploadTask;
          attachmentUrl = await taskSnapshot.ref.getDownloadURL();
          
          print('✅ Attachment uploaded successfully!');
          print('   → URL: $attachmentUrl');
          print('   → Size: ${taskSnapshot.totalBytes} bytes');
          
        } catch (e) {
          print('❌ Error uploading attachment: $e');
          
          // Check if it's a storage setup issue
          if (e.toString().contains('object-not-found') || 
              e.toString().contains('storage') ||
              e.toString().contains('bucket')) {
            
            // Show user-friendly message about storage setup
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Document upload temporarily unavailable. Your application will be submitted without the attachment.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            
            // Continue without attachment - set a placeholder
            attachmentUrl = null;
            print('Continuing without attachment due to storage setup issue');
            
          } else {
            // For other errors, still try to continue but log the error
            print('Unexpected upload error: $e');
            attachmentUrl = null;
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Document upload failed. Your application will be submitted without the attachment.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        }
      }

      // Write directly to Firestore (this will overwrite existing document for re-applications)
      await FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .set({
        'name': name,
        'email': user.email ?? '',
        'phone': userData['phone'] ?? '',
        'bloodType': _selectedBloodGroup!,
        'weight': double.tryParse(_weightController.text) ?? 0.0,
        'dateOfBirth': _selectedDOB != null ? Timestamp.fromDate(_selectedDOB!) : null,
        'gender': _selectedGender ?? '',
        'occupation': _occupationController.text.trim(),
        'attachmentUrl': attachmentUrl, // Store the attachment URL
        'lastDonationDate': null,
        'totalDonations': 0,
        'isAvailable': false, // Set to false until verified
        'latitude': _currentPosition?.latitude ?? 0.0,
        'longitude': _currentPosition?.longitude ?? 0.0,
        'address': _currentPosition != null 
            ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}'
            : 'Location not available',
        'createdAt': Timestamp.now(),
        'updatedAt': null,
        'verificationStatus': 'pending', // This is the key field
        'verifiedAt': null,
        'verifiedBy': null,
        'rejectedAt': null,
        'rejectedBy': null,
        'rejectionReason': null,
        'adminNotes': null,
      });

      print('Donor profile written directly to Firestore');
      
      // Verify it was created
      final donorDoc = await FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .get();
      
      if (donorDoc.exists) {
        final data = donorDoc.data()!;
        print('Verification - Donor document exists:');
        print('  - verificationStatus: ${data['verificationStatus']}');
        print('  - bloodType: ${data['bloodType']}');
        print('  - createdAt: ${data['createdAt']}');
      } else {
        print('ERROR: Donor document was not created!');
        throw Exception('Failed to create donor document');
      }
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Donor application submitted successfully! Your application is now pending admin verification for security purposes.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<bool> _showAttachmentWarningDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('No Document Attached'),
            ],
          ),
          content: const Text(
            'You haven\'t uploaded a verification document. While not strictly required, uploading a document (like a blood donor ID or medical report) helps speed up the verification process.\n\nWould you like to continue without a document?',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Professional background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Become a Donor',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFD32F2F), const Color(0xFFB71C1C)], // Professional red gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Icon(
                        Icons.bloodtype,
                        size: 40,
                        color: Color(0xFFD32F2F), // Professional red
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Join Our Life-Saving Community',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Help save lives by becoming a blood donor',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Personal Information Section
              _buildSectionHeader('Personal Information', Icons.person),
              const SizedBox(height: 16),

              // Blood Group Card
              _buildBloodGroupCard(),
              const SizedBox(height: 16),

              // Weight and DOB Row
              Row(
                children: [
                  Expanded(child: _buildWeightCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDOBCard()),
                ],
              ),
              const SizedBox(height: 16),

              // Gender Card
              _buildGenderCard(),
              const SizedBox(height: 16),

              // Occupation Card
              _buildOccupationCard(),
              const SizedBox(height: 32),

              // Document Section
              _buildSectionHeader('Document Verification', Icons.verified_user),
              const SizedBox(height: 16),
              _buildDocumentUploadCard(),
              const SizedBox(height: 40),

              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFD32F2F), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBloodGroupCard() {
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
            'Blood Group *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedBloodGroup,
            decoration: InputDecoration(
              hintText: 'Select your blood group',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD32F2F)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _bloodGroups.map((bloodGroup) {
              return DropdownMenuItem(
                value: bloodGroup,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          bloodGroup,
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(bloodGroup),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBloodGroup = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeightCard() {
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
            'Weight (kg) *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _weightController,
            decoration: InputDecoration(
              hintText: 'Enter weight',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD32F2F)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixText: 'kg',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              final weight = double.tryParse(value);
              if (weight == null || weight <= 0) {
                return 'Invalid weight';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDOBCard() {
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
            'Date of Birth *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDOB ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
                lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
              );
              if (selectedDate != null) {
                setState(() {
                  _selectedDOB = selectedDate;
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDOB != null
                          ? '${_selectedDOB!.day}/${_selectedDOB!.month}/${_selectedDOB!.year}'
                          : 'Select date',
                      style: TextStyle(
                        color: _selectedDOB != null ? Colors.black : Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_today, color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard() {
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
            'Gender *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _genders.map((gender) {
              final isSelected = _selectedGender == gender;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGender = gender;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFD32F2F) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFD32F2F) : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      gender,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupationCard() {
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
            'Occupation *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _occupationController,
            decoration: InputDecoration(
              hintText: 'Enter your occupation',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD32F2F)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Occupation is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUploadCard() {
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
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _attachmentImage != null ? Colors.green.withOpacity(0.1) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _attachmentImage != null ? Colors.green : Colors.grey[300]!,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: _attachmentImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _attachmentImage!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Upload Document (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload any official document that shows your blood group\n(Blood donor ID, Driving License, etc.)\n\nThis helps speed up verification but is not required.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'JPG, PNG formats only',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD32F2F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Submit Application',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}