import 'package:flutter/material.dart';
import '../services/image_upload_service.dart';

/// A widget that displays Cloudinary images with automatic optimization
class CloudinaryImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int quality;
  final String format;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CloudinaryImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.quality = 80,
    this.format = 'webp',
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Safely convert width and height to int, handling infinity and NaN
    int? safeWidth;
    int? safeHeight;
    
    if (width != null && width!.isFinite && !width!.isNaN) {
      safeWidth = width!.toInt();
    }
    
    if (height != null && height!.isFinite && !height!.isNaN) {
      safeHeight = height!.toInt();
    }
    
    // Get optimized URL if it's a Cloudinary image
    final optimizedUrl = ImageUploadService.getOptimizedImageUrl(
      imageUrl,
      width: safeWidth,
      height: safeHeight,
      quality: quality,
      format: format,
    );

    return Image.network(
      optimizedUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        
        return placeholder ??
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.broken_image,
                color: Colors.grey[600],
                size: (width != null && height != null) 
                    ? (width! < height! ? width! : height!) * 0.3
                    : 40,
              ),
            );
      },
    );
  }
}

/// Profile image widget with Cloudinary optimization
class CloudinaryProfileImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;
  final bool showEditIcon;

  const CloudinaryProfileImage({
    super.key,
    this.imageUrl,
    this.size = 100,
    this.onTap,
    this.showEditIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? CloudinaryImageWidget(
                      imageUrl: imageUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        width: size,
                        height: size,
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.person,
                          size: size * 0.5,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                  : Container(
                      width: size,
                      height: size,
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.person,
                        size: size * 0.5,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
          ),
          if (showEditIcon)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: size * 0.15,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Thumbnail image widget
class CloudinaryThumbnail extends StatelessWidget {
  final String imageUrl;
  final double size;
  final VoidCallback? onTap;

  const CloudinaryThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 60,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: CloudinaryImageWidget(
            imageUrl: ImageUploadService.getThumbnailUrl(imageUrl, size: size.toInt()),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}