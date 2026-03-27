import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../services/poll_service.dart';
import '../services/jwt_service.dart';

/// Poll endpoints for group-chat poll creation, voting, and results.
///
/// Route contract (matches frontend [poll_service.dart]):
///   POST   /api/polls                     — create poll
///   GET    /api/polls/<pollId>            — fetch poll with results
///   POST   /api/polls/<pollId>/vote       — cast/change a vote
///   POST   /api/polls/<pollId>/close      — close a poll (creator only)
class PollEndpoints {
  final PollService _pollService;
  final JwtService _jwtService;

  PollEndpoints({
    required PollService pollService,
    required JwtService jwtService,
  })  : _pollService = pollService,
        _jwtService = jwtService;

  Router get router {
    final r = Router();
    r.post('/api/polls', _createPoll);
    r.get('/api/polls/<pollId>', _getPoll);
    r.post('/api/polls/<pollId>/vote', _vote);
    r.post('/api/polls/<pollId>/close', _closePoll);
    return r;
  }

  Future<Response> _createPoll(Request request) async {
    final userId = _extractUserId(request);
    if (userId == null) {
      return Response.unauthorized(
        jsonEncode({'error': 'Unauthorized'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final groupId = body['groupId'] as String?;
      final question = body['question'] as String?;
      final options = (body['options'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList();
      final isAnonymous = (body['isAnonymous'] as bool?) ?? false;
      final closesAtRaw = body['closesAt'] as String?;
      final closesAt = closesAtRaw != null ? DateTime.parse(closesAtRaw) : null;

      if (groupId == null || question == null || options == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'groupId, question, and options are required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final poll = await _pollService.createPoll(
        groupId: groupId,
        creatorUserId: userId,
        question: question,
        optionTexts: options,
        isAnonymous: isAnonymous,
        closesAt: closesAt,
      );

      return Response.ok(
        jsonEncode(poll.toMap()..['createdAt'] = poll.createdAt.toIso8601String()),
        headers: {'Content-Type': 'application/json'},
      );
    } on ArgumentError catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.message}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to create poll'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _getPoll(Request request, String pollId) async {
    final userId = _extractUserId(request);
    if (userId == null) {
      return Response.unauthorized(
        jsonEncode({'error': 'Unauthorized'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final result = await _pollService.getPollWithResults(
        pollId: pollId,
        requestingUserId: userId,
      );
      return Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    } on StateError catch (e) {
      return Response.notFound(
        jsonEncode({'error': e.message}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch poll'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _vote(Request request, String pollId) async {
    final userId = _extractUserId(request);
    if (userId == null) {
      return Response.unauthorized(
        jsonEncode({'error': 'Unauthorized'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final optionId = body['optionId'] as String?;

      if (optionId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'optionId is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await _pollService.vote(
        pollId: pollId,
        optionId: optionId,
        userId: userId,
      );

      return Response.ok(
        jsonEncode({'message': 'Vote recorded'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on StateError catch (e) {
      return Response(409,
          body: jsonEncode({'error': e.message}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to record vote'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _closePoll(Request request, String pollId) async {
    final userId = _extractUserId(request);
    if (userId == null) {
      return Response.unauthorized(
        jsonEncode({'error': 'Unauthorized'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      await _pollService.closePoll(
        pollId: pollId,
        requestingUserId: userId,
      );
      return Response.ok(
        jsonEncode({'message': 'Poll closed'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on StateError catch (e) {
      return Response(403,
          body: jsonEncode({'error': e.message}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to close poll'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Extract the authenticated user ID from the JWT in the Authorization header.
  String? _extractUserId(Request request) {
    final authHeader = request.headers['authorization'] ??
        request.headers['Authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;

    final token = authHeader.substring('Bearer '.length);
    try {
      final claims = _jwtService.verifyAndDecode(token);
      return claims['sub'] as String?;
    } catch (_) {
      return null;
    }
  }
}
