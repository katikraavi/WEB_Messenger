import 'dart:async';
import 'dart:convert' show Encoding;
import 'dart:io';
import 'package:http/http.dart' as http;

/// Enhanced HTTP client with timeout, retry, and error recovery support
class ResilientHttpClient {
  // Configuration constants
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(milliseconds: 500);
  static const double retryBackoffMultiplier = 2.0;

  final http.Client _innerClient;
  final Duration timeout;
  final int maxRetryAttempts;
  
  ResilientHttpClient({
    http.Client? client,
    this.timeout = defaultTimeout,
    this.maxRetryAttempts = maxRetries,
  }) : _innerClient = client ?? http.Client();

  /// Make a GET request with resilience (retry, timeout)
  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    bool retryOn401 = false,
  }) async {
    return _makeRequestWithRetry(
      () => _innerClient.get(uri, headers: headers),
      'GET',
      uri.toString(),
      retryOn401: retryOn401,
    );
  }

  /// Make a POST request with resilience (retry, timeout)
  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool retryOn401 = false,
  }) async {
    return _makeRequestWithRetry(
      () => _innerClient.post(uri, headers: headers, body: body, encoding: encoding),
      'POST',
      uri.toString(),
      retryOn401: retryOn401,
    );
  }

  /// Make a DELETE request with resilience (retry, timeout)
  Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool retryOn401 = false,
  }) async {
    return _makeRequestWithRetry(
      () => _innerClient.delete(uri, headers: headers, body: body, encoding: encoding),
      'DELETE',
      uri.toString(),
      retryOn401: retryOn401,
    );
  }

  /// Make a request with automatic retry and timeout handling
  Future<http.Response> _makeRequestWithRetry(
    Future<http.Response> Function() request,
    String method,
    String url,
    {bool retryOn401 = false}
  ) async {
    int attempt = 0;
    Duration delay = initialRetryDelay;
    
    while (attempt <= maxRetryAttempts) {
      try {
        attempt++;
        
        // Execute request with timeout
        final response = await request().timeout(
          timeout,
          onTimeout: () => throw TimeoutException(
            'Request timeout after ${timeout.inSeconds}s',
            timeout,
          ),
        );

        // Check if we should retry based on status code
        if (_shouldRetry(response.statusCode, retryOn401)) {
          if (attempt <= maxRetryAttempts) {
            await Future.delayed(delay);
            delay *= retryBackoffMultiplier;
            continue;
          }
        }

        // Return successful response or final attempt
        return response;
      } on TimeoutException catch (e) {
        if (attempt <= maxRetryAttempts) {
          await Future.delayed(delay);
          delay *= retryBackoffMultiplier;
          continue;
        } else {
          rethrow;
        }
      } on SocketException catch (e) {
        if (attempt <= maxRetryAttempts && _isRetryableSocketError(e)) {
          await Future.delayed(delay);
          delay *= retryBackoffMultiplier;
          continue;
        } else {
          rethrow;
        }
      }
    }

    throw Exception('Max retry attempts exceeded');
  }

  /// Determine if a status code warrants a retry
  bool _shouldRetry(int statusCode, bool retryOn401) {
    // Server errors (5xx) - always retry
    if (statusCode >= 500 && statusCode < 600) {
      return true;
    }

    // Too Many Requests - retry
    if (statusCode == 429) {
      return true;
    }

    // Unauthorized - only retry if explicitly requested
    if (statusCode == 401 && retryOn401) {
      return true;
    }

    // Client errors (4xx) except 429 - don't retry
    if (statusCode >= 400 && statusCode < 500) {
      return false;
    }

    return false;
  }

  /// Determine if a socket error is potentially retryable
  bool _isRetryableSocketError(SocketException e) {
    // Connection refused, reset, or broken pipe - retry if transient
    return e.osError?.errorCode != null;
  }

  /// Close the underlying client
  void close() {
    _innerClient.close();
  }

  /// Get retry statistics for monitoring
  Map<String, dynamic> getStats() {
    return {
      'timeout': timeout.inSeconds,
      'maxRetries': maxRetryAttempts,
      'initialDelay': initialRetryDelay.inMilliseconds,
      'backoffMultiplier': retryBackoffMultiplier,
    };
  }
}

/// Network state listener for offline detection
class NetworkStateListener {
  final StreamController<NetworkState> _stateController = 
    StreamController<NetworkState>.broadcast();
  
  late Timer _checkTimer;
  NetworkState _currentState = NetworkState.unknown;
  
  Stream<NetworkState> get stateStream => _stateController.stream;
  
  NetworkState get currentState => _currentState;

  /// Start monitoring network state
  void startMonitoring({Duration checkInterval = const Duration(seconds: 5)}) {
    _checkTimer = Timer.periodic(checkInterval, (_) async {
      await _updateNetworkState();
    });
    
    // Initial check
    _updateNetworkState();
  }

  /// Stop monitoring network state
  void stopMonitoring() {
    _checkTimer.cancel();
    _stateController.close();
  }

  /// Check current network state by attempting a simple request
  Future<void> _updateNetworkState() async {
    try {
      final client = http.Client();
      await client.get(Uri.parse('http://8.8.8.8')).timeout(
        const Duration(seconds: 5),
      );
      _updateState(NetworkState.online);
      client.close();
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 101) {
        // Network unreachable
        _updateState(NetworkState.offline);
      } else {
        _updateState(NetworkState.degraded);
      }
    } on TimeoutException {
      _updateState(NetworkState.degraded);
    } catch (e) {
      _updateState(NetworkState.unknown);
    }
  }

  void _updateState(NetworkState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }
}

/// Represents network connectivity state
enum NetworkState {
  online,    // Connected to internet
  offline,   // No internet connection
  degraded,  // Slow or unstable connection
  unknown,   // Cannot determine state
}

/// Extension to provide user-friendly descriptions
extension NetworkStateDescription on NetworkState {
  String get description {
    switch (this) {
      case NetworkState.online:
        return 'Connected';
      case NetworkState.offline:
        return 'No Connection';
      case NetworkState.degraded:
        return 'Slow Connection';
      case NetworkState.unknown:
        return 'Checking Connection...';
    }
  }

  bool get isOnline => this == NetworkState.online;
  bool get isOffline => this == NetworkState.offline;
}
