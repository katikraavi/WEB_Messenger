import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  int _inviteNotificationId(String inviteId) => inviteId.hashCode;

  Future<void> initialize({
    required void Function(Map<String, dynamic> payload) onPayloadTap,
  }) async {
    if (_initialized) {
      return;
    }

    const settings = InitializationSettings(
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      ),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          return;
        }
        onPayloadTap(jsonDecode(payload) as Map<String, dynamic>);
      },
    );

    _initialized = true;
  }

  Future<void> showMessageNotification({
    required String chatId,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      chatId.hashCode,
      title,
      body,
      const NotificationDetails(
        linux: LinuxNotificationDetails(),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({
        'type': 'chat_message',
        'chatId': chatId,
      }),
    );
  }

  Future<void> showInviteNotification({
    required String inviteId,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      _inviteNotificationId(inviteId),
      title,
      body,
      const NotificationDetails(
        linux: LinuxNotificationDetails(),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({
        'type': 'chat_invite',
        'inviteId': inviteId,
      }),
    );
  }

  Future<void> dismissInviteNotification(String inviteId) async {
    await _plugin.cancel(_inviteNotificationId(inviteId));
  }
}
