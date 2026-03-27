import 'package:flutter/foundation.dart';

class AppExceptionLogger {
  AppExceptionLogger._();

  static void log(
    Object error, {
    StackTrace? stackTrace,
    required String context,
    bool fatal = false,
  }) {
    final severity = fatal ? 'FATAL' : 'ERROR';
    if (stackTrace != null) {
    }
  }
}