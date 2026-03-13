import 'package:flutter/material.dart';

/// Widget for displaying circular profile picture
/// 
/// Shows profile image in a circular format (120x120) with fallback to default avatar.
/// Handles network image loading, errors, and animations.
/// 
/// Usage:
/// ```dart
/// ProfilePictureWidget(
///   imageUrl: 'https://example.com/profile.jpg',
///   size: 120,
///   isLoading: false,
/// )
/// ```

class ProfilePictureWidget extends StatelessWidget {
  /// URL to the profile picture (HTTPS)
  /// If null or empty, displays default avatar
  final String? imageUrl;

  /// Diameter of the circular image (pixels)
  /// Default: 120
  final double size;

  /// Whether currently loading the image
  /// Instead of showing a network image, shows a loading skeleton
  final bool isLoading;

  /// Called when user taps the profile picture
  /// Can be used to open gallery/camera for image selection
  final VoidCallback? onTap;

  /// Creates a ProfilePictureWidget
  const ProfilePictureWidget({
    Key? key,
    this.imageUrl,
    this.size = 120,
    this.isLoading = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        // T037: Display loading skeleton while fetching
        child: isLoading
            ? _buildLoadingSkeleton()
            // Show network image if URL provided, otherwise default avatar
            : (imageUrl != null && imageUrl!.isNotEmpty)
                ? _buildNetworkImage()
                : _buildDefaultAvatar(),
      ),
    );
  }

  /// Builds loading skeleton (shimmer effect)
  Widget _buildLoadingSkeleton() {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
      ),
    );
  }

  /// Builds network image with error handling [T037]
  /// 
  /// Shows loading indicator while fetching, handles errors gracefully
  Widget _buildNetworkImage() {
    return ClipOval(
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          // Show loading skeleton while image loads
          if (loadingProgress == null) {
            return child;
          }
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Fallback to default avatar on error
          return _buildDefaultAvatar();
        },
      ),
    );
  }

  /// Builds default profile avatar [T037]
  /// 
  /// Shows generic placeholder avatar when no custom image
  Widget _buildDefaultAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Variant: Small profile picture for list items/chat messages
/// 
/// Usage: ProfilePictureWidget.small(imageUrl: url)
extension ProfilePictureWidgetSmall on ProfilePictureWidget {
  /// Creates a small profile picture (48x48)
  /// Suitable for list items and inline display
  static Widget small({
    required String? imageUrl,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return ProfilePictureWidget(
      imageUrl: imageUrl,
      size: 48,
      isLoading: isLoading,
      onTap: onTap,
    );
  }

  /// Creates a large profile picture (160x160)
  /// Suitable for full-page profile view with edit capability
  static Widget large({
    required String? imageUrl,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return ProfilePictureWidget(
      imageUrl: imageUrl,
      size: 160,
      isLoading: isLoading,
      onTap: onTap,
    );
  }
}
