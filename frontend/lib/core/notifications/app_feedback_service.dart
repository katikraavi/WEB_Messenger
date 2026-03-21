import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum AppFeedbackLevel { info, warning, error }

class AppFeedbackService {
  AppFeedbackService._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static String? _lastMessage;
  static DateTime? _lastShownAt;

  static void showInfo(String message) {
    _show(message, level: AppFeedbackLevel.info);
  }

  static void showWarning(String message) {
    _show(message, level: AppFeedbackLevel.warning);
  }

  static void showError(String message) {
    _show(message, level: AppFeedbackLevel.error);
  }

  static void _show(String message, {required AppFeedbackLevel level}) {
    if (message.trim().isEmpty) {
      return;
    }

    final now = DateTime.now();
    if (_lastMessage == message &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(seconds: 4)) {
      return;
    }

    _lastMessage = message;
    _lastShownAt = now;

    void showSnackBar() {
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: switch (level) {
            AppFeedbackLevel.info => Colors.blueGrey.shade700,
            AppFeedbackLevel.warning => Colors.orange.shade800,
            AppFeedbackLevel.error => Colors.red.shade700,
          },
          duration: Duration(seconds: level == AppFeedbackLevel.error ? 6 : 4),
        ),
      );
    }

    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    if (schedulerPhase == SchedulerPhase.idle ||
        schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      showSnackBar();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showSnackBar();
    });
  }
}
