/// Profile constants for validation rules
/// 
/// Centralized validation limits used by both frontend and backend
/// to ensure consistent validation across the application.

class ProfileConstants {
  /// Minimum username length (characters)
  static const int minUsernameLength = 3;

  /// Maximum username length (characters)
  static const int maxUsernameLength = 32;

  /// Maximum bio/about me length (characters)
  static const int maxBioLength = 500;

  /// Maximum image file size (bytes)
  /// 5MB = 5 * 1024 * 1024
  static const int maxImageSizeBytes = 5242880;

  /// Minimum image dimension (pixels), both width and height
  static const int minImageDimension = 100;

  /// Maximum image dimension (pixels), both width and height
  static const int maxImageDimension = 5000;

  /// Server-side compressed image dimension (square, pixels)
  /// Images are compressed to this exact size server-side
  static const int compressedImageDimension = 500;

  /// Supported image formats (lowercase)
  static const List<String> supportedImageFormats = ['jpeg', 'png'];

  /// Cache duration for profile data
  static const Duration profileCacheDuration = Duration(minutes: 5);

  /// API request timeout duration
  static const Duration apiTimeoutDuration = Duration(seconds: 30);

  /// Minimum delay between duplicate operations (e.g., rapid uploads)
  static const Duration minOperationDelay = Duration(milliseconds: 1000);

  // Regex patterns for validation
  /// Username pattern: alphanumeric, underscore, hyphen
  /// Must start and end with alphanumeric character
  static const String usernamePattern = r'^[a-zA-Z0-9]([a-zA-Z0-9_-]*[a-zA-Z0-9])?$';

  // Private constructor to prevent instantiation
  ProfileConstants._();
}
