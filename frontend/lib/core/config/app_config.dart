import 'package:flutter/material.dart';

/// Frontend application configuration and constants

class AppConfig {
  static const String appName = 'Mobile Messenger';
  static const String appVersion = '1.0.0';
  
    // Backend configuration defaults to hosted backend origin.
    static const String backendUrlAndroid =
      'https://web-messenger-backend.onrender.com';
    static const String backendUrlIOS =
      'https://web-messenger-backend.onrender.com';
    static const String backendUrlPhysicalDevice =
      'https://web-messenger-backend.onrender.com';
  
  /// Get backend URL for web platform
  /// When deployed on Render, uses BACKEND_URL env var injected at build time
  /// For local development, uses localhost:8081
  static String get backendUrlWeb {
    // Try to get from environment variable first (set at build time)
    const String envBackendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');
    if (envBackendUrl.isNotEmpty && envBackendUrl != '/') {
      return envBackendUrl;
    }
    // Local development default: connect to localhost:8081
    return 'http://localhost:8081';
  }
  
  // API configuration
  static const int connectionTimeoutSeconds = 30;
  static const int retryAttempts = 5;
  static const List<int> retryDelaysMs = [100, 500, 2000, 5000, 10000];
  
  // UI configuration  
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color accentColor = Color(0xFFFF5722);
  
  // Feature flags
  static const bool enableLogging = true;
  static const bool enableAnalytics = false;
}

// Colors
const Color primaryColor = Color(0xFF2196F3);
const Color accentColor = Color(0xFFFF5722);
const Color successColor = Color(0xFF4CAF50);
const Color errorColor = Color(0xFFF44336);
const Color warningColor = Color(0xFFFFC107);
