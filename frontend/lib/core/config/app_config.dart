/// Frontend application configuration and constants

class AppConfig {
  static const String appName = 'Mobile Messenger';
  static const String appVersion = '1.0.0';
  
  // Backend configuration
  static const String backendUrlAndroid = 'http://host.docker.internal:8081'; // Android emulator
  static const String backendUrlIOS = 'http://localhost:8081'; // iOS simulator
  static const String backendUrlPhysicalDevice = 'http://[YOUR_DEVICE_IP]:8081'; // Update with actual IP
  
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
