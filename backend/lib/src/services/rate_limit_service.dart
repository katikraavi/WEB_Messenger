import 'dart:async';

/// RateLimitService enforces rate limits using a sliding window algorithm
/// 
/// Sliding window approach:
/// - Tracks attempts with timestamps
/// - Allows a fixed number of attempts within a time window
/// - Automatically clears old attempts outside the window
/// 
/// Configuration:
/// - maxAttempts: Maximum allowed attempts (e.g., 5)
/// - windowDuration: Time window for attempts (e.g., 1 hour)
/// 
/// Example usage:
///   final service = RateLimitService(
///     maxAttempts: 5,
///     windowDuration: Duration(hours: 1),
///   );
///   
///   if (await service.isRateLimited('user_email')) {
///     return 429; // Too Many Requests
///   }
///   
///   await service.recordAttempt('user_email');
class RateLimitService {
  final int maxAttempts;
  final Duration windowDuration;

  // In-memory store: identifier -> list of timestamps
  // In production, this should use Redis or similar distributed cache
  final Map<String, List<DateTime>> _attempts = {};

  RateLimitService({
    required this.maxAttempts,
    required this.windowDuration,
  });

  /// Check if an identifier is currently rate limited
  /// 
  /// Parameters:
  /// - identifier: Unique identifier (e.g., email, IP address)
  /// 
  /// Returns: true if rate limited, false otherwise
  Future<bool> isRateLimited(String identifier) async {
    await _acquireLock();
    try {
      _cleanOldAttempts(identifier);

      final attempts = _attempts[identifier] ?? [];
      return attempts.length >= maxAttempts;
    } finally {
      _releaseLock();
    }
  }

  /// Record a new attempt for an identifier
  /// 
  /// Parameters:
  /// - identifier: Unique identifier (e.g., email, IP address)
  /// 
  /// Returns: Current attempt count after recording
  Future<int> recordAttempt(String identifier) async {
    await _acquireLock();
    try {
      _cleanOldAttempts(identifier);

      if (!_attempts.containsKey(identifier)) {
        _attempts[identifier] = [];
      }

      _attempts[identifier]!.add(DateTime.now().toUtc());
      return _attempts[identifier]!.length;
    } finally {
      _releaseLock();
    }
  }

  /// Get remaining attempts before rate limit
  /// 
  /// Parameters:
  /// - identifier: Unique identifier
  /// 
  /// Returns: Number of attempts remaining (0 or positive)
  /// 
  /// Example: If maxAttempts=5 and attempts=2, returns 3
  Future<int> getRemainingAttempts(String identifier) async {
    await _acquireLock();
    try {
      _cleanOldAttempts(identifier);

      final attempts = _attempts[identifier] ?? [];
      return (maxAttempts - attempts.length).clamp(0, maxAttempts);
    } finally {
      _releaseLock();
    }
  }

  /// Get the reset time for an identifier
  /// 
  /// Parameters:
  /// - identifier: Unique identifier
  /// 
  /// Returns: DateTime when the rate limit will reset, or null if not rate limited
  Future<DateTime?> getResetTime(String identifier) async {
    await _acquireLock();
    try {
      _cleanOldAttempts(identifier);

      final attempts = _attempts[identifier] ?? [];
      if (attempts.isEmpty) {
        return null;
      }

      // Reset time is when the oldest attempt falls out of the window
      final oldestAttempt = attempts.first;
      return oldestAttempt.add(windowDuration);
    } finally {
      _releaseLock();
    }
  }

  /// Get current attempt count for an identifier
  /// 
  /// Parameters:
  /// - identifier: Unique identifier
  /// 
  /// Returns: Number of attempts in current window
  Future<int> getAttemptCount(String identifier) async {
    await _acquireLock();
    try {
      _cleanOldAttempts(identifier);

      return _attempts[identifier]?.length ?? 0;
    } finally {
      _releaseLock();
    }
  }

  /// Clear all attempts for an identifier
  /// 
  /// Parameters:
  /// - identifier: Unique identifier
  Future<void> clearAttempts(String identifier) async {
    await _acquireLock();
    try {
      _attempts.remove(identifier);
    } finally {
      _releaseLock();
    }
  }

  /// Clear all rate limit data
  /// 
  /// Use sparingly; typically only for testing
  Future<void> clearAll() async {
    await _acquireLock();
    try {
      _attempts.clear();
    } finally {
      _releaseLock();
    }
  }

  /// Remove attempts outside the sliding window
  /// 
  /// Internal method called before each operation
  void _cleanOldAttempts(String identifier) {
    final attempts = _attempts[identifier];
    if (attempts == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(windowDuration);

    // Remove attempts that are too old
    _attempts[identifier] = attempts.where((time) => time.isAfter(cutoff)).toList();

    // Clean up empty entries
    if (_attempts[identifier]!.isEmpty) {
      _attempts.remove(identifier);
    }
  }

  /// Simple lock mechanism for basic thread safety
  /// 
  /// Note: For production use, consider using:
  /// - Redis with atomic operations
  /// - Distributed lock service
  /// - Database with transactions
  Future<void> _acquireLock() async {
    // Simple serialization: wait for any pending operations
    await Future.delayed(Duration.zero);
  }

  /// Release the lock
  void _releaseLock() {
    // Lock is automatically released after _acquireLock completes
  }
}

/// Rate limit information
class RateLimitInfo {
  final bool isLimited;
  final int attemptCount;
  final int maxAttempts;
  final int remainingAttempts;
  final DateTime? resetTime;

  RateLimitInfo({
    required this.isLimited,
    required this.attemptCount,
    required this.maxAttempts,
    required this.remainingAttempts,
    this.resetTime,
  });

  /// Time until rate limit resets
  Duration? get timeUntilReset {
    if (resetTime == null) return null;
    final remaining = resetTime!.difference(DateTime.now().toUtc());
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  @override
  String toString() =>
      'RateLimitInfo(isLimited: $isLimited, attempts: $attemptCount/$maxAttempts, '
      'remaining: $remainingAttempts, resetTime: $resetTime)';
}
