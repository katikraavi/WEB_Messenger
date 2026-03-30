import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:cryptography/cryptography.dart';
import 'package:postgres/postgres.dart';

import '../models/device_session.dart';

typedef Connection = PostgreSQLConnection;

/// TokenService generates, hashes, and verifies cryptographically secure tokens
/// 
/// Security approach:
/// - Tokens: 32-byte (256-bit) random data, Base64URL encoded
/// - Storage: Never stored plaintext; SHA256 hash stored in database
/// - Verification: Timing-safe comparison prevents timing attacks
class TokenService {
  static const int TOKEN_BYTE_LENGTH = 32; // 256-bit entropy
  static const int TOKEN_LENGTH_BASE64 = 43; // Base64URL encoded length

  final String _sessionHashSecret;

  TokenService({String? sessionHashSecret})
      : _sessionHashSecret = sessionHashSecret ?? 'device-session-hmac-secret';

  static const String _deviceIdHeader = 'x-device-id';
  static const String _userAgentHeader = 'user-agent';
  static const String _acceptLanguageHeader = 'accept-language';

  /// Generate a new cryptographically secure token
  /// 
  /// Returns a Base64URL-encoded token (approximately 43 characters)
  /// Example: "nV7Zq1_pK2mX8bYc3dEfGhIjKlMnOpQrStUvWxYzAbCdEfGhIjKlMnOp"
  Future<String> generateToken() async {
    // Generate 32 bytes (256 bits) of cryptographically secure random data
    final random = Random.secure();
    final values = List<int>.generate(TOKEN_BYTE_LENGTH, (i) => random.nextInt(256));
    
    // Use Base64URL encoding (URL-safe without padding)
    return base64Url.encode(values).replaceAll('=', '');
  }

  /// Hash a token using SHA256 for secure storage
  /// 
  /// Never store tokens plaintext in database. Always hash before storage.
  /// Example: token "abc123" → hash "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  Future<String> hashToken(String token) async {
    final sha256 = Sha256();
    final digest = await sha256.hash(utf8.encode(token));
    
    // Convert bytes to hex string
    return digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Verify token against stored hash using timing-safe comparison
  /// 
  /// This prevents timing attacks where an attacker could learn parts of the
  /// token by measuring response time differences.
  /// 
  /// Returns true only if token hashes match the stored hash.
  Future<bool> verifyTokenHash(String token, String storedHash) async {
    try {
      final computedHash = await hashToken(token);
      
      // Timing-safe comparison: always check all bytes regardless of match
      // This prevents timing attacks from revealing token validity
      return _timingSafeEquals(computedHash, storedHash);
    } catch (e) {
      return false;
    }
  }

  /// Compare two strings in constant time to prevent timing attacks
  /// 
  /// Standard string comparison (==) can leak information via timing:
  /// - First char mismatch: fast
  /// - Last char mismatch: slow
  /// 
  /// This checks ALL characters regardless of match result.
  bool _timingSafeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Validate token format (should be Base64URL, ~43 chars)
  bool isValidTokenFormat(String token) {
    if (token.length != TOKEN_LENGTH_BASE64) {
      return false;
    }
    
    // Check if it's valid Base64URL (alphanumeric, -, _, no padding =)
    final base64UrlRegex = RegExp(r'^[A-Za-z0-9_-]+$');
    return base64UrlRegex.hasMatch(token);
  }

  /// Validate token hash format (SHA256 hex = 64 characters)
  bool isValidHashFormat(String hash) {
    if (hash.length != 64) {
      return false;
    }
    
    // Check if it's valid hex (0-9, a-f)
    final hexRegex = RegExp(r'^[a-f0-9]+$');
    return hexRegex.hasMatch(hash);
  }

  /// Extracts a device id from request headers.
  ///
  /// Priority:
  /// 1) Use `X-Device-ID` if present and valid.
  /// 2) Otherwise derive a deterministic UUID-like value from stable headers
  ///    (`User-Agent` + `Accept-Language`) so the same client fingerprint
  ///    yields the same value when possible.
  Future<String> extractOrGenerateDeviceId(Map<String, String> headers) async {
    final normalizedHeaders = <String, String>{};
    for (final entry in headers.entries) {
      normalizedHeaders[entry.key.toLowerCase()] = entry.value;
    }

    final headerDeviceId = normalizedHeaders[_deviceIdHeader]?.trim();
    if (headerDeviceId != null && _isValidUuidLike(headerDeviceId)) {
      return headerDeviceId;
    }

    final userAgent = normalizedHeaders[_userAgentHeader]?.trim() ?? '';
    final acceptLanguage = normalizedHeaders[_acceptLanguageHeader]?.trim() ?? '';
    final fingerprint = '$userAgent|$acceptLanguage';

    if (fingerprint == '|') {
      return _generateRandomUuidLike();
    }

    return _generateStableUuidLike(fingerprint);
  }

