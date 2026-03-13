import 'package:test/test.dart';
import '../../lib/src/models/user_model.dart';

void main() {
  group('User Model', () {
    test('User creation with valid data', () {
      final user = User(
        id: 'user-123',
        email: 'test@example.com',
        username: 'testuser',
        passwordHash: 'hashed_password',
        emailVerified: false,
        createdAt: DateTime.now(),
      );

      expect(user.id, 'user-123');
      expect(user.email, 'test@example.com');
      expect(user.username, 'testuser');
      expect(user.emailVerified, false);
    });

    test('User toJson includes all fields', () {
      final user = User(
        id: 'user-123',
        email: 'test@example.com',
        username: 'testuser',
        passwordHash: 'hashed_password',
        emailVerified: true,
        profilePictureUrl: 'https://example.com/pic.jpg',
        aboutMe: 'Hello world',
        createdAt: DateTime.now(),
      );

      final json = user.toJson();
      expect(json['id'], 'user-123');
      expect(json['email'], 'test@example.com');
      expect(json['username'], 'testuser');
      expect(json['email_verified'], true);
      expect(json['profile_picture_url'], 'https://example.com/pic.jpg');
    });

    test('User fromJson deserializes correctly', () {
      final now = DateTime.now();
      final json = {
        'id': 'user-123',
        'email': 'test@example.com',
        'username': 'testuser',
        'password_hash': 'hashed_password',
        'email_verified': false,
        'profile_picture_url': null,
        'about_me': null,
        'created_at': now.toIso8601String(),
      };

      final user = User.fromJson(json);
      expect(user.id, 'user-123');
      expect(user.email, 'test@example.com');
    });

    test('User copyWith creates new instance with updates', () {
      final user = User(
        id: 'user-123',
        email: 'old@example.com',
        username: 'testuser',
        passwordHash: 'hashed_password',
        emailVerified: false,
        createdAt: DateTime.now(),
      );

      final updated = user.copyWith(
        email: 'new@example.com',
        aboutMe: 'New bio',
      );

      expect(updated.id, user.id);
      expect(updated.email, 'new@example.com');
      expect(updated.aboutMe, 'New bio');
      expect(user.email, 'old@example.com'); // Original unchanged
    });

    test('User toString returns expected format', () {
      final user = User(
        id: 'user-123',
        email: 'test@example.com',
        username: 'testuser',
        passwordHash: 'hashed_password',
        emailVerified: false,
        createdAt: DateTime.now(),
      );

      final str = user.toString();
      expect(str, contains('user-123'));
      expect(str, contains('test@example.com'));
    });
  });
}
