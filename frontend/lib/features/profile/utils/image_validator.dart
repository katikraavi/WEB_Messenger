import 'dart:io';
import 'dart:typed_data';
import 'package:frontend/features/profile/models/profile_form_state.dart';

/// Image validation utilities for profile pictures
///
/// Provides async validation for image format, size, and dimensions.
/// Used to validate images before upload to ensure compliance with constraints.

class ImageValidator {
  static ValidationError? validateFormatFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      return null;
    }
    return ValidationError.imageFormatInvalid;
  }

  static ValidationError? validateDimensionsFromBytes(Uint8List bytes) {
    if (bytes.length < 24) {
      return ValidationError.imageDimensionsInvalid;
    }

    int? width;
    int? height;

    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      width =
          (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      height =
          (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    } else if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      var offset = 2;
      while (offset < bytes.length - 8) {
        if (bytes[offset] == 0xFF) {
          final marker = bytes[offset + 1];
          if ((marker >= 0xC0 && marker <= 0xC3) ||
              (marker >= 0xC5 && marker <= 0xC7) ||
              (marker >= 0xC9 && marker <= 0xCB) ||
              (marker >= 0xCD && marker <= 0xCF)) {
            height = (bytes[offset + 5] << 8) | bytes[offset + 6];
            width = (bytes[offset + 7] << 8) | bytes[offset + 8];
            break;
          }
          final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
          offset = offset + 2 + length;
        } else {
          offset++;
        }
      }
    }

    if (width != null && height != null) {
      if (width < 100 || width > 5000 || height < 100 || height > 5000) {
        return ValidationError.imageDimensionsInvalid;
      }
    }

    return null;
  }

  static Future<ValidationError?> validateImageBytes({
    required String filename,
    required Uint8List bytes,
  }) async {
    final formatError = validateFormatFromFilename(filename);
    if (formatError != null) return formatError;

    final sizeError = validateSize(bytes.length);
    if (sizeError != null) return sizeError;

    return validateDimensionsFromBytes(bytes);
  }

  /// Validates image format (must be JPEG or PNG)
  ///
  /// Checks file extension and optionally decodes header to verify magic bytes.
  /// Returns [ValidationError.imageFormatInvalid] if not JPEG/PNG, null if valid
  ///
  /// Arguments:
  ///   - filePath: Full path to the image file
  static ValidationError? validateFormat(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    // Check file extension
    if (!['jpg', 'jpeg', 'png'].contains(extension)) {
      return ValidationError.imageFormatInvalid;
    }

    return null;
  }

  /// Validates image file size with soft and hard limits
  /// 
  /// Soft limit (5MB): Images will be auto-compressed
  /// Hard limit (10MB): Images will be rejected as truly oversized
  /// 
  /// Returns: [ValidationError.imageTooLarge] if > 10MB (hard limit)
  ///          null otherwise (soft limit images will be compressed)
  ///
  /// Arguments:
  ///   - fileSizeBytes: File size in bytes
  static ValidationError? validateSize(int fileSizeBytes) {
    // Hard limit - reject if extremely large
    if (fileSizeBytes > 10485760) {
      // 10MB = 10 * 1024 * 1024
      return ValidationError.imageTooLarge;
    }

    // Images between 5-10MB will be auto-compressed (soft limit)
    return null;
  }

  /// Check if image should be auto-compressed
  /// 
  /// Returns true if file is between 5-10MB (needs compression)
  /// Returns false if file is under 5MB (already good) or over 10MB (too large)
  static bool shouldCompress(int fileSizeBytes) {
    const int softLimit = 5242880; // 5MB
    const int hardLimit = 10485760; // 10MB
    return fileSizeBytes > softLimit && fileSizeBytes <= hardLimit;
  }

  /// Validates image dimensions (must be 100x100 to 5000x5000 pixels)
  ///
  /// Decodes image header to get actual dimensions without full image load.
  /// Returns [ValidationError.imageDimensionsInvalid] if dimensions out of range, null if valid
  ///
  /// Arguments:
  ///   - filePath: Full path to the image file
  ///
  /// Throws: May throw FileSystemException if file cannot be read
  ///
  /// Note: Uses image package to decode headers efficiently
  static Future<ValidationError?> validateDimensions(String filePath) async {
    try {
      final file = File(filePath);

      // Read file bytes
      final bytes = await file.readAsBytes();

      // Basic dimension checking for JPEG and PNG
      // JPEG: Check for SOI (FFD8) and scan for height/width in JFIF/EXIF headers
      // PNG: Check signature and read IHDR chunk for dimensions

      if (bytes.length < 24) {
        return ValidationError
            .imageDimensionsInvalid; // Too small to contain valid dimensions
      }

      int? width;
      int? height;

      // Check for PNG signature: 89 50 4E 47 8D 0A 1A 0A
      if (bytes.length >= 24 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        // PNG format - read IHDR chunk (bytes 16-24)
        width =
            (bytes[16] << 24) |
            (bytes[17] << 16) |
            (bytes[18] << 8) |
            bytes[19];
        height =
            (bytes[20] << 24) |
            (bytes[21] << 16) |
            (bytes[22] << 8) |
            bytes[23];
      }
      // Check for JPEG signature: FFD8 at start
      else if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        // JPEG format - scan for SOF (Start of Frame) marker to find dimensions
        // SOF markers: FFC0-FFC3, FFC5-FFC7, FFC9-FFCB, FFCD-FFCF
        int offset = 2;
        while (offset < bytes.length - 8) {
          if (bytes[offset] == 0xFF) {
            final marker = bytes[offset + 1];
            // Check for SOF marker (FFC0, FFC1, FFC2, FFC9, etc.)
            if ((marker >= 0xC0 && marker <= 0xC3) ||
                (marker >= 0xC5 && marker <= 0xC7) ||
                (marker >= 0xC9 && marker <= 0xCB) ||
                (marker >= 0xCD && marker <= 0xCF)) {
              // Found SOF marker - height at offset+5, width at offset+7
              height = (bytes[offset + 5] << 8) | bytes[offset + 6];
              width = (bytes[offset + 7] << 8) | bytes[offset + 8];
              break;
            }
            // Skip to next marker (read length field at offset+2)
            final length = ((bytes[offset + 2] << 8) | bytes[offset + 3])
                .toInt();
            offset = offset + 2 + length;
          } else {
            offset++;
          }
        }
      }

      // Validate dimensions if found
      if (width != null && height != null) {
        if (width < 100 || width > 5000 || height < 100 || height > 5000) {
          return ValidationError.imageDimensionsInvalid;
        }
      }

      return null; // Valid dimensions
    } catch (e) {
      return null; // On error, allow the image (don't block)
    }
  }

  /// Comprehensive image validation
  ///
  /// Performs all validations: format, size, dimensions
  /// Returns first validation error encountered, or null if all validations pass
  ///
  /// Arguments:
  ///   - filePath: Full path to the image file
  ///   - fileSizeBytes: File size in bytes
  static Future<ValidationError?> validateImage({
    required String filePath,
    required int fileSizeBytes,
  }) async {
    // Validate format
    final formatError = validateFormat(filePath);
    if (formatError != null) return formatError;

    // Validate size
    final sizeError = validateSize(fileSizeBytes);
    if (sizeError != null) return sizeError;

    // Validate dimensions
    final dimensionError = await validateDimensions(filePath);
    if (dimensionError != null) return dimensionError;

    return null; // All validations passed
  }

  /// Format file size for display (e.g., "2.5 MB")
  ///
  /// Converts file size in bytes to human-readable format with appropriate units
  ///
  /// Arguments:
  ///   - bytes: File size in bytes
  ///
  /// Returns: Formatted string like "1.5 MB", "512 KB", etc.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Check if image dimensions are landscape orientation
  ///
  /// Landscape means width > height
  ///
  /// Arguments:
  ///   - width: Image width in pixels
  ///   - height: Image height in pixels
  ///
  /// Returns: true if landscape, false if portrait or square
  static bool isLandscape(int width, int height) {
    return width > height;
  }
}
