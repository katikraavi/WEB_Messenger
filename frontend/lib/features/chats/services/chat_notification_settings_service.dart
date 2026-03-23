import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ChatNotificationSettingsService {
  ChatNotificationSettingsService._();

  static final ChatNotificationSettingsService instance =
      ChatNotificationSettingsService._();

  final http.Client _httpClient = http.Client();
  final Set<String> _mutedChatIds = <String>{};

  String get _baseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8081',
      );

  bool isMutedLocally(String chatId) => _mutedChatIds.contains(chatId);

  Future<void> syncMutedChats(String token) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/notifications/muted-chats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to sync muted chats: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final chatIds = (json['chat_ids'] as List<dynamic>? ?? const <dynamic>[])
        .map((id) => id as String)
        .toSet();

    _mutedChatIds
      ..clear()
      ..addAll(chatIds);
  }

  Future<bool> fetchMuteStatus({
    required String token,
    required String chatId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/api/chats/$chatId/notification-settings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch notification settings: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final isMuted = json['is_muted'] as bool? ?? false;
    if (isMuted) {
      _mutedChatIds.add(chatId);
    } else {
      _mutedChatIds.remove(chatId);
    }
    return isMuted;
  }

  Future<bool> setMuted({
    required String token,
    required String chatId,
    required bool isMuted,
  }) async {
    final response = await _httpClient.put(
      Uri.parse('$_baseUrl/api/chats/$chatId/notification-settings'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'is_muted': isMuted}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update notification settings: ${response.statusCode}');
    }

    if (isMuted) {
      _mutedChatIds.add(chatId);
    } else {
      _mutedChatIds.remove(chatId);
    }

    return isMuted;
  }

  /// Register an FCM/APNs device token with the backend so push notifications
  /// can be delivered to this device.
  Future<void> registerDeviceToken({
    required String token,
    required String deviceToken,
    required String platform,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/api/notifications/device-token'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'token': deviceToken,
        'platform': platform,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to register device token: ${response.statusCode}');
    }
  }

  /// Retrieves the FCM token (if Firebase is configured) and registers it with
  /// the backend.  Silently no-ops when Firebase is absent or token retrieval fails.
  Future<void> tryRegisterFcmToken({required String token}) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      const platform = String.fromEnvironment('PLATFORM', defaultValue: '');
      await registerDeviceToken(
        token: token,
        deviceToken: fcmToken,
        platform: platform.isEmpty ? 'android' : platform,
      );
    } catch (e) {
    }
  }
}
