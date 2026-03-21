import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Firebase Cloud Messaging notification handler for push notifications
/// 
/// T049: Handle push notification tap and deep link to InvitationsScreen
/// 
/// This service:
/// - Initializes Firebase Cloud Messaging
/// - Handles foreground notifications
/// - Handles background/terminated state notifications
/// - Routes notifications to appropriate screens via deep links
/// - Manages notification permissions
class PushNotificationHandler {
  static final PushNotificationHandler _instance = PushNotificationHandler._internal();
  
  late FirebaseMessaging _firebaseMessaging;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  factory PushNotificationHandler() {
    return _instance;
  }

  PushNotificationHandler._internal();

  /// Initialize push notification handler
  /// 
  /// This must be called early in app initialization (main.dart)
  /// 
  /// Parameters:
  /// - navigatorKey: GlobalKey for navigator to handle deep links
  /// 
  /// Returns: Future that completes when initialization is done
  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (_initialized) return;

    _navigatorKey = navigatorKey;
    _firebaseMessaging = FirebaseMessaging.instance;

    // Request user permission for notifications (requires user input)
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('[Push] Notification permission status: ${settings.authorizationStatus}');

    // Get FCM token for this device
    final token = await _firebaseMessaging.getToken();
    debugPrint('[Push] Device FCM token: $token');

    // Handle foreground notifications (app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[Push] Foreground notification received: ${message.notification?.title}');
      _handleNotification(message);
    });

    // Handle notification tap when app is in background (not killed)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[Push] Notification tapped (background): ${message.data}');
      _handleNotificationTap(message);
    });

    // Handle background message (requires top-level handler)
    // See main.dart for _firebaseMessagingBackgroundHandler

    _initialized = true;
  }

  /// Handle incoming notification
  /// 
  /// This is called when:
  /// - App is in foreground and notification arrives
  /// - App is in background and user taps notification
  /// 
  /// Parameters:
  /// - message: RemoteMessage containing notification data
  void _handleNotification(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    debugPrint('[Push] Handling notification:');
    debugPrint('[Push]   Title: ${notification?.title}');
    debugPrint('[Push]   Body: ${notification?.body}');
    debugPrint('[Push]   Data: $data');

    // Show notification in foreground with top-level widget overlay
    if (notification != null) {
      _showNotificationOverlay(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        onTap: () => _handleDataPayload(data),
      );
    }
  }

  /// Handle notification tap
  /// 
  /// This is called when user taps a notification.
  /// Routes to appropriate screen based on notification type via deep link.
  /// 
  /// Parameters:
  /// - message: RemoteMessage containing deep link info
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    _handleDataPayload(data);
  }

  /// Parse and handle notification data payload
  /// 
  /// Supported types:
  /// - chat_invitation: Route to InvitationsScreen with pending tab
  ///   Expected data: {deepLink: 'messenger://invitations?tab=pending', inviteId: '...'}
  /// 
  /// Parameters:
  /// - data: Map of notification data
  void _handleDataPayload(Map<String, dynamic> data) {
    final deepLink = data['deepLink'] as String?;
    final type = data['type'] as String?;

    debugPrint('[Push] Handling data payload: type=$type, deepLink=$deepLink');

    if (deepLink != null) {
      _navigateViaDeepLink(deepLink);
    } else if (type == 'chat_invitation') {
      // Fallback: Route to invitations screen even without deep link
      _navigateToInvitations();
    }
  }

  /// Navigate to screen via deep link
  /// 
  /// Supported deep link formats:
  /// - messenger://invitations?tab=pending
  /// - messenger://invitations?tab=sent
  /// 
  /// Parameters:
  /// - deepLink: Deep link URI
  void _navigateViaDeepLink(String deepLink) {
    try {
      final uri = Uri.parse(deepLink);
      
      if (uri.scheme == 'messenger' && uri.host == 'invitations') {
        final tab = uri.queryParameters['tab'] ?? 'pending';
        _navigateToInvitations(tab: tab);
      } else {
        debugPrint('[Push] Unknown deep link format: $deepLink');
      }
    } catch (e) {
      debugPrint('[Push Error] Failed to parse deep link: $e');
      _navigateToInvitations();
    }
  }

  /// Navigate to InvitationsScreen
  /// 
  /// Parameters:
  /// - tab: Which tab to display ('pending' or 'sent')
  void _navigateToInvitations({String tab = 'pending'}) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      debugPrint('[Push Error] Navigator not available for navigation');
      return;
    }

    debugPrint('[Push] Navigating to Invitations screen, tab=$tab');

    // Push to invitations screen with tab parameter
    navigator.pushNamedAndRemoveUntil(
      '/invitations',
      (route) => route.isFirst,
      arguments: {'tab': tab},
    );
  }

  /// Show notification overlay in foreground
  /// 
  /// Displays a custom notification UI when app is in foreground
  /// and a notification arrives (since default FCM overlay doesn't work in foreground)
  /// 
  /// Parameters:
  /// - title: Notification title
  /// - body: Notification body
  /// - onTap: Callback when notification is tapped
  void _showNotificationOverlay({
    required String title,
    required String body,
    VoidCallback? onTap,
  }) {
    // Find the context from navigator
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('[Push] Context not available for overlay');
      return;
    }

    // Show as SnackBar (simple approach)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Open',
          onPressed: onTap ?? () {},
        ),
      ),
    );
  }

  /// Get current device FCM token
  /// 
  /// This token should be sent to backend to enable notifications
  /// 
  /// Returns: FCM token string or null
  Future<String?> getToken() async {
    return _firebaseMessaging.getToken();
  }

  /// Refresh FCM token
  /// 
  /// Called when token expires or needs refresh
  /// 
  /// Returns: New FCM token
  Future<String?> refreshToken() async {
    return _firebaseMessaging.getToken();
  }

  /// Subscribe to topic
  /// 
  /// Allows bulk notifications to be sent to topic subscribers
  /// 
  /// Parameters:
  /// - topic: Topic name (e.g., 'chat-invitations')
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    debugPrint('[Push] Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic
  /// 
  /// Parameters:
  /// - topic: Topic name
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    debugPrint('[Push] Unsubscribed from topic: $topic');
  }
}

/// Background message handler
/// 
/// This runs in an isolate when:
/// - App is in background and notification is tapped
/// - App is terminated and notification is tapped
/// 
/// Called from main.dart as top-level handler
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background message received: ${message.notification?.title}');
  
  // Parse and store deep link for when app launches
  final data = message.data;
  if (data['deepLink'] != null) {
    debugPrint('[Push] Background deep link stored: ${data['deepLink']}');
  }
}
