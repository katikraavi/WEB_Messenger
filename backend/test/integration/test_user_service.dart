import 'package:test/test.dart';
import '../../lib/src/models/enums.dart';
import '../../lib/src/services/user_service.dart';

void main() {
  group('UserService', () {
    test('isValidEmail accepts valid emails', () {
      expect(UserService.isValidEmail('test@example.com'), true);
      expect(UserService.isValidEmail('user.name@domain.co.uk'), true);
    });

    test('isValidEmail rejects invalid emails', () {
      expect(UserService.isValidEmail('invalid'), false);
      expect(UserService.isValidEmail('@example.com'), false);
      expect(UserService.isValidEmail('test@'), false);
    });

    test('isValidUsername accepts valid usernames', () {
      expect(UserService.isValidUsername('john_doe'), true);
      expect(UserService.isValidUsername('user123'), true);
      expect(UserService.isValidUsername('abc'), true);
    });

    test('isValidUsername rejects invalid usernames', () {
      expect(UserService.isValidUsername('ab'), false); // too short
      expect(UserService.isValidUsername('user@name'), false); // invalid char
      expect(UserService.isValidUsername('a' * 21), false); // too long
    });

    test('isStrongPassword accepts strong passwords', () {
      expect(UserService.isStrongPassword('Password123'), true);
      expect(UserService.isStrongPassword('MySecure1Pass'), true);
    });

    test('isStrongPassword rejects weak passwords', () {
      expect(UserService.isStrongPassword('password123'), false); // no uppercase
      expect(UserService.isStrongPassword('PASSWORD'), false); // no number
      expect(UserService.isStrongPassword('Pass1'), false); // too short
    });

    test('createUser generates password hash', () {
      final user = UserService.createUser(
        id: 'user-1',
        email: 'test@example.com',
        username: 'testuser',
        plainPassword: 'Password123',
      );

      expect(user.passwordHash, isNotEmpty);
      expect(user.passwordHash, isNot('Password123'));
    });

    test('verifyPassword validates correctly', () {
      const password = 'Password123';
      final user = UserService.createUser(
        id: 'user-1',
        email: 'test@example.com',
        username: 'testuser',
        plainPassword: password,
      );

      expect(UserService.verifyPassword(password, user.passwordHash), true);
      expect(UserService.verifyPassword('WrongPassword1', user.passwordHash), false);
    });

    test('updateProfile preserves user id and creation date', () {
      final user = UserService.createUser(
        id: 'user-1',
        email: 'test@example.com',
        username: 'testuser',
        plainPassword: 'Password123',
      );

      final updated = UserService.updateProfile(
        user: user,
        email: 'new@example.com',
        aboutMe: 'New bio',
      );

      expect(updated.id, user.id);
      expect(updated.createdAt, user.createdAt);
      expect(updated.email, 'new@example.com');
    });

    test('verifyEmail marks email as verified', () {
      final user = UserService.createUser(
        id: 'user-1',
        email: 'test@example.com',
        username: 'testuser',
        plainPassword: 'Password123',
      );

      final verified = UserService.verifyEmail(user);
      expect(verified.emailVerified, true);
    });
  });
}
