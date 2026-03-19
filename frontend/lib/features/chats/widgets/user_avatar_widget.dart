import 'package:flutter/material.dart';
import '../../../core/constants/asset_constants.dart';

/// Reusable user avatar widget with intelligent fallback handling
///
/// Handles three cases in order:
/// 1. Network image (from server)
/// 2. Default asset image (if no network image)
/// 3. Icon (if asset fails to load)
class UserAvatarWidget extends StatefulWidget {
  /// URL to the network image
  final String? imageUrl;

  /// Avatar size/radius
  final double radius;

  /// Background color when no image
  final Color? backgroundColor;

  /// Username for generating initials (future enhancement)
  final String? username;

  const UserAvatarWidget({
    this.imageUrl,
    this.radius = 24,
    this.backgroundColor,
    this.username,
    Key? key,
  }) : super(key: key);

  @override
  State<UserAvatarWidget> createState() => _UserAvatarWidgetState();
}

class _UserAvatarWidgetState extends State<UserAvatarWidget> {
  late bool _useNetworkImage;
  late bool _useAssetImage;

  @override
  void initState() {
    super.initState();
    _useNetworkImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
    _useAssetImage = true;
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? Colors.grey[300],
      child: ClipOval(
        child: SizedBox(
          width: widget.radius * 2,
          height: widget.radius * 2,
          child: _buildAvatar(),
        ),
      ),
    );
  }

  /// Build avatar with fallback chain
  Widget _buildAvatar() {
    // Try network image first
    if (_useNetworkImage) {
      return _buildNetworkAvatar();
    }

    // Try asset image
    if (_useAssetImage) {
      return _buildAssetAvatar();
    }

    // Fallback to icon
    return _buildIconAvatar();
  }

  /// Build network image with error handling
  Widget _buildNetworkAvatar() {
    return Image.network(
      widget.imageUrl!,
      fit: BoxFit.cover,
      width: widget.radius * 2,
      height: widget.radius * 2,
      errorBuilder: (context, error, stackTrace) {
        print('[UserAvatarWidget] ❌ Network image failed to load: $error');
        // Don't call setState, just return fallback immediately
        return _buildAssetFallback();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: widget.radius * 0.6,
            height: widget.radius * 0.6,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
            ),
          ),
        );
      },
    );
  }

  /// Fallback from network to asset
  Widget _buildAssetFallback() {
    if (_useAssetImage) {
      return _buildAssetAvatar();
    }
    return _buildIconAvatar();
  }

  /// Build asset image with error handling
  Widget _buildAssetAvatar() {
    return Image.asset(
      AssetConstants.defaultProfilePicture,
      fit: BoxFit.cover,
      width: widget.radius * 2,
      height: widget.radius * 2,
      errorBuilder: (context, error, stackTrace) {
        print('[UserAvatarWidget] ❌ Asset image failed to load: $error');
        // Asset failed, return icon directly
        return _buildIconAvatar();
      },
    );
  }

  /// Build icon as ultimate fallback
  Widget _buildIconAvatar() {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.person,
          size: widget.radius * 1.2,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
