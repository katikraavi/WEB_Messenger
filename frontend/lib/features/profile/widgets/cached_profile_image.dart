import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../../core/constants/asset_constants.dart';

/// Profile image display with caching and efficient loading
/// 
/// Phase 11 Task T143: CachedNetworkImage integration
/// 
/// Provides:
/// - Automatic image caching on device
/// - Smooth loading transitions
/// - Error handling with fallback
/// - Placeholder while loading
/// - Memory and disk cache management

class CachedProfileImage extends StatelessWidget {
  /// The URL of the image to display
  final String imageUrl;

  /// Optional image file path for displaying local/pending images
  final String? localImagePath;

  /// Width of the image
  final double width;

  /// Height of the image
  final double height;

  /// Border decoration
  final Border? border;

  /// Whether to display as circular (profile picture)
  final bool isCircular;

  /// On error callback for debugging
  final void Function()? onError;

  const CachedProfileImage({
    required this.imageUrl,
    this.localImagePath,
    this.width = 100,
    this.height = 100,
    this.border,
    this.isCircular = false,
    this.onError,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        border: border ?? Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: _buildImage(context),
    );
  }

  /// Build the appropriate image widget
  /// 
  /// Prioritizes: local image > network cached image > placeholder
  Widget _buildImage(BuildContext context) {
    // Local image takes priority (user is editing)
    if (localImagePath != null && localImagePath!.isNotEmpty) {
      return _buildLocalImage();
    }

    // Network image with caching
    if (imageUrl.isNotEmpty) {
      return _buildCachedNetworkImage(context);
    }

    // Fallback to default placeholder
    return _buildPlaceholder();
  }

  /// Build local image from file
  Widget _buildLocalImage() {
    return ClipOval(
      child: Image.file(
        File(localImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          onError?.call();
          return _buildPlaceholder();
        },
      ),
    );
  }

  /// Build cached network image with fade-in animation
  Widget _buildCachedNetworkImage(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      
      // T143: Placeholder while loading
      placeholder: (context, url) => Container(
        color: Colors.grey[300],
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
              strokeWidth: 2,
            ),
          ),
        ),
      ),
      
      // T143: Error fallback
      errorWidget: (context, url, error) {
        onError?.call();
        return _buildPlaceholder();
      },
      
      // T143: Memory cache settings
      memCacheWidth: (width * MediaQuery.of(context).devicePixelRatio).toInt(),
      memCacheHeight: (height * MediaQuery.of(context).devicePixelRatio).toInt(),
      
      // T143: Fade-in animation for smooth appearance
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      
      // Important: Use ClipOval for circular images
      imageBuilder: (context, imageProvider) {
        if (isCircular) {
          return ClipOval(
            child: Image(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          );
        }
        return Image(
          image: imageProvider,
          fit: BoxFit.cover,
        );
      },
    );
  }

  /// Build default placeholder with default profile picture asset
  Widget _buildPlaceholder() {
    if (isCircular) {
      return ClipOval(
        child: Image.asset(
          AssetConstants.defaultProfilePicture,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to icon if asset not found
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
              ),
              child: Center(
                child: Icon(
                  Icons.person,
                  size: width * 0.5,
                  color: Colors.grey[600],
                ),
              ),
            );
          },
        ),
      );
    }

    return Image.asset(
      AssetConstants.defaultProfilePicture,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to icon if asset not found
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: Icon(
              Icons.image,
              size: width * 0.4,
              color: Colors.grey[600],
            ),
          ),
        );
      },
    );
  }
}

/// Cache management utility for profile images
/// 
/// Provides methods to manage the image cache
class ProfileImageCacheManager {
  /// Clear all cached profile images
  /// 
  /// Call this when user logs out or switches accounts
  static Future<void> clearAllCache() async {
    try {
      // Clear through cached_network_image package
      await CachedNetworkImage(imageUrl: '').cacheManager?.emptyCache();
    } catch (e) {
      // Silently fail - cache clearing is not critical
    }
  }

  /// Clear cache for specific image URL
  static Future<void> clearImageCache(String imageUrl) async {
    try {
      // Clear specific URL through cached_network_image
      await CachedNetworkImage(imageUrl: imageUrl).cacheManager?.removeFile(imageUrl);
    } catch (e) {
      // Silently fail
    }
  }

  /// Get cache size statistics
  /// 
  /// Useful for debugging or showing cache stats to users
  static Future<int> getCacheSizeBytes() async {
    try {
      // For now, return a placeholder since getting cache info is complex
      // In a real app, you'd implement actual cache size monitoring
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Format cache size for display
  /// 
  /// Returns string like "2.5 MB"
  static Future<String> getCacheSizeDisplay() async {
    final bytes = await getCacheSizeBytes();
    return _formatBytes(bytes);
  }

  /// Helper to format bytes
  static String _formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    if (i == 0) return '${size.toInt()} ${suffixes[i]}';
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
