import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';

/// HTTP Client for connecting to Serverpod backend
/// 
/// Features:
/// - Exponential backoff retry logic (5 attempts: 100ms, 500ms, 2s, 5s, 10s)
/// - Health check endpoint verification
/// - Base URL configuration for Android/iOS emulator differences

class ApiClient {
  static late String _baseUrl;
  static late http.Client _httpClient;
  static bool _isHealthy = false;

  /// Initialize API client with backend URL
  /// 
  /// Automatically detects platform and sets appropriate backend URL:
  /// - Android emulator: http://host.docker.internal:8081
  /// - iOS simulator: http://localhost:8081
  /// - Linux/Web: http://localhost:8081
  /// - Physical device: http://localhost:8081 (configure for your network)
  static Future<void> initialize() async {
    _httpClient = http.Client();
    
    // Set base URL based on platform
    if (Platform.isAndroid) {
      _baseUrl = 'http://host.docker.internal:8081';
    } else {
      // For iOS, Linux, macOS, Windows, Web: use localhost
      _baseUrl = 'http://localhost:8081';
    }
    
    // Try to connect to backend with retry logic
    _isHealthy = await connectToBackend();
  }

  /// Connect to backend with exponential backoff retry logic
  /// 
  /// Attempts: 5 times with delays: 100ms, 500ms, 2s, 5s, 10s
  /// Returns true if health check succeeds, false after all retries exhausted
  static Future<bool> connectToBackend() async {
    const maxRetries = 5;
    const delays = [100, 500, 2000, 5000, 10000]; // milliseconds

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final isServerHealthy = await isHealthy();
        if (isServerHealthy) {
          print('[API Client] Backend connected successfully on attempt ${attempt + 1}');
          return true;
        }
      } catch (e) {
        print('[API Client] Connection attempt ${attempt + 1} failed: $e');
      }

      // Wait before next retry (except after last attempt)
      if (attempt < maxRetries - 1) {
        final delay = delays[attempt];
        print('[API Client] Retrying in ${delay}ms...');
        await Future.delayed(Duration(milliseconds: delay));
      }
    }

    print('[API Client] Failed to connect to backend after $maxRetries attempts');
    return false;
  }

  /// Check if backend health endpoint is responding
  /// 
  /// Returns true if /health endpoint responds with 200 and valid JSON
  /// Returns false if connection fails or response is invalid
  static Future<bool> isHealthy() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Health check timeout'),
      );

      if (response.statusCode == 200) {
        // Parse JSON response
        // Expected: {"status": "ok", "timestamp": "<ISO8601>", "uptime_ms": <number>}
        print('[API Client] Backend health check passed');
        return true;
      } else {
        print('[API Client] Health check failed with status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('[API Client] Health check error: $e');
      return false;
    }
  }

  /// Get base URL for backend
  static String getBaseUrl() => _baseUrl;

  /// Check if backend connection is established
  static bool get isConnected => _isHealthy;

  /// Set base URL manually (for testing or special configurations)
  static void setBaseUrl(String url) => _baseUrl = url;

  /// Make GET request to backend endpoint
  /// 
  /// Example: ApiClient.get('/users') → http://host.docker.internal:8081/users
  static Future<http.Response> get(String endpoint) async {
    return _httpClient.get(Uri.parse('$_baseUrl$endpoint'));
  }

  /// Make POST request to backend endpoint
  static Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _httpClient.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: body,
    );
  }

  /// Make PUT request to backend endpoint
  static Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _httpClient.put(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: body,
    );
  }

  /// Make DELETE request to backend endpoint
  static Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    return _httpClient.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
    );
  }

  /// Close HTTP client (call when app is shutting down)
  static void dispose() {
    _httpClient.close();
  }
}
