import 'package:postgres/postgres.dart';
import 'token_service.dart';

// Alias for cleaner code
typedef Connection = PostgreSQLConnection;

/// Service for managing email verification tokens and user verification status
class VerificationService {
  final Connection connection;
  final TokenService tokenService;

  VerificationService({
    required this.connection,
    required this.tokenService,
  });

  /// Create a new verification token for a user
  /// Returns the plaintext token (to be sent in email)
  Future<String> createVerificationToken(String userId) async {
    try {
      // Generate a new token
      final token = await tokenService.generateToken();
      final tokenHash = await tokenService.hashToken(token);
      
      // Calculate expiration (24 hours from now)
      final expiresAt = DateTime.now().add(Duration(hours: 24)).toUtc();
      
      // Invalidate any existing verification tokens for this user
      await connection.execute(
        'UPDATE verification_token SET used_at = CURRENT_TIMESTAMP WHERE user_id = @id AND used_at IS NULL',
        substitutionValues: {'id': userId},
      );
      
      // Insert new token
      await connection.execute(
        '''INSERT INTO verification_token (user_id, token_hash, expires_at)
           VALUES (@user_id, @token_hash, @expires_at)''',
        substitutionValues: {'user_id': userId, 'token_hash': tokenHash, 'expires_at': expiresAt},
      );
      
      return token;
    } catch (e) {
      throw VerificationException('Failed to create verification token: $e');
    }
  }

  /// Verify and consume a verification token
  /// Updates user.email_verified and marks token as used
  /// Returns true if verification successful, false if token invalid/expired
  Future<bool> verifyAndConsumeToken(String token) async {
    try {
      final tokenHash = await tokenService.hashToken(token);
      
      // Find the token
      final result = await connection.query(
        '''SELECT user_id, expires_at, used_at FROM verification_token 
           WHERE token_hash = @hash''',
        substitutionValues: {'hash': tokenHash},
      );
      
      if (result.isEmpty) {
        return false; // Token not found
      }
      
      final row = result.first;
      final expiresAt = row.toColumnMap()['expires_at'] as DateTime;
      final usedAt = row.toColumnMap()['used_at'];
      final userId = row.toColumnMap()['user_id'] as String;
      
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
        '''UPDATE verification_token SET used_at = CURRENT_TIMESTAMP 
           WHERE token_hash = @hash''',
        substitutionValues: {'hash': tokenHash},
      );
      
      // Update user verification status
      await connection.execute(
        '''UPDATE "users" SET email_verified = true, verified_at = CURRENT_TIMESTAMP 
           WHERE id = @id''',
        substitutionValues: {'id': userId},
      );
      
      return true;
    } catch (e) {
      throw VerificationException('Failed to verify token: $e');
    }
  }

  /// Get verification status for a user
  Future<VerificationStatus> getVerificationStatus(String userId) async {
    try {
      final result = await connection.query(
        '''SELECT email_verified, verified_at FROM "users" WHERE id = @id''',
        substitutionValues: {'id': userId},
      );
      
      if (result.isEmpty) {
        throw VerificationException('User not found');
      }
      
      final row = result.first.toColumnMap();
      final emailVerified = row['email_verified'] as bool;
      final verifiedAt = row['verified_at'] as DateTime?;
      
      return VerificationStatus(
        isVerified: emailVerified,
        verifiedAt: verifiedAt,
      );
    } catch (e) {
      throw VerificationException('Failed to get verification status: $e');
    }
  }

  /// Mark user as verified (admin/test purpose)
  Future<void> markUserVerified(String userId) async {
    try {
      await connection.execute(
        '''UPDATE "users" SET email_verified = true, verified_at = CURRENT_TIMESTAMP 
           WHERE id = @id''',
        substitutionValues: {'id': userId},
      );
    } catch (e) {
      throw VerificationException('Failed to mark user verified: $e');
    }
  }

  /// Clean up expired tokens (manual maintenance)
  Future<int> cleanupExpiredTokens() async {
    try {
      final result = await connection.execute(
        '''DELETE FROM verification_token 
           WHERE expires_at < CURRENT_TIMESTAMP AND used_at IS NULL''',
      );
      
      return result; // Number of rows deleted
    } catch (e) {
      throw VerificationException('Failed to cleanup tokens: $e');
    }
  }

  /// Check if user has pending verification (not yet verified)
  Future<bool> hasPendingVerification(String userId) async {
    try {
      final result = await connection.query(
        '''SELECT id FROM verification_token 
           WHERE user_id = @id AND used_at IS NULL AND expires_at > CURRENT_TIMESTAMP
           LIMIT 1''',
        substitutionValues: {'id': userId},
      );
      
      return result.isNotEmpty;
    } catch (e) {
      throw VerificationException('Failed to check pending verification: $e');
    }
  }
}

/// Verification status information
class VerificationStatus {
  final bool isVerified;
  final DateTime? verifiedAt;

  VerificationStatus({
    required this.isVerified,
    this.verifiedAt,
  });

  Map<String, dynamic> toJson() => {
    'is_verified': isVerified,
    'verified_at': verifiedAt?.toIso8601String(),
  };
}

/// Exception for verification-related errors
class VerificationException implements Exception {
  final String message;
  
  VerificationException(this.message);
  
  @override
  String toString() => 'VerificationException: $message';
}
