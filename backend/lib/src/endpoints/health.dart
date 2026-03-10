import 'dart:io';

/// Health check endpoint for monitoring service status
/// 
/// Responds to GET /health with JSON containing:
/// - status: "ok" (success indicator)
/// - timestamp: ISO8601 formatted current time
/// - uptime_ms: milliseconds since server startup

class HealthEndpoint {
  static final DateTime _startTime = DateTime.now();

  /// GET /health endpoint handler
  /// Returns JSON: {"status": "ok", "timestamp": "<ISO8601>", "uptime_ms": <number>}
  static Map<String, dynamic> getHealth() {
    final now = DateTime.now().toUtc();
    final uptime = DateTime.now().difference(_startTime).inMilliseconds;

    return {
      'status': 'ok',
      'timestamp': now.toIso8601String(),
      'uptime_ms': uptime,
    };
  }

  /// Check if health is good based on uptime
  static bool isHealthy() {
    return DateTime.now().difference(_startTime).inSeconds > 0;
  }

  /// Get server startup time
  static DateTime getStartTime() => _startTime;

  /// Get current uptime in milliseconds
  static int getUptimeMs() {
    return DateTime.now().difference(_startTime).inMilliseconds;
  }
}