  /// Generates a human-readable device label from request headers.
  String inferDeviceName(Map<String, String> headers) {
    final normalizedHeaders = <String, String>{};
    for (final entry in headers.entries) {
      normalizedHeaders[entry.key.toLowerCase()] = entry.value;
    }

    final userAgent = normalizedHeaders[_userAgentHeader]?.trim();
    if (userAgent == null || userAgent.isEmpty) {
      return 'Unknown device';
    }

    if (userAgent.contains('Chrome')) return 'Chrome';
    if (userAgent.contains('Firefox')) return 'Firefox';
    if (userAgent.contains('Safari') && !userAgent.contains('Chrome')) {
      return 'Safari';
    }
    if (userAgent.contains('Edg')) return 'Edge';
    return userAgent.length > 80 ? userAgent.substring(0, 80) : userAgent;
  }

  /// Stores or refreshes a per-device session row using an HMAC-SHA256 token hash.
  Future<DeviceSession> createDeviceSession({
    required Connection connection,
    required String userId,
    required String deviceId,
    String? deviceName,
    required String refreshToken,
  }) async {
    final now = DateTime.now().toUtc();
    final tokenHash = await _hashRefreshTokenForSession(refreshToken);

    await connection.execute(
      '''INSERT INTO device_sessions (
           id, user_id, device_id, device_name, token_hash, created_at, last_seen_at
         ) VALUES (
           @id, @user_id, @device_id, @device_name, @token_hash, @created_at, @last_seen_at
         )
         ON CONFLICT (user_id, device_id) DO UPDATE SET
           device_name = EXCLUDED.device_name,
           token_hash = EXCLUDED.token_hash,
           last_seen_at = EXCLUDED.last_seen_at''',
      substitutionValues: {
        'id': _generateRandomUuidLike(),
        'user_id': userId,
        'device_id': deviceId,
        'device_name': deviceName,
        'token_hash': tokenHash,
        'created_at': now,
        'last_seen_at': now,
      },
    );

    final sessions = await listDeviceSessions(
      connection: connection,
      userId: userId,
    );

    return sessions.firstWhere(
      (session) => session.deviceId == deviceId,
      orElse: () => DeviceSession(
        id: _generateRandomUuidLike(),
        userId: userId,
        deviceId: deviceId,
        deviceName: deviceName,
        tokenHash: tokenHash,
        createdAt: now,
        lastSeenAt: now,
      ),
    );
  }

  Future<void> revokeDeviceSession({
    required Connection connection,
    required String userId,
    required String deviceId,
  }) async {
    await connection.execute(
      '''DELETE FROM device_sessions
         WHERE user_id = @user_id AND device_id = @device_id''',
      substitutionValues: {
        'user_id': userId,
        'device_id': deviceId,
      },
    );
  }

  Future<void> revokeAllDeviceSessions({
    required Connection connection,
    required String userId,
  }) async {
    await connection.execute(
      '''DELETE FROM device_sessions
         WHERE user_id = @user_id''',
      substitutionValues: {
        'user_id': userId,
      },
    );
  }

  Future<bool> hasActiveDeviceSessionForToken({
    required Connection connection,
    required String userId,
    required String token,
  }) async {
    final tokenHash = await _hashRefreshTokenForSession(token);
    final result = await connection.query(
      '''SELECT 1
         FROM device_sessions
         WHERE user_id = @user_id AND token_hash = @token_hash
         LIMIT 1''',
      substitutionValues: {
        'user_id': userId,
        'token_hash': tokenHash,
      },
    );

    return result.isNotEmpty;
  }

  Future<List<DeviceSession>> listDeviceSessions({
    required Connection connection,
    required String userId,
  }) async {
    final result = await connection.query(
      '''SELECT id, user_id, device_id, device_name, token_hash, created_at, last_seen_at
         FROM device_sessions
         WHERE user_id = @user_id
         ORDER BY last_seen_at DESC''',
      substitutionValues: {
        'user_id': userId,
      },
    );

    return result
        .map((row) => DeviceSession.fromMap({
              'id': row[0],
              'user_id': row[1],
              'device_id': row[2],
              'device_name': row[3],
              'token_hash': row[4],
              'created_at': row[5],
              'last_seen_at': row[6],
            }))
        .toList();
  }

  Future<String> _hashRefreshTokenForSession(String refreshToken) async {
    final hmac = Hmac(Sha256());
    final mac = await hmac.calculateMac(
      utf8.encode(refreshToken),
      secretKey: SecretKey(utf8.encode(_sessionHashSecret)),
    );

    return mac.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  bool _isValidUuidLike(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[1-5][0-9a-fA-F]{3}\-[89abAB][0-9a-fA-F]{3}\-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(value);
  }

  Future<String> _generateStableUuidLike(String seed) async {
    final sha256 = Sha256();
    final digest = await sha256.hash(utf8.encode(seed));
    final bytes = List<int>.from(digest.bytes.take(16));

    // Set version (5) and variant (RFC4122) bits.
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    return _formatUuid(bytes);
  }

  String _generateRandomUuidLike() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version (4) and variant (RFC4122) bits.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    return _formatUuid(bytes);
  }

  String _formatUuid(List<int> bytes) {
    String hexByte(int b) => b.toRadixString(16).padLeft(2, '0');
    final hex = bytes.map(hexByte).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
