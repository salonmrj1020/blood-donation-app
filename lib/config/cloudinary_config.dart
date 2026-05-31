/// Cloudinary Configuration
/// 
/// Replace these values with your actual Cloudinary credentials
/// You can find these in your Cloudinary Dashboard
class CloudinaryConfig {
  // IMPORTANT: Replace these with your actual Cloudinary credentials
  static const String cloudName = 'deb7ojqbl';
  static const String apiKey = '738851155628629';
  static const String apiSecret = 'O4o_IAzS7-rW7G3rGVr10wor7Yw';
  
  // Upload presets (configure all as signed with filename + unique suffix)
  static const String profileImagePreset = 'profile_images'; // Use your existing preset
  static const String documentPreset = 'documents'; // Use your existing preset  
  static const String bloodRequestPreset = 'blood_requests'; // Use your existing preset
  
  // Folder structure
  static const String profileImagesFolder = 'blood_donation_app/profiles';
  static const String documentsFolder = 'blood_donation_app/documents';
  static const String bloodRequestsFolder = 'blood_donation_app/blood_requests';
  
  // Image transformation presets
  static const Map<String, String> profileImageTransformation = {
    'width': '400',
    'height': '400',
    'crop': 'fill',
    'quality': '80',
    'format': 'webp',
  };
  
  static const Map<String, String> thumbnailTransformation = {
    'width': '150',
    'height': '150',
    'crop': 'fill',
    'quality': '70',
    'format': 'webp',
  };
  
  static const Map<String, String> documentTransformation = {
    'width': '800',
    'quality': '85',
    'format': 'jpg',
  };
  
  // Maximum file sizes (in bytes)
  static const int maxProfileImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxDocumentSize = 10 * 1024 * 1024; // 10MB
  
  // Allowed file types
  static const List<String> allowedImageTypes = [
    'jpg', 'jpeg', 'png', 'webp', 'gif'
  ];
  
  static const List<String> allowedDocumentTypes = [
    'jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'
  ];
}

/// Environment-specific configurations
class CloudinaryEnvironment {
  static bool get isDevelopment => const bool.fromEnvironment('dart.vm.product') == false;
  
  // Remove environment prefix - use same folders for dev and prod
  static String get environmentPrefix => '';
  
  static String getFolder(String baseFolder) {
    return baseFolder; // No prefix added
  }
  
  static String getPublicId(String baseId) {
    return baseId; // No prefix added
  }
}