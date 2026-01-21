import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/blood_request_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'blood_request_list_screen.dart';
import 'map_location_picker_screen.dart';

class CreateBloodRequestScreen extends StatefulWidget {
  const CreateBloodRequestScreen({super.key});

  @override
  State<CreateBloodRequestScreen> createState() => _CreateBloodRequestScreenState();
}

class _CreateBloodRequestScreenState extends State<CreateBloodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bloodRequestService = BloodRequestService();
  final _authService = AuthService();
  final _notificationService = NotificationService();

  // Form controllers
  final _patientNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationController = TextEditingController();
  final _bloodUnitsController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Form values
  String _requestFor = 'Other Person'; // 'Other Person' or 'Myself'
  String? _selectedGender;
  String? _selectedBloodGroup;
  String? _selectedBloodType;
  String? _selectedUrgency;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedLocation;
  Position? _currentPosition;
  List<File> _attachments = [];
  bool _isLoading = false;
  Map<String, dynamic>? _userData; // Store user data for auto-fill

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _bloodTypes = ['Whole Blood', 'Plasma', 'Platelets', 'Red Blood Cells'];
  final List<String> _urgencyLevels = ['Normal', 'Urgent', 'Emergency'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getCurrentUserData();
      if (userData != null && mounted) {
        setState(() {
          // Store user data for auto-fill when "Myself" is selected
          _userData = userData;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    _bloodUnitsController.dispose();
    _hospitalController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled. Please enable them in settings.', isSuccess: false);
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions are denied. Please grant location access.', isSuccess: false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions are permanently denied. Please enable them in app settings.', isSuccess: false);
        return;
      }

      // Show loading indicator
      if (mounted) {
        _showSnackBar('Getting your location...', isSuccess: true);
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
        _showSnackBar('Location obtained successfully!', isSuccess: true);
        print('Location obtained: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        _showSnackBar('Failed to get location. Please try again or enter location manually.', isSuccess: false);
      }
    }
  }

  Future<void> _createBloodRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validation
    if (_selectedBloodGroup == null) {
      _showSnackBar('Please select a blood group');
      return;
    }
    if (_selectedBloodType == null) {
      _showSnackBar('Please select a blood type');
      return;
    }
    if (_selectedUrgency == null) {
      _showSnackBar('Please select urgency level');
      return;
    }
    if (_selectedDate == null) {
      _showSnackBar('Please select a date');
      return;
    }

    // Location validation
    if (_currentPosition == null) {
      _showSnackBar('Location not available. Trying to get location again...');
      await _getCurrentLocation();
      if (_currentPosition == null) {
        _showSnackBar('Unable to get location. Please enable location services and try again.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get user data
      final userData = await _authService.getCurrentUserData();
      if (userData == null) {
        throw Exception('User data not found');
      }

      final requesterName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      final requesterPhone = userData['phone'] ?? _phoneController.text.trim();

      print('Creating blood request with location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

      // Create blood request
      final requestId = await _bloodRequestService.createBloodRequest(
        requesterId: user.uid,
        requesterName: requesterName,
        requesterPhone: requesterPhone,
        bloodType: _selectedBloodGroup!,
        quantity: int.tryParse(_bloodUnitsController.text) ?? 1,
        urgency: _selectedUrgency!.toLowerCase(),
        hospitalName: _hospitalController.text.trim(),
        hospitalAddress: _selectedLocation ?? 'Location not specified',
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        patientName: _patientNameController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (requestId != null) {
        if (mounted) {
          _showSnackBar('Blood request created successfully! Matching donors will be notified.', isSuccess: true);
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to create blood request');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickAttachment() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _attachments.add(File(image.path));
      });
    }
  }

  void _chooseLocation() async {
    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => MapLocationPickerScreen(
            initialLatitude: _currentPosition?.latitude,
            initialLongitude: _currentPosition?.longitude,
            initialAddress: _selectedLocation,
          ),
        ),
      );

      if (result != null) {
        setState(() {
          _selectedLocation = result['address'];
          // Update the position with the selected location
          _currentPosition = Position(
            latitude: result['latitude'],
            longitude: result['longitude'],
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );
        });
        _showSnackBar('Location selected successfully!', isSuccess: true);
      }
    } catch (e) {
      print('Error opening location picker: $e');
      _showSnackBar('Error opening location picker. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Professional background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post Blood Need',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Request For Section
                    const Text(
                      'I am requesting blood for',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRequestForOption('Other Person'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildRequestForOption('Myself'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Patient's Information
                    const Text(
                      'Patient\'s Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Full Name
                    const Text('Full Name', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _patientNameController,
                      hintText: 'Patient\'s Full Name',
                      prefixIcon: Icons.person,
                      validator: (value) => value?.isEmpty == true ? 'Please enter patient name' : null,
                      isAutoFilled: _requestFor == 'Myself',
                    ),
                    const SizedBox(height: 16),

                    // Age and Gender
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Age', style: TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _ageController,
                                hintText: 'Enter Age',
                                prefixIcon: Icons.calendar_today,
                                keyboardType: TextInputType.number,
                                validator: (value) => value?.isEmpty == true ? 'Enter age' : null,
                                isAutoFilled: _requestFor == 'Myself',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Gender', style: TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 8),
                              _buildDropdown(
                                value: _selectedGender,
                                items: _genders,
                                hint: 'Gender',
                                onChanged: (value) => setState(() => _selectedGender = value),
                                isAutoFilled: _requestFor == 'Myself',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    const Text('Phone Number', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _phoneController,
                      hintText: 'Phone Number',
                      prefixIcon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) => value?.isEmpty == true ? 'Please enter phone number' : null,
                      isAutoFilled: _requestFor == 'Myself',
                    ),
                    const SizedBox(height: 16),

                    // Relation to Patient
                    const Text('Relation to Patient', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _relationController,
                      hintText: 'Relation to patient',
                      prefixIcon: Icons.people,
                      isAutoFilled: _requestFor == 'Myself',
                    ),
                    const SizedBox(height: 24),

                    // Choose Map Location
                    const Text(
                      'Choose Map Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _chooseLocation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.grey[600]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedLocation ?? 'Choose location',
                                style: TextStyle(
                                  color: _selectedLocation != null ? Colors.black : Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Requirements
                    const Text(
                      'Requirements',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Blood Group and Blood Type
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Blood Group', style: TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 8),
                              _buildDropdown(
                                value: _selectedBloodGroup,
                                items: _bloodGroups,
                                hint: 'Blood Group',
                                onChanged: (value) => setState(() => _selectedBloodGroup = value),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Blood Type', style: TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 8),
                              _buildDropdown(
                                value: _selectedBloodType,
                                items: _bloodTypes,
                                hint: 'Blood Type',
                                onChanged: (value) => setState(() => _selectedBloodType = value),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Blood Units and Urgency
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Blood Units', style: TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _bloodUnitsController,
                                hintText: 'Enter Unit',
                                keyboardType: TextInputType.number,
                                validator: (value) => value?.isEmpty == true ? 'Enter units' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Urgency', style: TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 8),
                              _buildDropdown(
                                value: _selectedUrgency,
                                items: _urgencyLevels,
                                hint: 'Urgency Level',
                                onChanged: (value) => setState(() => _selectedUrgency = value),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Hospital
                    const Text('Hospital', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _hospitalController,
                      hintText: 'Hospital Name',
                      prefixIcon: Icons.local_hospital,
                      validator: (value) => value?.isEmpty == true ? 'Please enter hospital name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Need Before Date and Time
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Need Before Date', style: TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _selectDate,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today, color: Colors.grey[600]),
                                      const SizedBox(width: 12),
                                      Text(
                                        _selectedDate != null
                                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                            : 'Need Before',
                                        style: TextStyle(
                                          color: _selectedDate != null ? Colors.black : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Need Before Time', style: TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _selectTime,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time, color: Colors.grey[600]),
                                      const SizedBox(width: 12),
                                      Text(
                                        _selectedTime != null
                                            ? _selectedTime!.format(context)
                                            : 'Need Before',
                                        style: TextStyle(
                                          color: _selectedTime != null ? Colors.black : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Attachments
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickAttachment,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Attachments',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'If you have blood request form/document provided by hospital, please add here. Only in jpg and png format.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          if (_attachments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: _attachments.map((file) => Chip(
                                label: Text('Image ${_attachments.indexOf(file) + 1}'),
                                onDeleted: () {
                                  setState(() {
                                    _attachments.remove(file);
                                  });
                                },
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Case Description
                    const Text('Case Description', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _descriptionController,
                      hintText: 'Describe your case...',
                      prefixIcon: Icons.message,
                      maxLines: 4,
                      maxLength: 300,
                    ),
                    const SizedBox(height: 24),

                    // Location Status
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _currentPosition != null ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentPosition != null ? Colors.green : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _currentPosition != null ? Icons.location_on : Icons.location_off,
                            color: _currentPosition != null ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentPosition != null ? 'Location Obtained' : 'Location Not Available',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _currentPosition != null ? Colors.green : Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentPosition != null 
                                      ? 'Donors within 50km will be notified'
                                      : 'Enable location for better donor matching',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_currentPosition == null)
                            TextButton(
                              onPressed: _getCurrentLocation,
                              child: const Text('Retry'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Terms and Conditions
                    const Text(
                      'By posting a blood request, you\'ve confirmed that all the information are correct and you\'ve agreed to our Terms & Conditions and Privacy Policy.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createBloodRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRequestForOption(String option) {
    final isSelected = _requestFor == option;
    return GestureDetector(
      onTap: () {
        setState(() {
          _requestFor = option;
          
          // Auto-fill user data when "Myself" is selected
          if (option == 'Myself' && _userData != null) {
            _patientNameController.text = '${_userData!['firstName'] ?? ''} ${_userData!['lastName'] ?? ''}'.trim();
            _phoneController.text = _userData!['phone'] ?? '';
            _selectedGender = _userData!['gender'];
            
            // Calculate age from date of birth if available
            if (_userData!['dateOfBirth'] != null) {
              try {
                final dob = (_userData!['dateOfBirth'] as dynamic).toDate();
                final age = DateTime.now().difference(dob).inDays ~/ 365;
                _ageController.text = age.toString();
              } catch (e) {
                print('Error calculating age: $e');
              }
            }
            
            // Set relation to "Self"
            _relationController.text = 'Self';
          } else if (option == 'Other Person') {
            // Clear fields when switching to "Other Person"
            _patientNameController.clear();
            _ageController.clear();
            _phoneController.clear();
            _relationController.clear();
            _selectedGender = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.red : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.red : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              option,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.red : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
    bool isAutoFilled = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey[600]) : null,
        suffixIcon: isAutoFilled && controller.text.isNotEmpty
            ? Icon(Icons.auto_awesome, color: Colors.green[600], size: 20)
            : null,
        filled: true,
        fillColor: isAutoFilled && controller.text.isNotEmpty 
            ? Colors.green.withOpacity(0.05) 
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isAutoFilled && controller.text.isNotEmpty 
                ? Colors.green.withOpacity(0.5) 
                : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required void Function(String?) onChanged,
    bool isAutoFilled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isAutoFilled && value != null 
            ? Colors.green.withOpacity(0.05) 
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAutoFilled && value != null 
              ? Colors.green.withOpacity(0.5) 
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(hint, style: TextStyle(color: Colors.grey[600])),
                isExpanded: true,
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
          if (isAutoFilled && value != null)
            Icon(Icons.auto_awesome, color: Colors.green[600], size: 20),
        ],
      ),
    );
  }
}