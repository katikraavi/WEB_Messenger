import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:uni_links/uni_links.dart'; // TODO: Add uni_links dependency when implementing deep links
import 'dart:async';
import 'dart:io';

/// Handles deep links from email verification and password reset
class DeepLinkHandler {
  static StreamSubscription? _deepLinkSubscription;

  /// Initialize deep link listening
  static void init(BuildContext context) {
    if (Platform.isAndroid) {
      _initAndroidDeepLinks(context);
    } else if (Platform.isIOS) {
      _initIOSDeepLinks(context);
    }
  }

  /// Handle Android deep links
  /// Schemes: messenger://verify?token=TOKEN
  ///         messenger://reset?token=TOKEN
  static void _initAndroidDeepLinks(BuildContext context) {
    _deepLinkSubscription?.cancel();
    // TODO: Implement deep link handling once uni_links is added to dependencies
    //  _deepLinkSubscription = uriLinkStream.listen(
    //   (String link) {
    //     _handleDeepLink(context, link);
    //   },
    //   onError: (error) {
    //     print('[DeepLink] Error: $error');
    //   },
    // );
    print('[DeepLink] Android deep link support not yet enabled');
  }

  /// Handle iOS deep links
  /// Schemes: messenger://verify?token=TOKEN
  ///         messenger://reset?token=TOKEN
  static void _initIOSDeepLinks(BuildContext context) {
    _deepLinkSubscription?.cancel();
    // TODO: Implement deep link handling once uni_links is added to dependencies
    // _deepLinkSubscription = uriLinkStream.listen(
    //   (String link) {
    //     _handleDeepLink(context, link);
    //   },
    //   onError: (error) {
    //     print('[DeepLink] Error: $error');
    //   },
    // );
    print('[DeepLink] iOS deep link support not yet enabled');
  }

  /// Handle both Android and iOS deep links
  /// Examples:
  /// - messenger://verify?token=abc123
  /// - messenger://reset?token=abc123
  static void _handleDeepLink(BuildContext context, String link) {
    print('[DeepLink] Received: $link');

    try {
      final uri = Uri.parse(link);

      // Email verification deep link
      if (uri.host == 'verify' && uri.queryParameters.containsKey('token')) {
        final token = uri.queryParameters['token']!;
        print('[DeepLink] Email verification token: $token');
        _navigateToVerification(context, token);
        return;
      }

      // Password reset deep link
      if (uri.host == 'reset' && uri.queryParameters.containsKey('token')) {
        final token = uri.queryParameters['token']!;
        print('[DeepLink] Password reset token: $token');
        _navigateToPasswordReset(context, token);
        return;
      }

      print('[DeepLink] Unknown deep link: $link');
    } catch (e) {
      print('[DeepLink] Error parsing deep link: $e');
    }
  }

  /// Navigate to verification screen with token
  static void _navigateToVerification(BuildContext context, String token) {
    // Navigate to verification screen with token
    // This will be handled by the verification provider
    Navigator.of(context).pushNamed(
      '/verification-confirm',
      arguments: {'token': token},
    );
  }

  /// Navigate to password reset screen with token
  static void _navigateToPasswordReset(BuildContext context, String token) {
    // Navigate to password reset screen with token
    Navigator.of(context).pushNamed(
      '/password-reset-confirm',
      arguments: {'token': token},
    );
  }

  /// Cleanup deep link subscription
  static void dispose() {
    _deepLinkSubscription?.cancel();
  }
}

/// Widget that listens to deep links
class DeepLinkListener extends StatefulWidget {
  final Widget child;

  const DeepLinkListener({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  @override
  void initState() {
    super.initState();
    DeepLinkHandler.init(context);
  }

  @override
  void dispose() {
    DeepLinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
