import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:frontend/core/platform/fvp_register.dart';
import 'package:frontend/core/platform/runtime_env.dart';

const bool _suppressConsoleLogs = false;  // Enabled for debugging connection issues
const bool _skipEagerMediaInitOnWsl = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final shouldSkipMediaInit = _skipEagerMediaInitOnWsl && isWslRuntime();
  if (shouldSkipMediaInit) {
    // Avoid libsecret warnings on WSL where keyring integration is often unavailable.
    SecureStorageWrapper().forceMemoryMode();
  }

  // Only initialize media_kit on native platforms (not web)
  // media_kit is not necessary for basic functionality, so skipping
  // if it fails is fine
  if (!shouldSkipMediaInit && !kIsWeb) {
    try {
      await registerFvpIfSupported();
    } catch (_) {
      // FVP initialization failed - may be web or unavailable
    }
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
