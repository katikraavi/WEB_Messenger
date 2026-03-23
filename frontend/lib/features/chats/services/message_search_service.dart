import 'dart:convert';

import 'package:http/http.dart' as http;

class MessageSearchResult {
  final String messageId;
  final String snippet;
  final DateTime sentAt;

  const MessageSearchResult({
    required this.messageId,
    required this.snippet,
    required this.sentAt,
  });

  factory MessageSearchResult.fromJson(Map<String, dynamic> json) {
    return MessageSearchResult(
      messageId: json['message_id'] as String? ?? json['messageId'] as String,
      snippet: json['snippet'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String? ?? json['sentAt'] as String),
    );
  }
}

class MessageSearchService {
  final http.Client _httpClient;
  final String _baseUrl;
  final Map<String, List<MessageSearchResult>> _cache = {};

  MessageSearchService({required String baseUrl, http.Client? httpClient})
      : _baseUrl = baseUrl,
        _httpClient = httpClient ?? http.Client();

  Future<List<MessageSearchResult>> searchMessages({
    required String token,
    required String chatId,
    required String query,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final cacheKey = '$chatId::$normalizedQuery';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final uri = Uri.parse('$_baseUrl/api/messages/search').replace(
      queryParameters: {
        'chatId': chatId,
        'q': normalizedQuery,
      },
    );

    final response = await _httpClient.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as List<dynamic>;
      final results = json
          .map((item) => MessageSearchResult.fromJson(item as Map<String, dynamic>))
          .toList();
      _cache[cacheKey] = results;
      return results;
    }

    if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    }

    if (response.statusCode == 403) {
      throw Exception('Forbidden');
    }

    throw Exception('Failed to search messages: ${response.statusCode}');
  }

  void clearCacheForChat(String chatId) {
    _cache.removeWhere((key, _) => key.startsWith('$chatId::'));
  }
}