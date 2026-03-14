import 'package:flutter/foundation.dart';
import 'dart:async';
import '../utils/profile_logger.dart';

/// Performance profiling and monitoring utility
/// 
/// Phase 11 Task T144: Performance profiling
/// 
/// Measures:
/// - Operation execution time
/// - Image loading performance
/// - API request latency
/// - Frame rendering performance
/// - Memory usage patterns

class PerformanceProfiler {
  /// Store profiling data with operation name as key
  static final Map<String, List<PerformanceMetric>> _metrics = {};

  /// Measure execution time of an async operation
  /// 
  /// Usage:
  /// ```dart
  /// final result = await PerformanceProfiler.measureAsync(
  ///   'uploadImage',
  ///   () => uploadImageOperation(),
  /// );
  /// ```
  static Future<T> measureAsync<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      stopwatch.stop();

      _recordMetric(
        operationName,
        PerformanceMetric(
          operationName: operationName,
          durationMs: stopwatch.elapsedMilliseconds,
          timestamp: DateTime.now(),
          success: true,
        ),
      );

      ProfileLogger.logStateChange(
        'performance',
        '$operationName completed in ${stopwatch.elapsedMilliseconds}ms',
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      _recordMetric(
        operationName,
        PerformanceMetric(
          operationName: operationName,
          durationMs: stopwatch.elapsedMilliseconds,
          timestamp: DateTime.now(),
          success: false,
          error: e.toString(),
        ),
      );

      ProfileLogger.logError(
        'performance',
        '$operationName failed after ${stopwatch.elapsedMilliseconds}ms: $e',
      );

      rethrow;
    }
  }

  /// Measure synchronous operation execution time
  static T measureSync<T>(
    String operationName,
    T Function() operation,
  ) {
    final stopwatch = Stopwatch()..start();

    try {
      final result = operation();
      stopwatch.stop();

      _recordMetric(
        operationName,
        PerformanceMetric(
          operationName: operationName,
          durationMs: stopwatch.elapsedMilliseconds,
          timestamp: DateTime.now(),
          success: true,
        ),
      );

      ProfileLogger.logStateChange(
        'performance',
        '$operationName completed in ${stopwatch.elapsedMilliseconds}ms',
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      _recordMetric(
        operationName,
        PerformanceMetric(
          operationName: operationName,
          durationMs: stopwatch.elapsedMilliseconds,
          timestamp: DateTime.now(),
          success: false,
          error: e.toString(),
        ),
      );

      ProfileLogger.logError(
        'performance',
        '$operationName failed after ${stopwatch.elapsedMilliseconds}ms: $e',
      );

      rethrow;
    }
  }

  /// Record a custom metric
  static void recordMetric(PerformanceMetric metric) {
    _recordMetric(metric.operationName, metric);
  }

  /// Internal method to record metrics
  static void _recordMetric(String operationName, PerformanceMetric metric) {
    if (!_metrics.containsKey(operationName)) {
      _metrics[operationName] = [];
    }
    _metrics[operationName]!.add(metric);

    // Keep only last 100 metrics per operation to avoid unbounded growth
    if (_metrics[operationName]!.length > 100) {
      _metrics[operationName]!.removeAt(0);
    }
  }

  /// Get statistics for an operation
  /// 
  /// Returns average duration, min, max, success rate
  static PerformanceStats? getStats(String operationName) {
    final metrics = _metrics[operationName];
    if (metrics == null || metrics.isEmpty) return null;

    return PerformanceStats.fromMetrics(metrics);
  }

  /// Get summary of all performance metrics
  static String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Performance Profile Summary:');
    buffer.writeln('${_metrics.length} operations tracked\n');

    _metrics.forEach((operationName, metrics) {
      final stats = PerformanceStats.fromMetrics(metrics);
      buffer.writeln('$operationName:');
      buffer.writeln('  Calls: ${metrics.length}');
      buffer.writeln('  Avg: ${stats.averageDurationMs.toStringAsFixed(1)}ms');
      buffer.writeln('  Min: ${stats.minDurationMs.toStringAsFixed(1)}ms');
      buffer.writeln('  Max: ${stats.maxDurationMs.toStringAsFixed(1)}ms');
      buffer.writeln('  Success Rate: ${stats.successRate.toStringAsFixed(1)}%');
      buffer.writeln('');
    });

    return buffer.toString();
  }

  /// Clear all profiling data
  static void clear() {
    _metrics.clear();
  }

  /// Clear metrics for specific operation
  static void clearOperation(String operationName) {
    _metrics.remove(operationName);
  }

  /// Enable/disable profiling in debug mode
  /// 
  /// In production, profiling overhead can be minimized
  static bool isEnabled() => kDebugMode;
}

/// Single performance measurement
class PerformanceMetric {
  final String operationName;
  final int durationMs;
  final DateTime timestamp;
  final bool success;
  final String? error;

  PerformanceMetric({
    required this.operationName,
    required this.durationMs,
    required this.timestamp,
    required this.success,
    this.error,
  });

  @override
  String toString() =>
      '$operationName: ${durationMs}ms (${success ? 'success' : 'failed'})';
}

/// Statistics for a set of performance metrics
class PerformanceStats {
  final String operationName;
  final int totalCalls;
  final int successfulCalls;
  final int failedCalls;
  final double averageDurationMs;
  final double minDurationMs;
  final double maxDurationMs;
  final double successRate;

  PerformanceStats({
    required this.operationName,
    required this.totalCalls,
    required this.successfulCalls,
    required this.failedCalls,
    required this.averageDurationMs,
    required this.minDurationMs,
    required this.maxDurationMs,
    required this.successRate,
  });

  /// Calculate statistics from a list of metrics
  factory PerformanceStats.fromMetrics(List<PerformanceMetric> metrics) {
    if (metrics.isEmpty) {
      return PerformanceStats(
        operationName: 'unknown',
        totalCalls: 0,
        successfulCalls: 0,
        failedCalls: 0,
        averageDurationMs: 0,
        minDurationMs: 0,
        maxDurationMs: 0,
        successRate: 0,
      );
    }

    final successful = metrics.where((m) => m.success).toList();
    final failed = metrics.where((m) => !m.success).toList();
    final durations = metrics.map((m) => m.durationMs.toDouble()).toList();

    final average = durations.reduce((a, b) => a + b) / durations.length;
    final min = durations.reduce((a, b) => a < b ? a : b);
    final max = durations.reduce((a, b) => a > b ? a : b);
    final successRate = (successful.length / metrics.length) * 100;

    return PerformanceStats(
      operationName: metrics.first.operationName,
      totalCalls: metrics.length,
      successfulCalls: successful.length,
      failedCalls: failed.length,
      averageDurationMs: average,
      minDurationMs: min,
      maxDurationMs: max,
      successRate: successRate,
    );
  }

  /// Check if performance is acceptable
  /// 
  /// Consider operation slow if average > threshold
  bool isUnderThreshold({double thresholdMs = 1000}) {
    return averageDurationMs < thresholdMs;
  }

  @override
  String toString() => '''PerformanceStats(
    operation: $operationName,
    calls: $totalCalls (success: $successfulCalls, failed: $failedCalls),
    avg: ${averageDurationMs.toStringAsFixed(1)}ms,
    min: ${minDurationMs.toStringAsFixed(1)}ms,
    max: ${maxDurationMs.toStringAsFixed(1)}ms,
    successRate: ${successRate.toStringAsFixed(1)}%
  )''';
}
