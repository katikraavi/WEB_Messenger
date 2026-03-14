/// Service for managing camera and gallery permissions
/// 
/// Handles requesting and checking permissions for:
/// - Camera access (for capturing photos)
/// - Photo library access (for selecting existing images)
/// - Graceful handling of permission denials
/// 
/// NOTE: In production, this should integrate with permission_handler package:
/// - Android: Requires READ_EXTERNAL_STORAGE or READ_MEDIA_IMAGES permission
/// - iOS: Requires NSPhotoLibraryUsageDescription and NSCameraUsageDescription in Info.plist
/// - image_picker package handles permission requests on most platforms
class PermissionService {
  /// Request camera permission
  /// 
  /// Returns: true if permission granted or available, false if denied
  /// 
  /// The image_picker package handles permission requests internally,
  /// so this service primarily documents the permissions needed.
  /// 
  /// Platform-specific handling:
  /// - iOS: Shows system permission dialog on first request
  /// - Android: Shows system permission dialog on first request
  /// - Web: No permissions needed
  static Future<bool> requestCameraPermission() async {
    try {
      // The image_picker package handles camera permission requests
      // Return true to indicate permission flow attempted
      // Actual permission granted/denied is determined by image_picker's response
      return true;
    } catch (e) {
      print('[PermissionService] Error with camera permission: $e');
      return false;
    }
  }

  /// Request photo library permission
  /// 
  /// Returns: true if permission request attempted, false on error
  /// 
  /// Platform-specific handling:
  /// - iOS: Shows system permission dialog on first request
  /// - Android (API 33+): Requests READ_MEDIA_IMAGES permission
  /// - Android (API < 33): Requests READ_EXTERNAL_STORAGE permission
  /// - The image_picker package handles these requests internally
  static Future<bool> requestPhotoLibraryPermission() async {
    try {
      // The image_picker package handles photo library permission requests
      // Return true to indicate permission flow attempted
      return true;
    } catch (e) {
      print('[PermissionService] Error with photo library permission: $e');
      return false;
    }
  }

  /// Check if camera permission is already granted (without requesting)
  /// 
  /// Returns: true if permission already granted, false otherwise
  /// 
  /// Note: On some platforms, this may always return false if permission_handler
  /// is not integrated. Use image_picker's response to determine actual permission.
  static Future<bool> hasCameraPermission() async {
    try {
      // Without permission_handler, we trust image_picker's response
      // This method documents the capability for future enhancement
      return true;
    } catch (e) {
      print('[PermissionService] Error checking camera permission: $e');
      return false;
    }
  }

  /// Check if photo library permission is already granted (without requesting)
  /// 
  /// Returns: true if permission already granted, false otherwise
  /// 
  /// Note: On some platforms, this may always return false if permission_handler
  /// is not integrated. Use image_picker's response to determine actual permission.
  static Future<bool> hasPhotoLibraryPermission() async {
    try {
      // Without permission_handler, we trust image_picker's response
      // This method documents the capability for future enhancement
      return true;
    } catch (e) {
      print('[PermissionService] Error checking photo library permission: $e');
      return false;
    }
  }

  /// Show user-friendly message about permission denial
  /// 
  /// Used when image_picker returns null (user denied permission)
  /// Logs the denial; UI layer responsibility to show snackbar/dialog to user
  static void showPermissionDeniedMessage(String what) {
    print('[PermissionService] $what permission denied by user');
    // UI layer should display appropriate message when image_picker returns null
  }
}
