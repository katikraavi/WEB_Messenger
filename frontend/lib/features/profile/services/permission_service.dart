/// Service for managing camera and gallery permissions
/// 
/// Handles requesting and checking permissions for:
/// - Camera access (for capturing photos)
/// - Photo library access (for selecting existing images)
/// - Graceful handling of permission denials
/// 
/// Integrates with permission_handler package with graceful fallback:
/// - If permission_handler is not available, allows image_picker to handle it
/// - Android: Requires READ_EXTERNAL_STORAGE or READ_MEDIA_IMAGES permission
/// - iOS: Requires NSPhotoLibraryUsageDescription and NSCameraUsageDescription in Info.plist
/// - image_picker package handles permission requests on most platforms

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request camera permission
  /// 
  /// Returns: true if permission granted or available, false if denied
  /// Gracefully handles MissingPluginException by returning true (let image_picker handle it)
  /// 
  /// Platform-specific handling:
  /// - iOS: Shows system permission dialog on first request
  /// - Android: Shows system permission dialog on first request
  /// - Web: No permissions needed
  static Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } on MissingPluginException catch (e) {
      // Permission handler plugin not available, let image_picker handle it
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Request photo library permission
  /// 
  /// Returns: true if permission request attempted, false on error
  /// Gracefully handles MissingPluginException by returning true (let image_picker handle it)
  /// 
  /// Platform-specific handling:
  /// - iOS: Shows system permission dialog on first request
  /// - Android (API 33+): Requests READ_MEDIA_IMAGES permission
  /// - Android (API < 33): Requests READ_EXTERNAL_STORAGE permission
  static Future<bool> requestPhotoLibraryPermission() async {
    try {
      final status = await Permission.photos.request();
      return status.isGranted;
    } on MissingPluginException catch (e) {
      // Permission handler plugin not available, let image_picker handle it
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if camera permission is already granted (without requesting)
  /// 
  /// Returns: true if permission already granted, false otherwise
  /// Gracefully handles MissingPluginException by returning true
  static Future<bool> hasCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } on MissingPluginException {
      // Permission handler plugin not available, assume permission exists
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if photo library permission is already granted (without requesting)
  /// 
  /// Returns: true if permission already granted, false otherwise
  /// Gracefully handles MissingPluginException by returning true
  static Future<bool> hasPhotoLibraryPermission() async {
    try {
      final status = await Permission.photos.status;
      return status.isGranted;
    } on MissingPluginException {
      // Permission handler plugin not available, assume permission exists
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Show user-friendly message about permission denial
  /// 
  /// Used when image_picker returns null (user denied permission)
  /// Logs the denial; UI layer responsibility to show snackbar/dialog to user
  static void showPermissionDeniedMessage(String what) {
    // UI layer should display appropriate message when image_picker returns null
  }
}
