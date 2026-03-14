import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/profile_logger.dart';

/// Handles image picker permission requests with user-friendly error displays
/// 
/// Phase 11 Task T133: Permission error handling UI
/// 
/// Provides methods to:
/// - Request gallery and camera permissions
/// - Handle permission denials elegantly
/// - Display actionable error messages to users
/// - Guide users to app settings for permission changes

class ImagePickerPermissionsHandler {
  /// Request camera permission for taking photos
  /// 
  /// Returns true if permission granted, false otherwise
  /// Handles denied/permanently denied cases with appropriate messaging
  static Future<bool> requestCameraPermission(BuildContext context) async {
    try {
      ProfileLogger.logStateChange('permissions', 'Requesting camera permission');

      final status = await Permission.camera.request();

      if (status.isGranted) {
        ProfileLogger.logStateChange('permissions', 'Camera permission granted');
        return true;
      }

      if (status.isDenied) {
        // Permission was denied (can ask again later)
        _showPermissionDeniedDialog(
          context,
          'Camera Permission Required',
          'The app needs access to your camera to take photos. Grant permission to continue.',
          Permission.camera,
        );
        ProfileLogger.logError('permissions', 'Camera permission denied');
        return false;
      }

      if (status.isPermanentlyDenied) {
        // Permission was permanently denied (need to open settings)
        _showPermissionPermanentlyDeniedDialog(
          context,
          'Camera Permission',
          'Camera permission has been permanently denied. Please enable it in app settings to take photos.',
        );
        ProfileLogger.logError('permissions', 'Camera permission permanently denied');
        return false;
      }

      return false;
    } catch (e) {
      ProfileLogger.logError('permissions', 'Camera permission request failed: $e');
      _showErrorDialog(
        context,
        'Permission Error',
        'Unable to request camera permission. Please try again.',
      );
      return false;
    }
  }

  /// Request gallery permission for selecting images
  /// 
  /// Returns true if permission granted, false otherwise
  /// Handles denied/permanently denied cases with appropriate messaging
  static Future<bool> requestGalleryPermission(BuildContext context) async {
    try {
      ProfileLogger.logStateChange('permissions', 'Requesting photo library permission');

      final status = await Permission.photos.request();

      if (status.isGranted) {
        ProfileLogger.logStateChange('permissions', 'Photo library permission granted');
        return true;
      }

      if (status.isDenied) {
        // Permission was denied (can ask again later)
        _showPermissionDeniedDialog(
          context,
          'Photo Library Permission Required',
          'The app needs access to your photos. Grant permission to continue.',
          Permission.photos,
        );
        ProfileLogger.logError('permissions', 'Photo library permission denied');
        return false;
      }

      if (status.isPermanentlyDenied) {
        // Permission was permanently denied (need to open settings)
        _showPermissionPermanentlyDeniedDialog(
          context,
          'Photo Library Permission',
          'Photo library permission has been permanently denied. Please enable it in app settings to access your photos.',
        );
        ProfileLogger.logError('permissions', 'Photo library permission permanently denied');
        return false;
      }

      return false;
    } catch (e) {
      ProfileLogger.logError('permissions', 'Photo library permission request failed: $e');
      _showErrorDialog(
        context,
        'Permission Error',
        'Unable to request photo library permission. Please try again.',
      );
      return false;
    }
  }

  /// Display dialog for denied (but not permanent) permission
  /// 
  /// Shows explanation and retry option
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String title,
    String message,
    Permission permission,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Retry permission request
                if (permission == Permission.camera) {
                  requestCameraPermission(context);
                } else {
                  requestGalleryPermission(context);
                }
              },
              child: const Text('Grant Permission'),
            ),
          ],
        );
      },
    );
  }

  /// Display dialog for permanently denied permission
  /// 
  /// Shows explanation and directs user to app settings
  static void _showPermissionPermanentlyDeniedDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Open app settings
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Display generic error dialog
  /// 
  /// Used for unexpected permission errors
  static void _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
