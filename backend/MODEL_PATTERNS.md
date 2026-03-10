# Backend Model Patterns

This document describes the patterns and conventions for creating data models in the backend.

## Model Structure

All models are located in `backend/lib/src/models/` and follow a consistent pattern:

```dart
/// User model representing a user in the system
/// 
/// Organization:
/// - Layer 1 (Shared): All core user fields
/// - Layer 2 (Backend-only): Encrypted sensitive fields and internal state
class UserModel {
  // Core fields (Layer 1: Shared - can be sent to frontend)
  final String userId;
  final String username;
  final String email;
  final DateTime createdAt;

  // Backend-only fields (Layer 2: Backend-only)
  // Note: These are NOT sent to frontend for security
  final String encryptedPasswordHash;  // Follows naming pattern
  final String encryptedPhoneNumber;   // Encryption policy: see data-model.md
  final DateTime lastLoginAt;

  // Internal state (Layer 3: Backend-only)
  final bool isActive;
  final String role; // admin, user, moderator, etc.

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.createdAt,
    required this.encryptedPasswordHash,
    required this.encryptedPhoneNumber,
    required this.lastLoginAt,
    required this.isActive,
    required this.role,
  });

  /// Convert to JSON (excludes sensitive data)
  /// This is what gets sent to the frontend
  Map<String, dynamic> toPublicJson() => {
    'userId': userId,
    'username': username,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
    'lastLoginAt': lastLoginAt.toIso8601String(),
    'isActive': isActive,
  };

  /// Convert to JSON (includes all data)
  /// This is used for internal persistence and backend-to-backend communication
  Map<String, dynamic> toBakendJson() => {
    'userId': userId,
    'username': username,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
    'encryptedPasswordHash': encryptedPasswordHash,
    'encryptedPhoneNumber': encryptedPhoneNumber,
    'lastLoginAt': lastLoginAt.toIso8601String(),
    'isActive': isActive,
    'role': role,
  };

  /// Create from JSON (backend persistence)
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    userId: json['userId'],
    username: json['username'],
    email: json['email'],
    createdAt: DateTime.parse(json['createdAt']),
    encryptedPasswordHash: json['encryptedPasswordHash'],
    encryptedPhoneNumber: json['encryptedPhoneNumber'],
    lastLoginAt: DateTime.parse(json['lastLoginAt']),
    isActive: json['isActive'],
    role: json['role'],
  );
}
```

## Naming Conventions

### File Naming
- Use `snake_case`: `user_model.dart`, `message_model.dart`
- Pattern: `[domain]_model.dart`

### Class Naming
- Use `PascalCase`: `UserModel`, `MessageModel`
- Pattern: `[Domain]Model`

### Field Naming
- Use `camelCase`: `userId`, `createdAt`, `isActive`
- Private fields: `_internalField`

### Encrypted Field Naming
Per Constitution I (Security-First), encrypted fields follow a specific pattern:

- Prefix with `encrypted`: `encryptedPasswordHash`, `encryptedPhoneNumber`
- This makes encryption status explicit in code
- See [Data Model Documentation](../data-model.md) for encryption policy

## Layer Organization

Models follow a 4-layer organization:

| Layer | Location | Purpose | Example |
|-------|----------|---------|---------|
| Layer 1 | Shared (frontend + backend) | Read-only user data | userId, username, email |
| Layer 2 | Backend-only | Sensitive data | encryptedPasswordHash |
| Layer 3 | Backend-only | Business logic state | isActive role |
| Layer 4 | Configuration | Schema metadata | Not in model class |

## Encryption Policy

All sensitive data must be encrypted:

```dart
class UserModel {
  /// Sensitive fields MUST be prefixed with 'encrypted'
  final String encryptedPasswordHash;
  final String encryptedPhoneNumber;
  final String encryptedSSN;  // Social Security Number
  
  /// Non-sensitive fields (no encryption prefix needed)
  final String email;  // Not encrypted (public identifier)
  final String username;  // Not encrypted (public identifier)
}
```

## Type Safety and Validation

All models should validate data:

```dart
class MessageModel {
  final String messageId;
  final String content;
  final DateTime timestamp;

  MessageModel({
    required this.messageId,
    required this.content,
    required this.timestamp,
  }) {
    // Validation in constructor
    if (messageId.isEmpty) throw ArgumentError('messageId cannot be empty');
    if (content.isEmpty) throw ArgumentError('content cannot be empty');
    if (content.length > 10000) throw ArgumentError('content too long');
  }

  factory MessageModel.parse(String json) {
    final data = jsonDecode(json); // Will throw if invalid JSON
    return MessageModel(
      messageId: data['messageId'] as String,
      content: data['content'] as String,
      timestamp: DateTime.parse(data['timestamp'] as String),
    );
  }
}
```

## Example Models

### User Model (from Constitution I)
```dart
class UserModel {
  final String userId;
  final String username;
  final String email;
  final String encryptedPasswordHash;
  final String encryptedPhoneNumber;
}
```

### Message Model
```dart
class MessageModel {
  final String messageId;
  final String senderUserId;
  final String conversationId;
  final String content;
  final DateTime timestamp;
}
```

### Conversation Model
```dart
class ConversationModel {
  final String conversationId;
  final List<String> participantIds;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
}
```

## Testing

Create tests in `test/models/your_model_test.dart`:

```dart
void main() {
  group('UserModel', () {
    test('creates user with valid data', () {
      final user = UserModel(
        userId: '123',
        username: 'john_doe',
        email: 'john@example.com',
        // ...
      );
      expect(user.userId, equals('123'));
    });

    test('throws on invalid email', () {
      expect(
        () => UserModel(email: 'invalid-email'),
        throwsArgumentError,
      );
    });
  });
}
```

## Related Documentation

- [Data Model Architecture](../data-model.md) - Detailed data organization
- [Service Patterns](SERVICE_PATTERNS.md) - How services use models
- [Endpoint Patterns](ENDPOINT_PATTERNS.md) - How endpoints expose models
