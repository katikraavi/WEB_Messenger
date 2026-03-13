import 'package:shelf/shelf.dart';
import 'dart:convert';
import '../services/search_service.dart';
import '../models/search_query.dart';
import '../services/token_service.dart';

/// Search endpoints for user search functionality
Future<Response> handleSearchByUsername(
  Request request,
  SearchService searchService,
) async {
  try {
    // Extract and validate auth token
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.forbidden(
        jsonEncode({'error': 'Missing or invalid authorization header'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Get query parameter
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required query parameter: q'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Get optional limit parameter
    int limit = 10;
    if (request.url.queryParameters['limit'] != null) {
      try {
        limit = int.parse(request.url.queryParameters['limit']!);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid limit parameter: must be an integer'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    final results = await searchService.searchByUsername(query, limit);

    return Response.ok(
      jsonEncode({
        'data': results.map((r) => r.toJson()).toList(),
        'count': results.length,
        'query': query,
        'type': 'username',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    // Check if it's a validation error
    if (e.toString().contains('SearchValidationException')) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString().split(': ').last}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    print('[ERROR] Search by username error: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Search users by email
Future<Response> handleSearchByEmail(
  Request request,
  SearchService searchService,
) async {
  try {
    // Extract and validate auth token
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.forbidden(
        jsonEncode({'error': 'Missing or invalid authorization header'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Get query parameter
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required query parameter: q'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Get optional limit parameter
    int limit = 10;
    if (request.url.queryParameters['limit'] != null) {
      try {
        limit = int.parse(request.url.queryParameters['limit']!);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid limit parameter: must be an integer'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    final results = await searchService.searchByEmail(query, limit);

    return Response.ok(
      jsonEncode({
        'data': results.map((r) => r.toJson()).toList(),
        'count': results.length,
        'query': query,
        'type': 'email',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    // Check if it's a validation error
    if (e.toString().contains('SearchValidationException')) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString().split(': ').last}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    print('[ERROR] Search by email error: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
