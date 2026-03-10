# Backend Service Patterns

This document describes the patterns and conventions for creating business logic services in the backend.

## Service Structure

All services are located in `backend/lib/src/services/` and follow a consistent pattern:

```dart
import '../models/your_model.dart';

/// YourFeatures Service
/// Contains business logic for YourFeatures operations
class YourFeaturesService {
  // Dependencies can be injected for testing
  final DatabaseConnection _db;

  YourFeaturesService({DatabaseConnection? db}) 
    : _db = db ?? DatabaseConnection();

  /// Get item by ID
  Future<YourModel> getItem(String id) async {
    try {
      // Access database or external services
      final result = await _db.query('SELECT * FROM your_table WHERE id = ?', [id]);
      if (result.isEmpty) {
        throw ServiceException('Item not found');
      }
      return YourModel.fromJson(result.first);
    } catch (e) {
      throw ServiceException('Failed to get item: $e');
    }
  }

  /// Create new item
  Future<YourModel> createItem(String data) async {
    try {
      // Validate data
      final model = YourModel.parse(data);
      
      // Persist to database
      await _db.insert('your_table', model.toJson());
      
      return model;
    } catch (e) {
      throw ServiceException('Failed to create item: $e');
    }
  }
}

/// Custom exception for service errors
class ServiceException implements Exception {
  final String message;
  ServiceException(this.message);

  @override
  String toString() => 'ServiceException: $message';
}
```

## Conventions

- **File naming**: `snake_case_service.dart` (e.g., `user_service.dart`)
- **Class naming**: `PascalCase + Service` (e.g., `UserService`)
- **Method naming**: `verbNoun` in camelCase (e.g., `getUser`, `createMessage`)
- **Error handling**: Throw `ServiceException` with descriptive messages
- **Dependency injection**: Accept optional dependencies in constructor
- **No business logic in endpoints**: All logic should be in services

## Data Access

Services should encapsulate all data access:

```dart
class UserService {
  /// Get user by username
  Future<User> getUserByUsername(String username) async {
    // Database query logic here
  }

  /// Update user profile
  Future<void> updateUserProfile(String userId, UserProfile profile) async {
    // Database update logic here
  }

  /// Delete user
  Future<void> deleteUser(String userId) async {
    // Database delete logic here
  }
}
```

## Security Patterns

For sensitive operations, implement additional security:

```dart
class SecureService {
  /// Encrypt sensitive data before persistence
  Future<void> storeSensitiveData(String userId, String data) async {
    final encryptedData = encryptData(data);
    await _db.insert('sensitive_table', {
      'user_id': userId,
      'encrypted_data': encryptedData,
    });
  }

  /// Decrypt data when retrieving
  Future<String> retrieveSensitiveData(String userId) async {
    final result = await _db.query(
      'SELECT encrypted_data FROM sensitive_table WHERE user_id = ?',
      [userId],
    );
    return decryptData(result['encrypted_data']);
  }
}
```

## Testing

Create tests in `test/services/your_service_test.dart`:

```dart
void main() {
  group('YourService', () {
    test('getItem returns correct item', () async {
      final service = YourService();
      final item = await service.getItem('123');
      expect(item.id, equals('123'));
    });
  });
}
```

## Naming Conventions Reference

| Aspect | Convention | Example |
|--------|-----------|---------|
| File | snake_case.dart | user_service.dart |
| Class | PascalCase | UserService |
| Method | camelCase | getUserByEmail() |
| Property | camelCase | userId |
| Constant | UPPER_CASE | DEFAULT_TIMEOUT |
| Exception | PascalCase + Exception | ServiceException |

See [Data Model Documentation](../data-model.md) for data organization patterns.
