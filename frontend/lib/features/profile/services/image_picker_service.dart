import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/profile_form_state.dart';
import '../utils/image_validator.dart';
import 'permission_service.dart';

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery with permission handling
  ///
  /// Returns: XFile if user selects an image, null if cancelled or permission denied
  ///
  /// Handles:
  /// - Permission request via permission_handler (mobile only)
  /// - User cancellation (returns null)
  /// - Permission denial (returns null)
  /// - Web: Browser file picker dialog
  static Future<XFile?> pickImageFromGallery() async {
    try {
      // Request photo library permission (mobile only; web returns true)
      final permissionGranted =
          await PermissionService.requestPhotoLibraryPermission();

      if (!permissionGranted) {
        PermissionService.showPermissionDeniedMessage('photo library');
        return null;
      }

      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      // On web: null typically means user cancelled the file picker dialog
      // On mobile: null means permission denied or user cancelled
      if (pickedFile == null && !kIsWeb) {
        PermissionService.showPermissionDeniedMessage('photo library');
      }
      // On web, null is just user cancellation — don't show error message

      return pickedFile;
    } catch (e) {
      rethrow;
    }
  }

  /// Pick image from camera with permission handling
  ///
  /// Returns: XFile if user captures photo, null if cancelled or permission denied
  ///
  /// Handles:
  /// - Camera permission request via permission_handler (mobile only)
  /// - User cancellation (returns null)
  /// - Permission denial (returns null)
  /// - Camera not available (rethrows exception)
  static Future<XFile?> pickImageFromCamera() async {
    try {
      // Request camera permission (mobile only; web returns true)
      final permissionGranted =
          await PermissionService.requestCameraPermission();

      if (!permissionGranted) {
        PermissionService.showPermissionDeniedMessage('camera');
        return null;
      }

      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      // On mobile: null typically means permission denied or user cancelled
      // On web: camera access may not be available
      if (pickedFile == null && !kIsWeb) {
        PermissionService.showPermissionDeniedMessage('camera');
      }

      return pickedFile;
    } catch (e) {
      rethrow;
    }
  }

  /// Validate image locally before upload [T098]
  ///
  /// Performs comprehensive validation:
  /// - Format check: JPEG or PNG only
  /// - Size check: ≤5MB limit
  /// - Dimensions check: 100x100 to 5000x5000 pixels
  ///
  /// Returns: [ValidationError] if invalid, null if valid
  ///
  /// This uses the comprehensive [ImageValidator] for all validation checks
  /// and returns specific validation error types that can be mapped to
  /// user-friendly error messages.
  static Future<ValidationError?> validateImageComprehensive(XFile file) async {
    try {
      final bytes = await file.readAsBytes();

      // Use bytes-first validation on web; mobile can also use this path safely.
      final error = await ImageValidator.validateImageBytes(
        filename: file.name,
        bytes: bytes,
      );

      return error;
    } catch (e) {
      // NetworkError enum value may not always be present in older branches.
      return ValidationError.imageDimensionsInvalid;
    }
  }

  /// Validate image format and extension only [Backward compatible]
  ///
  /// Quick validation before full validation
  ///
  /// Returns: null if valid, error message string if invalid
  ///
  /// Checks:
  /// - File extension (JPEG/PNG only)
  static String? validateImage(XFile file) {
    // Check file extension
    final fileName = file.name.toLowerCase();
    if (!fileName.endsWith('.jpg') &&
        !fileName.endsWith('.jpeg') &&
        !fileName.endsWith('.png')) {
      return 'Only JPEG and PNG formats are supported';
    }

    // Note: For full validation including file size and dimensions,
    // use validateImageComprehensive() or ImageValidator.validateImage()

    return null; // Valid format
  }
}
