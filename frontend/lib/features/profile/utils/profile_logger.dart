/// Profile Feature Logging Utility [T147]
///
/// Provides debug logging for profile operations (non-sensitive data only)
/// Used to track API calls, validations, and state changes

class ProfileLogger {
  static const String _prefix = '[Profile]';
  static const bool _enabled = true; // Can be disabled for production

  /// Log API request
  static void logApiRequest(String method, String endpoint) {
    if (!_enabled) return;
    print('$_prefix → $method $endpoint');
  }

  /// Log API response
  static void logApiResponse(String method, String endpoint, int statusCode) {
    if (!_enabled) return;
    final status = statusCode >= 200 && statusCode < 300 ? '✓' : '✗';
    print('$_prefix $status $method $endpoint ($statusCode)');
  }

  /// Log validation result
  static void logValidation(String field, bool isValid, String? error) {
    if (!_enabled) return;
    final result = isValid ? '✓' : '✗';
    print('$_prefix Validation $result $field${error != null ? ': $error' : ''}');
  }

  /// Log state change
  static void logStateChange(String operation, String data) {
    if (!_enabled) return;
    print('$_prefix State: $operation → $data');
  }

  /// Log error
  static void logError(String operation, String error) {
    if (!_enabled) return;
    print('$_prefix ERROR: $operation: $error');
  }

  /// Log cache operation
  static void logCache(String operation, String userId) {
    if (!_enabled) return;
    print('$_prefix Cache: $operation for $userId');
  }
}
