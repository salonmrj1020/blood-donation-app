import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart';
import '../config/cloudinary_config.dart';

class ImageUploadService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick and upload profile image
  static Future<String?> pickAndUploadProfileImage({
    required BuildContext context,
    required String userId,
    ImageSource? source,
  }) async {
    try {
      // Show source selection if not specified
      source ??= await _showImageSourceDialog(context);
      if (source == null) return null;

      // Pick image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      // Validate file size
      final file = File(pickedFile.path);
      final fileSize = await file.length();
      
      if (fileSize > CloudinaryConfig.maxProfileImageSize) {
        _showErrorDialog(context, 'Image too large', 
            'Please select an image smaller than ${CloudinaryConfig.maxProfileImageSize ~/ (1024 * 1024)}MB');
        return null;
      }

      // Show loading dialog
      _showLoadingDialog(context, 'Uploading image...');

      // Upload to Cloudinary (use signed upload for better reliability)
      final imageUrl = await CloudinaryService.uploadImageFromXFile(
        xFile: pickedFile,
        folder: CloudinaryEnvironment.getFolder(CloudinaryConfig.profileImagesFolder),
        // Don't specify publicId - let Cloudinary auto-generate it
        useSignedUpload: true, // Use signed upload
      );

      // Hide loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (imageUrl != null) {
        _showSuccessDialog(context, 'Success', 'Profile image updated successfully!');
        return imageUrl;
      } else {
        _showErrorDialog(context, 'Upload Failed', 'Failed to upload image. Please try again.');
        return null;
      }
    } catch (e) {
      // Hide loading dialog if showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      _showErrorDialog(context, 'Error', 'An error occurred: ${e.toString()}');
      return null;
    }
  }

  /// Pick and upload document for verification
  static Future<String?> pickAndUploadDocument({
    required BuildContext context,
    required String userId,
    required String documentType,
    ImageSource? source,
  }) async {
    try {
      // Show source selection if not specified
      source ??= await _showImageSourceDialog(context);
      if (source == null) return null;

      // Pick image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );

      if (pickedFile == null) return null;

      // Validate file size
      final file = File(pickedFile.path);
      final fileSize = await file.length();
      
      if (fileSize > CloudinaryConfig.maxDocumentSize) {
        _showErrorDialog(context, 'File too large', 
            'Please select a file smaller than ${CloudinaryConfig.maxDocumentSize ~/ (1024 * 1024)}MB');
        return null;
      }

      // Show loading dialog
      _showLoadingDialog(context, 'Uploading document...');

      // Upload to Cloudinary (use signed upload for better reliability)
      final documentUrl = await CloudinaryService.uploadImageFromXFile(
        xFile: pickedFile,
        folder: CloudinaryEnvironment.getFolder(CloudinaryConfig.documentsFolder),
        // Don't specify publicId - let Cloudinary auto-generate it
        // Don't pass transformation parameters for signed uploads
        useSignedUpload: true, // Use signed upload
      );

      // Hide loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (documentUrl != null) {
        _showSuccessDialog(context, 'Success', 'Document uploaded successfully!');
        return documentUrl;
      } else {
        _showErrorDialog(context, 'Upload Failed', 'Failed to upload document. Please try again.');
        return null;
      }
    } catch (e) {
      // Hide loading dialog if showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      _showErrorDialog(context, 'Error', 'An error occurred: ${e.toString()}');
      return null;
    }
  }

  /// Pick and upload multiple images
  static Future<List<String>> pickAndUploadMultipleImages({
    required BuildContext context,
    required String folder,
    required String publicIdPrefix,
    int maxImages = 5,
  }) async {
    try {
      // Pick multiple images
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return [];

      // Limit number of images
      final filesToUpload = pickedFiles.take(maxImages).toList();

      // Show loading dialog
      _showLoadingDialog(context, 'Uploading ${filesToUpload.length} images...');

      final uploadedUrls = <String>[];

      for (int i = 0; i < filesToUpload.length; i++) {
        final file = File(filesToUpload[i].path);
        final fileSize = await file.length();
        
        if (fileSize <= CloudinaryConfig.maxProfileImageSize) {
          final url = await CloudinaryService.uploadImageFromXFile(
            xFile: filesToUpload[i],
            folder: CloudinaryEnvironment.getFolder(folder),
            // Don't specify publicId - let Cloudinary use filename + unique suffix
            useSignedUpload: true, // Use signed upload
          );
          
          if (url != null) {
            uploadedUrls.add(url);
          }
        }
      }

      // Hide loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (uploadedUrls.isNotEmpty) {
        _showSuccessDialog(context, 'Success', 
            'Uploaded ${uploadedUrls.length}/${filesToUpload.length} images successfully!');
      } else {
        _showErrorDialog(context, 'Upload Failed', 'Failed to upload images. Please try again.');
      }

      return uploadedUrls;
    } catch (e) {
      // Hide loading dialog if showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      _showErrorDialog(context, 'Error', 'An error occurred: ${e.toString()}');
      return [];
    }
  }

  /// Show image source selection dialog
  static Future<ImageSource?> _showImageSourceDialog(BuildContext context) async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Show loading dialog
  static void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  /// Show success dialog
  static void _showSuccessDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  static void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Delete image from Cloudinary
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      final publicId = CloudinaryService.extractPublicId(imageUrl);
      if (publicId == null) return false;
      
      return await CloudinaryService.deleteImage(publicId);
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Get optimized image URL for display
  static String getOptimizedImageUrl(
    String originalUrl, {
    int? width,
    int? height,
    int quality = 80,
    String format = 'webp',
  }) {
    if (!CloudinaryService.isCloudinaryUrl(originalUrl)) {
      return originalUrl;
    }

    return CloudinaryService.getTransformedUrl(
      originalUrl,
      width: width,
      height: height,
      crop: 'fill',
      quality: quality,
      format: format,
    );
  }

  /// Get profile image URL with standard transformations
  static String getProfileImageUrl(String originalUrl, {int size = 200}) {
    return CloudinaryService.getProfileImageUrl(originalUrl, size: size);
  }

  /// Get thumbnail URL
  static String getThumbnailUrl(String originalUrl, {int size = 150}) {
    return CloudinaryService.getThumbnailUrl(originalUrl, width: size, height: size);
  }

  /// Validate image file
  static bool isValidImageFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return CloudinaryConfig.allowedImageTypes.contains(extension);
  }

  /// Get file size in MB
  static Future<double> getFileSizeInMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }
}