import 'package:postgres/postgres.dart';
import 'token_service.dart';

// Alias for cleaner code
typedef Connection = PostgreSQLConnection;

/// Service for managing password reset tokens and password resets
class PasswordResetService {
  final Connection connection;
  final TokenService tokenService;

  PasswordResetService({
    required this.connection,
    required this.tokenService,
  });

  /// Create a new password reset token for a user
  /// Returns the plaintext token (to be sent in email)
  Future<String> createResetToken(String userId) async {
    try {
      // Generate a new token
      final token = await tokenService.generateToken();
      final tokenHash = await tokenService.hashToken(token);
      
      // Calculate expiration (24 hours from now)
      final expiresAt = DateTime.now().add(Duration(hours: 24)).toUtc();
      
      // Invalidate any existing reset tokens for this user
      await connection.execute(
        'UPDATE password_reset_token SET used_at = CURRENT_TIMESTAMP WHERE user_id = @id AND used_at IS NULL',
        substitutionValues: {'id': userId},
      );
      
      // Insert new token
      await connection.execute(
        '''INSERT INTO password_reset_token (user_id, token_hash, expires_at)
           VALUES (@user_id, @token_hash, @expires_at)''',
        substitutionValues: {'user_id': userId, 'token_hash': tokenHash, 'expires_at': expiresAt},
      );
      
      return token;
    } catch (e) {
      throw PasswordResetException('Failed to create reset token: $e');
    }
  }

  /// Verify a reset token and check if valid
  /// Returns userId if valid, null if invalid/expired
  Future<String?> verifyResetToken(String token) async {
    try {
      final tokenHash = await tokenService.hashToken(token);
      
      // Find the token
      final result = await connection.query(
        '''SELECT user_id, expires_at, used_at FROM password_reset_token 
           WHERE token_hash = @hash''',
        substitutionValues: {'hash': tokenHash},
      );
      
      if (result.isEmpty) {
        return null; // Token not found
      }
      
      final row = result.first.toColumnMap();
      final expiresAt = row['expires_at'] as DateTime;
      final usedAt = row['used_at'];
      final userId = row['user_id'] as String;
      
      // Check if token is expired
      if (DateTime.now().toUtc().isAfter(expiresAt)) {
        return null; // Token expired
      }
      
      // Check if token already used
      if (usedAt != null) {
        return null; // Token already used
      }
      
      return userId;
    } catch (e) {
      throw PasswordResetException('Failed to verify reset token: $e');
    }
  }

  /// Reset a user's password with a token
  /// Returns true if successful, false if token invalid
  Future<bool> resetPassword(String token, String newPasswordHash) async {
    try {
      final tokenHash = await tokenService.hashToken(token);
      
      // Find the token
      final result = await connection.query(
        '''SELECT user_id, expires_at, used_at FROM password_reset_token 
           WHERE token_hash = @hash''',
        substitutionValues: {'hash': tokenHash},
      );
      
      if (result.isEmpty) {
        return false; // Token not found
      }
      
      final row = result.first.toColumnMap();
      final expiresAt = row['expires_at'] as DateTime;
      final usedAt = row['used_at'];
      final userId = row['user_id'] as String;
      
      // Check if token is expired
      if (DateTime.now().toUtc().isAfter(expiresAt)) {
        return false; // Token expired
      }
      
      // Check if token already used
      if (usedAt != null) {
        return false; // Token already used
      }
      
      // Mark token as used
      await connection.execute(
        '''UPDATE password_reset_token SET used_at = CURRENT_TIMESTAMP 
           WHERE token_hash = @hash''',
        substitutionValues: {'hash': tokenHash},
      );
      
      // Update user password and last_password_changed
      await connection.execute(
        '''UPDATE "users" SET password_hash = @hash, last_password_changed = CURRENT_TIMESTAMP 
           WHERE id = @id''',
        substitutionValues: {'hash': newPasswordHash, 'id': userId},
      );
      
      // Clear rate limit counter for this user (successful reset)
      await connection.execute(
        '''DELETE FROM password_reset_attempt WHERE user_id = @id''',
        substitutionValues: {'id': userId},
      );
      
      return true;
    } catch (e) {
      throw PasswordResetException('Failed to reset password: $e');
    }
  }

  /// Validate password strength
  /// Returns validation object with isValid flag and errors list
  PasswordResetValidation validatePassword(String password) {
    final errors = <String>[];
    
    if (password.isEmpty) {
      errors.add('Password is required');
    }
    
    if (password.length < 8) {
      errors.add('Password must be at least 8 characters');
    }
    
    if (password.length > 128) {
      errors.add('Password must not exceed 128 characters');
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Password must contain at least one uppercase letter');
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Password must contain at least one lowercase letter');
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Password must contain at least one digit');
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:",.<>?/\\|`~]'))) {
      errors.add('Password must contain at least one special character');
    }
    
    return PasswordResetValidation(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Clean up expired tokens (maintenance)
  Future<int> cleanupExpiredTokens() async {
    try {
      final result = await connection.execute(
        '''DELETE FROM password_reset_token 
           WHERE expires_at < CURRENT_TIMESTAMP AND used_at IS NULL''',
      );
      
      return result; // Number of rows deleted
    } catch (e) {
      throw PasswordResetException('Failed to cleanup tokens: $e');
    }
  }

  /// Clean up attempts older than 24 hours
  Future<int> cleanupOldAttempts() async {
    try {
      final result = await connection.execute(
        '''DELETE FROM password_reset_attempt 
           WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '24 hours' ''',
      );
      
      return result; // Number of rows deleted
    } catch (e) {
      throw PasswordResetException('Failed to cleanup attempts: $e');
    }
  }
}

/// Password validation result
class PasswordResetValidation {
  final bool isValid;
  final List<String> errors;

  PasswordResetValidation({
    required this.isValid,
    required this.errors,
  });

  Map<String, dynamic> toJson() => {
    'is_valid': isValid,
    'errors': errors,
  };
}

/// Exception for password reset-related errors
class PasswordResetException implements Exception {
  final String message;
  
  PasswordResetException(this.message);
  
  @override
  String toString() => 'PasswordResetException: $message';
}
