part of '../../server.dart';


/// Database connection health check middleware
/// Ensures connection is alive before processing requests
/// Attempts automatic recovery on connection failure
Middleware _databaseHealthCheck(PostgreSQLConnection dbConnection) {
  return (Handler innerHandler) {
    return (Request request) async {
      final path = request.url.path;
      
      // Skip health check for /health endpoint to prevent infinite loops
      if (path == '/health' || path == 'health') {
        return await innerHandler(request);
      }

      // Ensure connection is healthy before processing request
      try {
        final monitor = dbConnection.getHealthMonitor();
        if (monitor != null) {
          final isHealthy = await monitor.ensureConnectionHealthy();
          if (!isHealthy) {
            return Response(
              503, // Service Unavailable
              body: jsonEncode({
                'error': 'Database connection temporarily unavailable',
                'details': 'Server cannot process requests - database offline',
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }
      } catch (e) {
        print('[ERROR] Health check failed: $e');
        return Response(
          503, // Service Unavailable
          body: jsonEncode({
            'error': 'Connection health check failed',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return await innerHandler(request);
    };
  };
}

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
            'Access-Control-Allow-Methods':
                'GET, POST, PUT, PATCH, DELETE, OPTIONS',
            'Access-Control-Allow-Headers':
                'Content-Type, Authorization, X-Device-ID',
            // Chrome Private Network Access (CORS-RFC1918): required when a
            // web page on one localhost port calls a different localhost port.
            'Access-Control-Allow-Private-Network': 'true',
          },
        );
      }

      try {
        final response = await innerHandler(request);
        // Try to apply CORS headers, but skip if the response is from a hijacked request
        try {
          return response.change(
            headers: {
              ...response.headers,
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods':
                  'GET, POST, PUT, PATCH, DELETE, OPTIONS',
              'Access-Control-Allow-Headers':
                  'Content-Type, Authorization, X-Device-ID',
              'Access-Control-Allow-Private-Network': 'true',
            },
          );
        } catch (e) {
          // If response.change() fails (e.g., hijacked request), return as-is
          return response;
        }
      } catch (e) {
        // If the inner handler throws (e.g., hijacked request), re-throw
        rethrow;
      }
    };
  };
}

/// Handle POST /auth/register
