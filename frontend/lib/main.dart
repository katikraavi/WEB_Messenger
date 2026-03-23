import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:provider/provider.dart' as provider_pkg;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:frontend/core/push_notifications/push_notification_handler.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/services/app_exception_logger.dart';
import 'package:frontend/core/services/api_client.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/utils/secure_storage_wrapper.dart';
import 'package:media_kit/media_kit.dart';

const bool _suppressConsoleLogs = true;
const bool _skipEagerMediaInitOnWsl = true;

bool _isWslRuntime() {
  if (!Platform.isLinux) {
    return false;
  }

  if (Platform.environment.containsKey('WSL_DISTRO_NAME')) {
    return true;
  }

  try {
    final version = File('/proc/version').readAsStringSync().toLowerCase();
    return version.contains('microsoft');
  } catch (_) {
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final shouldSkipMediaInit = _skipEagerMediaInitOnWsl && _isWslRuntime();
  if (shouldSkipMediaInit) {
    // Avoid libsecret warnings on WSL where keyring integration is often unavailable.
    SecureStorageWrapper().forceMemoryMode();
  }

  if (!shouldSkipMediaInit) {
    MediaKit.ensureInitialized();
    fvp.registerWith(options: {
      'platforms': ['linux'],
    });
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppExceptionLogger.log(
      details.exception,
      stackTrace: details.stack,
      context: 'FlutterError.onError',
      fatal: true,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'platform dispatcher',
        context: ErrorDescription(
          'while handling an uncaught asynchronous error',
        ),
      ),
    );
    AppExceptionLogger.log(
      error,
      stackTrace: stackTrace,
      context: 'PlatformDispatcher.onError',
      fatal: true,
    );
    return true;
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    // Firebase is not supported on this platform (e.g. Linux desktop).
    // The app will run without push notifications.
  }

  if (_suppressConsoleLogs) {
    // Suppress ad-hoc debug logs and print spam in terminal during local runs.
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Initialize API client before running app
  await ApiClient.initialize();

  runApp(
    ProviderScope(
      child: provider_pkg.MultiProvider(
        providers: [
          provider_pkg.ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(),
          ),
        ],
        child: const MessengerApp(),
      ),
    ),
  );
}
