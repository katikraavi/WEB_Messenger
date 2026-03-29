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
    if (kIsWeb) {
      final base = Uri.base;
      if ((base.scheme == 'http' || base.scheme == 'https') &&
          base.authority.isNotEmpty) {
        return '${base.scheme}://${base.authority}';
      }
    }
    return 'https://web-messenger-backend.onrender.com';
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
  static String getWebSocketUrl([String path = '/ws/messages']) {
    if (kIsWeb) {
      // On web, derive WebSocket URL from current window location
      // https://example.com/ → wss://example.com/ws/messages
      // http://example.com/ → ws://example.com/ws/messages
      final protocol = Uri.base.scheme == 'https' ? 'wss' : 'ws';
      final host = Uri.base.hasPort ? '${Uri.base.host}:${Uri.base.port}' : Uri.base.host;
      return '$protocol://$host$path';
    } else {
      // For non-web platforms, derive from _baseUrl
      if (_baseUrl.startsWith('https://')) {
        return _baseUrl.replaceFirst('https://', 'wss://').replaceAll(RegExp(r'/$'), '') + path;
      } else if (_baseUrl.startsWith('http://')) {
        return _baseUrl.replaceFirst('http://', 'ws://').replaceAll(RegExp(r'/$'), '') + path;
      }
      // Fallback
      return 'wss://web-messenger-backend.onrender.com$path';
    }
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
      _isHealthy = await connectToBackend();
      return;
    }

    // Set base URL based on platform
    if (kIsWeb) {
      // For web builds, use BACKEND_URL from build-time define.
      // Default to same-origin so hosted frontend can call its paired backend
      // without requiring an explicit environment variable.
      const String envBackendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '/');
      _baseUrl = _normalizeConfiguredBaseUrl(envBackendUrl);
    } else {
      _baseUrl = _defaultBaseUrl();
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
          return true;
        }
      } catch (e) {}

      // Wait before next retry (except after last attempt)
      if (attempt < maxRetries - 1) {
        final delay = delays[attempt];
        await Future.delayed(Duration(milliseconds: delay));
      }
    }

    return false;
  }

  /// Check if backend health endpoint is responding
  ///
  /// Returns true if /health endpoint responds with 200 and valid JSON
  /// Check if backend health endpoint is responding
  ///
  /// Returns true if /health endpoint responds with 200 and valid JSON
  /// Returns false if connection fails or response is invalid
  static Future<bool> isHealthy() async {
    try {
      final response = await _httpClient
          .get(Uri.parse(_buildUrl('/health')))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Health check timeout'),
          );

      if (response.statusCode == 200) {
        // Parse JSON response
        // Expected: {"status": "ok", "timestamp": "<ISO8601>", "uptime_ms": <number>}
        return true;
      } else {
        return false;
      }
    } catch (e) {
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
    }
    
    // Base URL should always be absolute at this point (http/https)
    // Remove trailing slash from base URL if present
    String base = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    
    // Ensure endpoint starts with /
    if (!endpoint.startsWith('/')) {
      endpoint = '/$endpoint';
    }
    
    return base + endpoint;
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
