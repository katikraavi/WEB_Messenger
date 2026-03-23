import 'dart:async';

/// Error handling utilities for invitation operations
class InviteErrorHandler {
  /// Check if error is due to network/offline issues
  static bool isNetworkError(dynamic error) {
    final errorStr = error.toString();
    return errorStr.contains('SocketException') ||
        errorStr.contains('Connection') ||
        errorStr.contains('Network') ||
        errorStr.contains('timeout') ||
        errorStr.contains('offline');
  }

  /// Check if error is recoverable (user can retry)
  static bool isRecoverableError(dynamic error) {
    return isNetworkError(error) ||
        (error is HttpException && error.statusCode == null) ||
        (error is TimeoutException);
  }
  
  /// Check if error indicates the device might be offline
  static bool indicatesOfflineState(dynamic error) {
    final errorStr = error.toString();
    return errorStr.contains('Connection refused') ||
        errorStr.contains('Network unreachable') ||
        errorStr.contains('No address associated') ||
        errorStr.contains('os error: 113');
  }
  /// Map API error codes to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    if (error is TimeoutException) {
      return 'Request took too long to complete. Please check your internet connection and try again.';
    } else if (error is NetworkTimeoutException) {
      return _handleNetworkTimeout(error);
    } else if (error is NetworkException) {
      return _handleNetworkException(error);
    } else if (error is HttpException) {
      return _handleHttpException(error);
    } else if (error is TokenExpiredException) {
      return 'Your session has expired. Please log in again.';
    }
    
    return 'An unexpected error occurred. Please try again.';
  }

  static String _handleNetworkTimeout(NetworkTimeoutException error) {
    return 'Request timed out. Please check your internet connection and try again.';
  }

  static String _handleNetworkException(NetworkException error) {
    if (error.message.contains('Connection refused')) {
      return 'Cannot connect to server. Please check if the backend is running.';
    }
    if (error.message.contains('No internet')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Network error: ${error.message}';
  }

  static String _handleHttpException(HttpException error) {
    final statusCode = error.statusCode;
    final message = error.message;

    switch (statusCode) {
      case 400:
        // Validation errors from backend
        if (message.contains('self-invite') || message.contains('self invite')) {
          return 'You cannot send an invitation to yourself.';
        }
        if (message.contains('already chatting') || message.contains('existing chat')) {
          return 'You\'re already chatting with this user.';
        }
        if (message.contains('already sent') || message.contains('Pending invitation')) {
          return 'You\'ve already sent an invitation to this user.';
        }
        if (message.contains('Not found') || message.contains('not found')) {
          return 'User not found. Please check the user ID.';
        }
        return 'Invalid request. Please check your input and try again.';

      case 401:
        throw TokenExpiredException('Session expired');

      case 403:
        return 'You don\'t have permission to perform this action.';

      case 404:
        return 'Invitation or user not found.';

      case 409:
        return 'An invitation has already been sent to this user.';

      case 422:
        return 'Invalid data. Please check your input.';

      case 429:
        return 'Too many requests. Please wait a moment and try again.';

      case 500:
      case 502:
      case 503:
        return 'Server error. The service may be temporarily unavailable. Please try again later.';

      case 504:
        return 'Server timeout. Please check your connection and try again.';

      default:
        return message.isNotEmpty
            ? message
            : 'An error occurred. Please try again.';
    }
  }

  /// Get recovery suggestions based on error type with actionable steps
  static String getRecoverySuggestion(dynamic error) {
    if (error is TimeoutException) {
      return 'Retry • Check Connection • Try Later';
    } else if (error is NetworkTimeoutException) {
      return 'Retry • Check Connection • Try Later';
    } else if (error is NetworkException) {
      if (indicatesOfflineState(error)) {
        return 'Check Connection • Enable WiFi/Mobile';
      }
      return 'Check Connection • Restart App';
    } else if (error is HttpException) {
      if (error.statusCode == 401) {
        return 'Log In Again';
      } else if (error.statusCode == 500 || error.statusCode == 502 || error.statusCode == 503) {
        return 'Retry • Try Later • Contact Support';
      } else if (error.statusCode == 404) {
        return 'Check User ID • Refresh';
      } else if (error.statusCode == 429) {
        return 'Wait a moment • Try Again';
      } else if ((error.statusCode ?? 0) >= 400) {
        return 'Check Input • Retry';
      }
    }
    return 'Retry';
  }

  /// Log errors for debugging (non-production logging)
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    if (stackTrace != null) {
    }
  }

  /// Categorize error severity for UI response
  static ErrorSeverity getErrorSeverity(dynamic error) {
    if (error is TimeoutException || error is NetworkTimeoutException) {
      return ErrorSeverity.high; // Network issue
    } else if (error is TokenExpiredException) {
      return ErrorSeverity.critical; // Requires immediate action
    } else if (error is NetworkException) {
      if (indicatesOfflineState(error)) {
        return ErrorSeverity.critical; // Device is offline
      }
      return ErrorSeverity.high; // Cannot proceed without fix
    } else if (error is HttpException) {
      final code = error.statusCode ?? 0;
      if (code >= 500) {
        return ErrorSeverity.high;
      } else if (code == 401 || code == 403) {
        return ErrorSeverity.medium;
      } else if (code == 429) {
        return ErrorSeverity.medium; // Rate limited
      } else if (code >= 400) {
        return ErrorSeverity.low;
      }
    }
    return ErrorSeverity.low;
  }
}

/// Error severity levels
enum ErrorSeverity {
  low,     // User can retry
  medium,  // Validation or permission issue
  high,    // Network or server issue
  critical // Session or auth issue
}

/// Custom exception for HTTP errors
class HttpException implements Exception {
  final String message;
  final int? statusCode;

  HttpException(this.message, this.statusCode) : assert(message.isNotEmpty);

  @override
  String toString() => 'HttpException: $message (status: $statusCode)';
}

/// Custom exception for network timeout errors
class NetworkTimeoutException implements Exception {
  final String message;
  final Duration timeout;

  NetworkTimeoutException(this.message, {this.timeout = const Duration(seconds: 30)});

  @override
  String toString() => 'NetworkTimeoutException: $message (timeout: ${timeout.inSeconds}s)';
}

/// Custom exception for general network errors
class NetworkException implements Exception {
  final String message;
  final dynamic originalError;

  NetworkException(this.message, {this.originalError});

  @override
  String toString() => 'NetworkException: $message';
}

/// Custom exception for token expiration
class TokenExpiredException implements Exception {
  final String message;

  TokenExpiredException(this.message);

  @override
  String toString() => 'TokenExpiredException: $message';
}
