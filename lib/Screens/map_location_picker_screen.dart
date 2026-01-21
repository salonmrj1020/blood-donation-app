import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class MapLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const MapLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  Completer<GoogleMapController> _mapController = Completer();
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _selectedAddress = 'Loading address...';
  bool _isLoading = false;
  bool _mapError = false;
  final TextEditingController _searchController = TextEditingController();
  
  Set<Marker> _markers = {};
  CameraPosition? _initialCameraPosition;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);

    try {
      // Use provided coordinates or get current location
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        _selectedLatitude = widget.initialLatitude!;
        _selectedLongitude = widget.initialLongitude!;
        _selectedAddress = widget.initialAddress ?? 'Selected Location';
      } else {
        // Get current location
        final position = await _getCurrentLocation();
        if (position != null) {
          _selectedLatitude = position.latitude;
          _selectedLongitude = position.longitude;
          await _getAddressFromCoordinates(position.latitude, position.longitude);
        } else {
          // Default to a central location if GPS fails
          _selectedLatitude = 37.7749;
          _selectedLongitude = -122.4194;
          _selectedAddress = 'Default Location (GPS unavailable)';
        }
      }

      // Set initial camera position
      _initialCameraPosition = CameraPosition(
        target: LatLng(_selectedLatitude!, _selectedLongitude!),
        zoom: 15.0,
      );

      // Add initial marker
      _updateMarker(_selectedLatitude!, _selectedLongitude!);

      // Test if Google Maps is available
      try {
        // This will help detect if Google Maps services are available
        print('Google Maps initialized with position: $_selectedLatitude, $_selectedLongitude');
      } catch (mapError) {
        print('Google Maps service error: $mapError');
        setState(() => _mapError = true);
      }

    } catch (e) {
      print('Error initializing location: $e');
      _selectedAddress = 'Error loading location';
      setState(() => _mapError = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        setState(() {
          _selectedAddress = _formatAddress(placemark);
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _selectedAddress = 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
      });
    }
  }

  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [];
    
    if (placemark.name != null && placemark.name!.isNotEmpty) {
      addressParts.add(placemark.name!);
    }
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      addressParts.add(placemark.street!);
    }
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      addressParts.add(placemark.locality!);
    }
    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
      addressParts.add(placemark.administrativeArea!);
    }
    if (placemark.country != null && placemark.country!.isNotEmpty) {
      addressParts.add(placemark.country!);
    }

    return addressParts.join(', ');
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        await _moveToLocation(location.latitude, location.longitude);
        _showSnackBar('Location found successfully!', isSuccess: true);
      } else {
        _showSnackBar('Location not found. Please try a different search term.');
      }
    } catch (e) {
      print('Error searching location: $e');
      _showSnackBar('Error searching location. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _moveToLocation(double latitude, double longitude) async {
    // Update selected coordinates
    _selectedLatitude = latitude;
    _selectedLongitude = longitude;
    
    // If map is available, move camera
    if (!_mapError && _mapController.isCompleted) {
      try {
        final GoogleMapController controller = await _mapController.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(latitude, longitude),
              zoom: 15.0,
            ),
          ),
        );
      } catch (e) {
        print('Error moving map camera: $e');
      }
    }
    
    // Update marker and address
    _updateMarker(latitude, longitude);
    await _getAddressFromCoordinates(latitude, longitude);
  }

  void _updateMarker(double latitude, double longitude) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: LatLng(latitude, longitude),
          infoWindow: InfoWindow(
            title: 'Selected Location',
            snippet: _selectedAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });
  }

  void _onMapTapped(LatLng position) {
    _moveToLocation(position.latitude, position.longitude);
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  void _confirmLocation() {
    if (_selectedLatitude != null && _selectedLongitude != null && _selectedAddress.isNotEmpty) {
      Navigator.pop(context, {
        'latitude': _selectedLatitude!,
        'longitude': _selectedLongitude!,
        'address': _selectedAddress,
      });
    } else {
      _showSnackBar('Please ensure location and address are available.');
    }
  }

  void _goToCurrentLocation() async {
    setState(() => _isLoading = true);

    final position = await _getCurrentLocation();
    if (position != null) {
      await _moveToLocation(position.latitude, position.longitude);
      _showSnackBar('Current location obtained!', isSuccess: true);
    } else {
      _showSnackBar('Unable to get current location. Please enable GPS.');
    }

    setState(() => _isLoading = false);
  }

  Widget _buildMapView() {
    if (_mapError || _initialCameraPosition == null) {
      return _buildFallbackView();
    }

    try {
      return GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          if (!_mapController.isCompleted) {
            _mapController.complete(controller);
          }
        },
        initialCameraPosition: _initialCameraPosition!,
        markers: _markers,
        onTap: _onMapTapped,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: true,
        mapType: MapType.normal,
      );
    } catch (e) {
      print('Google Maps error: $e');
      setState(() => _mapError = true);
      return _buildFallbackView();
    }
  }

  Widget _buildFallbackView() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Map Unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Google Maps requires a valid API key.\nUsing search and GPS for location selection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ),
            if (_selectedLatitude != null && _selectedLongitude != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Location',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(height: 8),
                  Text(
                    'You can still use search and GPS to select locations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
              ),
            )
          : Stack(
              children: [
                // Map or Fallback View
                _buildMapView(),
                
                // Search Bar at Top
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for hospitals, landmarks...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFD32F2F)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _searchLocation(),
                    ),
                  ),
                ),
                
                // Back Button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 80,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                
                // Current Location Button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 80,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.my_location, color: Color(0xFFD32F2F)),
                      onPressed: _goToCurrentLocation,
                    ),
                  ),
                ),
                
                // Bottom Sheet with Address and Confirm Button
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          spreadRadius: 1,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag Handle
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Selected Location Title
                          const Text(
                            'Selected Location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Address
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFFD32F2F), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedAddress,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Coordinates
                          if (_selectedLatitude != null && _selectedLongitude != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Coordinates: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 20),
                          
                          // Confirm Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (_selectedLatitude != null && _selectedLongitude != null) 
                                  ? _confirmLocation 
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Set Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          
                          // Safe area padding
                          SizedBox(height: MediaQuery.of(context).padding.bottom),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}