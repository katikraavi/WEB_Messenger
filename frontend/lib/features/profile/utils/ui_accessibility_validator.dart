import 'package:flutter/material.dart';

/// Utility for validating UI accessibility metrics
/// 
/// Phase 11 Tasks:
/// - T139: Touch target size validation (minimum 48x48 dp)
/// - T140: Color contrast verification (WCAG AA standards)
/// 
/// This utility helps ensure the UI meets accessibility standards
/// that make the app usable for all users.

class UIAccessibilityValidator {
  /// Minimum recommended touch target size in dp (Material Design)
  static const double minTouchTargetSize = 48.0;

  /// Color contrast ratio requirements
  static const double wcagAAContrastMinimum = 4.5; // AA standard for normal text
  static const double wcagAALargeTextContrast = 3.0; // AA standard for large text
  static const double wcagAAAContrastMinimum = 7.0; // AAA standard for normal text
  static const double wcagAAALargeTextContrast = 4.5; // AAA standard for large text

  /// Validates that a button or interactive widget meets minimum touch target size
  /// 
  /// Returns true if the size is acceptable (>= 48x48 dp)
  /// 
  /// Usage:
  /// ```dart
  /// if (UIAccessibilityValidator.isValidTouchTarget(buttonWidth, buttonHeight)) {
  ///   // Button is large enough
  /// }
  /// ```
  static bool isValidTouchTarget(double width, double height) {
    return width >= minTouchTargetSize && height >= minTouchTargetSize;
  }

  /// Get recommended size for a button that's too small
  /// 
  /// Returns the minimum of the current size or 48dp
  static double getRecommendedSize(double currentSize) {
    return currentSize < minTouchTargetSize ? minTouchTargetSize : currentSize;
  }

  /// Calculate relative luminance of a color (used for contrast calculation)
  /// 
  /// Based on WCAG 2.0 specification
  /// https://www.w3.org/TR/WCAG20/#relativeluminancedef
  static double calculateRelativeLuminance(Color color) {
    final r = _linearizeColorComponent(color.red / 255);
    final g = _linearizeColorComponent(color.green / 255);
    final b = _linearizeColorComponent(color.blue / 255);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize a color component for luminance calculation
  static double _linearizeColorComponent(double value) {
    if (value <= 0.03928) {
      return value / 12.92;
    }
    return ((value + 0.055) / 1.055) * ((value + 0.055) / 1.055);
  }

  /// Calculate contrast ratio between two colors
  /// 
  /// Based on WCAG 2.0 specification
  /// Returns a value between 1 and 21 (1 = no contrast, 21 = maximum contrast)
  static double calculateContrastRatio(Color foreground, Color background) {
    final l1 = calculateRelativeLuminance(foreground);
    final l2 = calculateRelativeLuminance(background);

    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Check if contrast ratio meets WCAG AA standard for normal text
  /// 
  /// AA standard requires minimum contrast ratio of 4.5:1 for normal text
  static bool meetsWCAGAAContrast(Color foreground, Color background) {
    final contrastRatio = calculateContrastRatio(foreground, background);
    return contrastRatio >= wcagAAContrastMinimum;
  }

  /// Check if contrast ratio meets WCAG AA standard for large text
  /// 
  /// AA standard requires minimum contrast ratio of 3:1 for large text (18pt or bold 14pt+)
  static bool meetsWCAGAALargeTextContrast(Color foreground, Color background) {
    final contrastRatio = calculateContrastRatio(foreground, background);
    return contrastRatio >= wcagAALargeTextContrast;
  }

  /// Check if contrast ratio meets WCAG AAA standard for normal text
  /// 
  /// AAA standard requires minimum contrast ratio of 7:1 for normal text
  static bool meetsWCAGAAAContrast(Color foreground, Color background) {
    final contrastRatio = calculateContrastRatio(foreground, background);
    return contrastRatio >= wcagAAAContrastMinimum;
  }

  /// Get contrast ratio description (for logging/debugging)
  /// 
  /// Returns a string like "7.2:1 (AAA)" or "3.1:1 (AA)"
  static String getContrastDescription(Color foreground, Color background) {
    final contrastRatio = calculateContrastRatio(foreground, background);
    final ratioStr = contrastRatio.toStringAsFixed(1);

    if (contrastRatio >= wcagAAAContrastMinimum) {
      return '$ratioStr:1 (WCAG AAA) ✓';
    } else if (contrastRatio >= wcagAAContrastMinimum) {
      return '$ratioStr:1 (WCAG AA) ✓';
    } else {
      return '$ratioStr:1 (Below AA) ✗';
    }
  }

  /// Validate all accessibility metrics for profile screen buttons
  /// 
  /// Returns a map of validation results:
  /// {
  ///   'save_button_touch_target': true,
  ///   'save_button_contrast': true,
  ///   'cancel_button_touch_target': true,
  ///   'cancel_button_contrast': true,
  /// }
  static Map<String, bool> validateProfileEditButtons(
    double buttonWidth,
    double buttonHeight,
    Color foregroundColor,
    Color backgroundColor,
  ) {
    return {
      'touch_target': isValidTouchTarget(buttonWidth, buttonHeight),
      'contrast': meetsWCAGAAContrast(foregroundColor, backgroundColor),
      'wcag_aaa_contrast': meetsWCAGAAAContrast(foregroundColor, backgroundColor),
    };
  }

  /// Get a summary report of accessibility validation
  /// 
  /// Useful for debugging/logging
  static String getValidationReport(
    double buttonWidth,
    double buttonHeight,
    Color foregroundColor,
    Color backgroundColor,
  ) {
    final results = validateProfileEditButtons(
      buttonWidth,
      buttonHeight,
      foregroundColor,
      backgroundColor,
    );

    final contrastRatio = calculateContrastRatio(foregroundColor, backgroundColor);
    final contrastDesc = getContrastDescription(foregroundColor, backgroundColor);

    return '''
Accessibility Validation Report:
- Touch Target Size: ${buttonWidth.toStringAsFixed(1)}x${buttonHeight.toStringAsFixed(1)} dp ${results['touch_target']! ? '✓' : '✗'} (minimum: ${minTouchTargetSize}x${minTouchTargetSize})
- Contrast Ratio: $contrastDesc
- Results: ${results.values.every((v) => v) ? 'PASS ✓' : 'FAIL ✗'}
''';
  }
}
