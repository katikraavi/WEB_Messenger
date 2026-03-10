import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'src/endpoints/health.dart';

void main() async {
  final databaseUrl = Platform.environment['DATABASE_URL'] ??
      'postgres://messenger_user:messenger_password@localhost:5432/messenger_db';
  final port = int.parse(Platform.environment['SERVERPOD_PORT'] ?? '8081');

  // Handler that routes requests to appropriate endpoints
  final handler = (Request request) async {
    // Route health check endpoint
    if (request.url.path == 'health' && request.method == 'GET') {
      final healthData = HealthEndpoint.getHealth();
      return Response.ok(
        _jsonEncode(healthData),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Route other endpoints as needed
    return Response.notFound('Endpoint not found');
  };

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('Serverpod started on port ${server.port}');
  print('[INFO] Health check endpoint available at http://localhost:${server.port}/health');
}

/// Simple JSON encoder (without external dependencies)
String _jsonEncode(Map<String, dynamic> data) {
  final entries = <String>[];
  data.forEach((key, value) {
    String encodedValue;
    if (value is String) {
      encodedValue = '"${value.replaceAll('"', '\\"')}"';
    } else if (value is int) {
      encodedValue = value.toString();
    } else if (value is bool) {
      encodedValue = value.toString();
    } else {
      encodedValue = 'null';
    }
    entries.add('"$key":$encodedValue');
  });
  return '{${entries.join(',')}}';
}
