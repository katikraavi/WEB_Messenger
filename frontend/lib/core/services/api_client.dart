import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

/// HTTP Client for connecting to Serverpod backend
///
/// Features:
/// - Exponential backoff retry logic (5 attempts: 100ms, 500ms, 2s, 5s, 10s)
/// - Health check endpoint verification
/// - Base URL configuration for Android/iOS emulator differences
/// - Dynamic backend URL for web deployments (from environment variables)

class ApiClient {
  static String _baseUrl = '';
  static late http.Client _httpClient;
  static bool _isHealthy = false;
  static const String _envBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '',
  );

  static final RegExp _ipv4Pattern = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

  static String _defaultBaseUrl() {
    // Priority 1: Check for environment variable (development)
    // BUT if it's just '/' (relative path), skip it and use web detection
    // Use: BACKEND_URL=http://localhost:8081 flutter run
    // Or: flutter run --dart-define=BACKEND_URL=http://localhost:8081
    if (_envBackendUrl.isNotEmpty && _envBackendUrl != '/') {
      return _envBackendUrl;
    }

    if (kIsWeb) {
      final base = Uri.base;
      // For local development on localhost, always use localhost:8081 backend
      if (base.host == 'localhost' || base.host == '127.0.0.1') {
        return 'http://localhost:8081';
      }
      // For deployed web apps, use same-origin (e.g., https://web-messenger.onrender.com)
      if ((base.scheme == 'http' || base.scheme == 'https') &&
          base.authority.isNotEmpty) {
        return '${base.scheme}://${base.authority}';
      }
    }

    // For non-web platforms (desktop, mobile), check if local backend is available
    // This enables development on emulators/desktop pointing to localhost
    // Production will fall back to the Render backend below
    
    return 'https://web-messenger-cy3r.onrender.com';
  }

  static bool _isLikelyWebResolvableHost(String host) {
    if (host.isEmpty) return false;
    if (_ipv4Pattern.hasMatch(host)) return true;
    // Single-label hosts like "api" often fail in public browser DNS contexts.
    if (!host.contains('.')) return false;
    return true;
  }

  static String _normalizeConfiguredBaseUrl(String rawUrl) {
    final candidate = rawUrl.trim();
    if (candidate.isEmpty || candidate == '/') {
      return _defaultBaseUrl();
    }

    // Relative paths on web should resolve to same-origin backend.
    if (candidate.startsWith('/')) {
      return _defaultBaseUrl();
    }

    // Support protocol-relative URLs (e.g. //api.example.com).
    if (candidate.startsWith('//')) {
      return '${Uri.base.scheme}:$candidate';
    }

    Uri? parsed = Uri.tryParse(candidate);

    // If scheme is missing and host looks usable, infer current page scheme.
    if (parsed != null && !parsed.hasScheme && parsed.host.isNotEmpty) {
      parsed = Uri.tryParse('${Uri.base.scheme}://$candidate');
    }

    if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https') || parsed.host.isEmpty) {
      return _defaultBaseUrl();
    }

    if (kIsWeb && !_isLikelyWebResolvableHost(parsed.host)) {
      return _defaultBaseUrl();
    }

    return '${parsed.scheme}://${parsed.authority}';
  }
  
  /// Get WebSocket URL for dynamic backend connection
  /// Converts relative HTTP paths to proper WebSocket URLs
  static String getWebSocketUrl([String path = '/api/ws/messages']) {
    final baseUrl = getBaseUrl(); // Use same URL for both web and mobile
    
    if (baseUrl.isEmpty) {
      print('[ApiClient] ⚠️ Base URL not initialized for WebSocket');
      return 'wss://web-messenger-cy3r.onrender.com$path';
    }
    
    // Convert HTTP/HTTPS to WS/WSS for all platforms
    if (baseUrl.startsWith('https://')) {
      final wsUrl = baseUrl.replaceFirst('https://', 'wss://').replaceAll(RegExp(r'/$'), '') + path;
      print('[ApiClient] WebSocket URL (HTTPS→WSS): $wsUrl');
      return wsUrl;
    } else if (baseUrl.startsWith('http://')) {
      final wsUrl = baseUrl.replaceFirst('http://', 'ws://').replaceAll(RegExp(r'/$'), '') + path;
      print('[ApiClient] WebSocket URL (HTTP→WS): $wsUrl');
      return wsUrl;
    }
    // Fallback
    return 'wss://web-messenger-cy3r.onrender.com$path';
  }

  /// Initialize API client with backend URL
  ///
  /// Automatically detects platform and sets appropriate backend URL:
  /// - Web (deployed): Uses BACKEND_URL from environment (Render sets this)
  /// - Web/local with explicit BACKEND_URL: uses that value
  /// - Otherwise falls back to hosted backend origin
  static Future<void> initialize() async {
    _httpClient = http.Client();

    final configuredBackendUrl = _envBackendUrl.trim();
    if (configuredBackendUrl.isNotEmpty) {
      _baseUrl = _normalizeConfiguredBaseUrl(configuredBackendUrl);
      print('🔌 [ApiClient] Using environment BACKEND_URL: $_baseUrl');
      _isHealthy = await connectToBackend();
      return;
    }

    // Set base URL based on platform
    if (kIsWeb) {
      // For web builds, use BACKEND_URL from build-time define.
      // Default to localhost:8081 for local development
      const String envBackendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:8081');
      _baseUrl = _normalizeConfiguredBaseUrl(envBackendUrl);
      print('🔌 [ApiClient] Web platform using: $_baseUrl');
    } else {
      _baseUrl = _defaultBaseUrl();
      print('🔌 [ApiClient] Mobile platform using: $_baseUrl');
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

    print('🔌 [ApiClient.connectToBackend] Starting connection with $maxRetries retries...');
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        print('🔌 [ApiClient.connectToBackend] Attempt ${attempt + 1}/$maxRetries');
        final isServerHealthy = await isHealthy();
        if (isServerHealthy) {
          print('✅ [ApiClient.connectToBackend] Connected successfully!');
          return true;
        }
      } catch (e) {
        print('❌ [ApiClient.connectToBackend] Attempt error: $e');
      }

      // Wait before next retry (except after last attempt)
      if (attempt < maxRetries - 1) {
        final delay = delays[attempt];
        print('⏳ [ApiClient.connectToBackend] Waiting ${delay}ms before retry...');
        await Future.delayed(Duration(milliseconds: delay));
      }
    }

    print('❌ [ApiClient.connectToBackend] Failed after all retries');
    return false;
  }

  /// Check if backend health endpoint is responding
  ///
  /// Returns true if /health endpoint responds with 200 and valid JSON
  /// Returns false if connection fails or response is invalid
  static Future<bool> isHealthy() async {
    try {
      final url = _buildUrl('/health');
      print('🔌 [ApiClient.isHealthy] Checking health at: $url');
      
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Health check timeout'),
          );

      print('🔌 [ApiClient.isHealthy] Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ [ApiClient.isHealthy] Backend is healthy!');
        return true;
      } else {
        print('❌ [ApiClient.isHealthy] Bad status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ [ApiClient.isHealthy] Error: $e');
      return false;
    }
  }

  /// Build proper URL from base URL and endpoint
  /// Handles both absolute URLs and endpoints correctly
  static String _buildUrl(String endpoint) {
    // Handle None/empty case
    if (_baseUrl.isEmpty) {
      final configuredBackendUrl = _envBackendUrl.trim();
      _baseUrl = configuredBackendUrl.isNotEmpty
          ? _normalizeConfiguredBaseUrl(configuredBackendUrl)
          : _defaultBaseUrl();
      print('🔌 [ApiClient] Rebuilt _baseUrl: $_baseUrl');
    }
    
    // Base URL should always be absolute at this point (http/https)
    // Remove trailing slash from base URL if present
    String base = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    
    // Ensure endpoint starts with /
    if (!endpoint.startsWith('/')) {
      endpoint = '/$endpoint';
    }
    
    final fullUrl = base + endpoint;
    print('🔌 [ApiClient] Calling: $fullUrl');
    return fullUrl;
  }

  /// Get base URL for backend
  static String getBaseUrl() {
    if (_baseUrl.isEmpty) {
      final configuredBackendUrl = _envBackendUrl.trim();
      _baseUrl = configuredBackendUrl.isNotEmpty
          ? _normalizeConfiguredBaseUrl(configuredBackendUrl)
          : _defaultBaseUrl();
    }
    return _baseUrl;
  }

  /// Check if backend connection is established
  static bool get isConnected => _isHealthy;

  /// Set base URL manually (for testing or special configurations)
  static void setBaseUrl(String url) => _baseUrl = _normalizeConfiguredBaseUrl(url);

  /// Make GET request to backend endpoint
  ///
  /// Example: ApiClient.get('/users') → http://host.docker.internal:8081/users
  static Future<http.Response> get(String endpoint) async {
    return _httpClient.get(Uri.parse(_buildUrl(endpoint)));
  }

  /// Make POST request to backend endpoint
  static Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _httpClient.post(
      Uri.parse(_buildUrl(endpoint)),
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
      Uri.parse(_buildUrl(endpoint)),
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
      Uri.parse(_buildUrl(endpoint)),
      headers: headers,
    );
  }

  /// Close HTTP client (call when app is shutting down)
  static void dispose() {
    _httpClient.close();
  }
}
