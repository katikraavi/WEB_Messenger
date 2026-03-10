# Backend Endpoint Patterns

This document describes the patterns and conventions for creating new endpoints in the Serverpod backend.

## Endpoint Structure

All endpoints are located in `backend/lib/src/endpoints/` and follow a consistent pattern:

```dart
import 'package:shelf/shelf.dart';
import '../services/your_service.dart';

/// MyFeature endpoint
/// Handles requests for MyFeature functionality
class MyFeatureEndpoint {
  final YourService _service = YourService();

  /// GET /myfeature/:id
  Future<Response> getItem(Request request) async {
    try {
      final id = request.params['id'];
      final item = await _service.getItem(id);
      return Response.ok(jsonEncode(item));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  /// POST /myfeature
  Future<Response> createItem(Request request) async {
    try {
      final body = await request.readAsString();
      final item = await _service.createItem(body);
      return Response.ok(jsonEncode(item));
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }
}
```

## Registration

Register endpoints in `backend/lib/server.dart`:

```dart
// Import the endpoint
import 'src/endpoints/my_feature.dart';

// In main()
final myFeatureEndpoint = MyFeatureEndpoint();
final handler = (Request request) async {
  if (request.url.path.startsWith('myfeature')) {
    // Route to appropriate handler method
  }
  // ... more routing
};
```

## Conventions

- **File naming**: `snake_case.dart` (e.g., `user_endpoint.dart`)
- **Class naming**: `PascalCase + Endpoint` (e.g., `UserEndpoint`)
- **Method naming**: `verbNoun` in camelCase (e.g., `getUser`, `createMessage`)
- **Error handling**: Always wrap in try-catch and return appropriate HTTP status codes
- **Dependency injection**: Inject services in constructor for testability

## Example: Creating a GET endpoint

```dart
class UserEndpoint {
  Future<Response> getUser(Request request) async {
    try {
      final userId = request.params['userId'];
      final user = await userService.getUser(userId);
      return Response.ok(jsonEncode(user));
    } catch (e) {
      return Response.notFound(jsonEncode({'error': 'User not found'}));
    }
  }
}
```

## Testing

Create tests in `test/endpoints/my_feature_test.dart`:

```dart
void main() {
  group('MyFeatureEndpoint', () {
    test('GET /myfeature/:id returns item', () async {
      // Test implementation
    });
  });
}
```

See Serverpod documentation for more advanced patterns.
