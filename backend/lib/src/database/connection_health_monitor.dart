import 'dart:async';
import 'package:postgres/postgres.dart';

/// Connection health monitor and auto-reconnection handler
/// Monitors the database connection and automatically reconnects if it fails
class ConnectionHealthMonitor {
  final PostgreSQLConnection _connection;
  final Duration _checkInterval;
  final Duration _reconnectDelay;
  
  Timer? _healthCheckTimer;
  bool _isMonitoring = false;
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 3;

  ConnectionHealthMonitor(
    this._connection, {
    Duration checkInterval = const Duration(seconds: 30),
    Duration reconnectDelay = const Duration(seconds: 5),
  })  : _checkInterval = checkInterval,
        _reconnectDelay = reconnectDelay;

  /// Start monitoring connection health
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    
    print('[INFO] Starting database connection health monitor (check every ${_checkInterval.inSeconds}s)');
    
    // Initial health check
    _performHealthCheck();
    
    // Schedule periodic checks
    _healthCheckTimer = Timer.periodic(_checkInterval, (_) {
      _performHealthCheck();
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _healthCheckTimer?.cancel();
    _isMonitoring = false;
    print('[INFO] Stopped database connection health monitor');
  }

  /// Perform a health check on the connection
  Future<void> _performHealthCheck() async {
    try {
      // Simple query to verify connection is alive
      await _connection.query('SELECT 1');
      
      if (_consecutiveFailures > 0) {
        print('[✓] Database connection restored after $_consecutiveFailures failures');
        _consecutiveFailures = 0;
      }
    } catch (e) {
      _consecutiveFailures++;
      print('[WARN] Database health check failed ($_consecutiveFailures/$_maxConsecutiveFailures): $e');
      
      // If too many failures, try to reconnect
      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        await _attemptReconnect();
      }
    }
  }

  /// Attempt to reconnect the database connection
  Future<void> _attemptReconnect() async {
    try {
      print('[INFO] Attempting to reconnect to database...');
      
      // Close the existing connection (if it's still somewhat alive)
      try {
        await _connection.close();
      } catch (e) {
        print('[DEBUG] Error closing old connection: $e');
      }
      
      // Wait a bit before reconnecting
      await Future.delayed(_reconnectDelay);
      
      // Reopen connection
      await _connection.open();
      print('[✓] Successfully reconnected to database');
      _consecutiveFailures = 0;
    } catch (e) {
      print('[ERROR] Reconnection failed: $e');
      // Will retry on next health check
    }
  }

  /// Check if connection is currently healthy
  Future<bool> isHealthy() async {
    try {
      await _connection.query('SELECT 1');
      return true;
    } catch (e) {
      print('[WARN] Connection health check failed: $e');
      return false;
    }
  }

  /// Ensure connection is healthy before executing query
  /// Attempts reconnection if connection is dead
  Future<bool> ensureConnectionHealthy() async {
    try {
      await _connection.query('SELECT 1');
      return true;
    } catch (e) {
      print('[WARN] Connection unhealthy, attempting recovery: $e');
      // Try immediate reconnect
      try {
        await _connection.close();
      } catch (_) {}
      
      try {
        await _connection.open();
        print('[✓] Emergency reconnection successful');
        return true;
      } catch (reconnectError) {
        print('[ERROR] Emergency reconnection failed: $reconnectError');
        return false;
      }
    }
  }
}

/// Wrapper around connection to auto-check health
extension HealthyConnection on PostgreSQLConnection {
  /// Store health monitor instance
  static final Map<PostgreSQLConnection, ConnectionHealthMonitor> _monitors = {};

  /// Initialize health monitoring for this connection
  void initializeHealthMonitoring({
    Duration checkInterval = const Duration(seconds: 30),
  }) {
    if (!_monitors.containsKey(this)) {
      final monitor = ConnectionHealthMonitor(
        this,
        checkInterval: checkInterval,
      );
      _monitors[this] = monitor;
      monitor.startMonitoring();
    }
  }

  /// Get the health monitor for this connection
  ConnectionHealthMonitor? getHealthMonitor() {
    return _monitors[this];
  }

  /// Stop monitoring this connection
  void stopHealthMonitoring() {
    _monitors[this]?.stopMonitoring();
    _monitors.remove(this);
  }
}
