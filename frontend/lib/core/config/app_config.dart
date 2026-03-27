import 'package:flutter/material.dart';

/// Frontend application configuration and constants

class AppConfig {
  static const String appName = 'Mobile Messenger';
  static const String appVersion = '1.0.0';
  
  // Backend configuration - for web, use environment variable or current host
  // For deployed web: backend URL from environment, for local: localhost
  static const String backendUrlAndroid = 'http://host.docker.internal:8081'; // Android emulator
  static const String backendUrlIOS = 'http://localhost:8081'; // iOS simulator  
  static const String backendUrlPhysicalDevice = 'http://localhost:8081'; // Linux/macOS/Windows - Docker is accessible via localhost
  
  /// Get backend URL for web platform
  /// When deployed on Render, uses BACKEND_URL env var injected at build time
  /// For local development, uses localhost
  static String get backendUrlWeb {
    // This will be replaced at build time by Render's environment variables
    const String envBackendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:8081');
    return envBackendUrl;
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
