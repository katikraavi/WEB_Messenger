import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';
import '../models/user_model.dart';

/// UserService handles user CRUD operations and authentication
class UserService {
  /// Create a new user with email and password
  static User createUser({
    required String id,
    required String email,
    required String username,
    required String plainPassword,
  }) {
    final passwordHash = _hashPassword(plainPassword);
    return User(
      id: id,
      email: email,
      username: username,
      passwordHash: passwordHash,
      emailVerified: false,
      createdAt: DateTime.now(),
    );
  }

  /// Verify a password against stored hash
  static bool verifyPassword(String plainPassword, String storedHash) {
    return _hashPassword(plainPassword) == storedHash;
  }

  /// Hash a password using SHA256
  static String _hashPassword(String password) {
    return crypto.sha256.convert(utf8.encode(password)).toString();
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  /// Validate username format (3-20 chars, alphanumeric + underscore)
  static bool isValidUsername(String username) {
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
    return usernameRegex.hasMatch(username);
  }

  /// Validate password strength (min 8 chars, one uppercase, one number)
  static bool isStrongPassword(String password) {
    final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasMinLength = password.length >= 8;
    return hasUpperCase && hasNumber && hasMinLength;
  }

  /// Update user profile information
  static User updateProfile({
    required User user,
    String? email,
    String? profilePictureUrl,
    String? aboutMe,
  }) {
    return user.copyWith(
      email: email,
      profilePictureUrl: profilePictureUrl,
      aboutMe: aboutMe,
    );
  }

  /// Mark email as verified
  static User verifyEmail(User user) {
    return user.copyWith(emailVerified: true);
  }
}
