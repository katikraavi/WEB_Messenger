part of '../../server.dart';


/// Logging middleware that skips health checks to reduce log noise
Middleware _logRequestsExceptHealth() {
  return (Handler innerHandler) {
    return (Request request) async {
      final path = request.url.path;
      // Skip logging for health checks
      if (path == '/health' || path == 'health') {
        return await innerHandler(request);
      }
      // Log other requests
      return await logRequests()(innerHandler)(request);
    };
  };
}

/// CORS middleware
Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok(
          '',
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          },
        );
      }

      final response = await innerHandler(request);
      return response.change(
        headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    };
  };
}

/// Handle POST /auth/register
