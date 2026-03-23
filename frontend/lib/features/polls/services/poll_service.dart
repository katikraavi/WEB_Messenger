import 'dart:convert';
import 'package:http/http.dart' as http;

import '../widgets/poll_widget.dart';

/// Typed HTTP client for the poll API.
///
/// Endpoint contracts (backend/lib/src/endpoints/poll_endpoints.dart):
///   POST   /api/polls                   — create a poll
///   GET    /api/polls/<id>              — get poll with aggregated results
///   POST   /api/polls/<id>/vote         — cast or change vote
///   DELETE /api/polls/<id>/vote         — retract vote  (future)
///   POST   /api/polls/<id>/close        — close poll (creator only)
class PollServiceClient {
  final String baseUrl;
  final http.Client _client;

  PollServiceClient({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  void _assertSuccess(http.Response response, String operation) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = '';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        detail = body?['error'] as String? ?? response.body;
      } catch (_) {
        detail = response.body;
      }
      throw Exception('Failed to $operation (${response.statusCode}): $detail');
    }
  }

  /// Create a new poll in a group chat.
  ///
  /// Returns the newly created poll id.
  Future<String> createPoll({
    required String token,
    required String groupId,
    required String question,
    required List<String> options,
    required bool isAnonymous,
    DateTime? closesAt,
  }) async {
    final uri = Uri.parse('$baseUrl/api/polls');
    final body = <String, dynamic>{
      'groupId': groupId,
      'question': question,
      'options': options,
      'isAnonymous': isAnonymous,
      if (closesAt != null) 'closesAt': closesAt.toUtc().toIso8601String(),
    };
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );
    _assertSuccess(response, 'create poll');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['id'] as String;
  }

  /// Fetch poll details together with aggregated vote counts.
  ///
  /// If [currentUserId] is provided the returned [PollData] will have
  /// [PollData.currentUserVotedOptionId] populated by the backend.
  Future<PollData> getPoll({
    required String pollId,
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/polls/$pollId');
    final response = await _client.get(uri, headers: _headers(token));
    _assertSuccess(response, 'get poll');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return PollData.fromJson(decoded);
  }

  /// Cast or change a vote on [pollId] for [optionId].
  Future<void> vote({
    required String token,
    required String pollId,
    required String optionId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/polls/$pollId/vote');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'optionId': optionId}),
    );
    _assertSuccess(response, 'cast vote');
  }

  /// Close a poll.  Only the poll creator can do this.
  Future<void> closePoll({
    required String token,
    required String pollId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/polls/$pollId/close');
    final response = await _client.post(uri, headers: _headers(token));
    _assertSuccess(response, 'close poll');
  }
}
