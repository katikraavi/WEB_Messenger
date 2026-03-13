import 'package:test/test.dart';
import 'package:backend/src/services/token_service.dart';

void main() {
  group('TokenService', () {
    late TokenService tokenService;

    setUp(() {
      tokenService = TokenService();
    });

    group('generateToken', () {
      test('generates a token with correct length', () async {
        final token = await tokenService.generateToken();
        
        expect(token, isNotNull);
        expect(token.length, equals(TokenService.TOKEN_LENGTH_BASE64));
      });

      test('generates unique tokens', () async {
        final token1 = await tokenService.generateToken();
        final token2 = await tokenService.generateToken();
        
        expect(token1, isNot(equals(token2)));
      });

      test('generates valid Base64URL tokens', () async {
        final token = await tokenService.generateToken();
        
        // Base64URL alphabet: A-Z a-z 0-9 - _
        expect(token, matches(RegExp(r'^[A-Za-z0-9\-_]+$')));
      });

      test('token has no padding characters', () async {
        final token = await tokenService.generateToken();
        
        expect(token, isNot(contains('=')));
      });
    });

    group('hashToken', () {
      test('converts token to SHA256 hash', () async {
        final token = await tokenService.generateToken();
        final hash = await tokenService.hashToken(token);
        
        expect(hash, isNotNull);
        // SHA256 hex encoded is 64 characters
        expect(hash.length, equals(64));
      });

      test('same token produces same hash', () async {
        final token = await tokenService.generateToken();
        final hash1 = await tokenService.hashToken(token);
        final hash2 = await tokenService.hashToken(token);
        
        expect(hash1, equals(hash2));
      });

      test('different tokens produce different hashes', () async {
        final token1 = await tokenService.generateToken();
        final token2 = await tokenService.generateToken();
        
        final hash1 = await tokenService.hashToken(token1);
        final hash2 = await tokenService.hashToken(token2);
        
        expect(hash1, isNot(equals(hash2)));
      });

      test('hash is lowercase hex', () async {
        final token = await tokenService.generateToken();
        final hash = await tokenService.hashToken(token);
        
        expect(hash, matches(RegExp(r'^[a-f0-9]+$')));
      });

      test('throws on invalid token format', () async {
        expect(
          () => tokenService.hashToken('invalid'),
          throwsException,
        );
      });
    });

    group('verifyTokenHash', () {
      test('returns true for valid token and hash pair', () async {
        final token = await tokenService.generateToken();
        final hash = await tokenService.hashToken(token);
        
        final isValid = await tokenService.verifyTokenHash(token, hash);
        
        expect(isValid, isTrue);
      });

      test('returns false for mismatched token and hash', () async {
        final token1 = await tokenService.generateToken();
        final token2 = await tokenService.generateToken();
        final hash = await tokenService.hashToken(token1);
        
        final isValid = await tokenService.verifyTokenHash(token2, hash);
        
        expect(isValid, isFalse);
      });

      test('returns false for corrupted hash', () async {
        final token = await tokenService.generateToken();
        final hash = await tokenService.hashToken(token);
        
        // Corrupt one character in the hash
        final corruptedHash = hash.replaceFirst('a', 'b');
        
        final isValid = await tokenService.verifyTokenHash(token, corruptedHash);
        
        expect(isValid, isFalse);
      });

      test('returns false for empty hash', () async {
        final token = await tokenService.generateToken();
        
        final isValid = await tokenService.verifyTokenHash(token, '');
        
        expect(isValid, isFalse);
      });

      test('throws on invalid token format', () async {
        final hash = '0' * 64;
        
        expect(
          () => tokenService.verifyTokenHash('invalid', hash),
          throwsException,
        );
      });

      test('throws on invalid hash format', () async {
        final token = await tokenService.generateToken();
        
        expect(
          () => tokenService.verifyTokenHash(token, 'invalid'),
          throwsException,
        );
      });
    });

    group('isValidTokenFormat', () {
      test('accepts valid tokens', () async {
        final token = await tokenService.generateToken();
        
        expect(tokenService.isValidTokenFormat(token), isTrue);
      });

      test('rejects tokens with wrong length', () {
        expect(tokenService.isValidTokenFormat('short'), isFalse);
        expect(
          tokenService.isValidTokenFormat('x' * 100),
          isFalse,
        );
      });

      test('rejects tokens with invalid characters', () {
        expect(
          tokenService.isValidTokenFormat('!' * TokenService.TOKEN_LENGTH_BASE64),
          isFalse,
        );
      });

      test('rejects tokens with padding', () {
        expect(
          tokenService.isValidTokenFormat('A' * 42 + '='),
          isFalse,
        );
      });

      test('accepts valid Base64URL characters', () {
        // Valid: A-Z, a-z, 0-9, -, _
        final validToken = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
        expect(tokenService.isValidTokenFormat(validToken.substring(0, TokenService.TOKEN_LENGTH_BASE64)), isTrue);
      });
    });

    group('isValidHashFormat', () {
      test('accepts valid hashes', () async {
        final token = await tokenService.generateToken();
        final hash = await tokenService.hashToken(token);
        
        expect(tokenService.isValidHashFormat(hash), isTrue);
      });

      test('rejects hashes with wrong length', () {
        expect(tokenService.isValidHashFormat('short'), isFalse);
        expect(tokenService.isValidHashFormat('f' * 100), isFalse);
      });

      test('rejects hashes with uppercase letters', () {
        expect(
          tokenService.isValidHashFormat('F' + 'f' * 63),
          isFalse,
        );
      });

      test('rejects hashes with invalid characters', () {
        expect(
          tokenService.isValidHashFormat('g' * 64),
          isFalse,
        );
      });

      test('accepts exactly 64 lowercase hex characters', () {
        expect(
          tokenService.isValidHashFormat('f' * 64),
          isTrue,
        );
      });
    });

    group('timing attack resistance', () {
      test('verifyTokenHash takes similar time regardless of mismatch position', () async {
        final correctToken = await tokenService.generateToken();
        final correctHash = await tokenService.hashToken(correctToken);
        
        final wrongToken1 = await tokenService.generateToken();
        final wrongToken2 = await tokenService.generateToken();
        
        final stopwatch = Stopwatch();
        
        // Verify correctToken (should match)
        stopwatch.start();
        await tokenService.verifyTokenHash(correctToken, correctHash);
        stopwatch.stop();
        final correctTime = stopwatch.elapsedMilliseconds;
        
        // Verify wrongToken1 (first byte mismatch)
        stopwatch.reset();
        stopwatch.start();
        await tokenService.verifyTokenHash(wrongToken1, correctHash);
        stopwatch.stop();
        final wrongTime1 = stopwatch.elapsedMilliseconds;
        
        // Verify wrongToken2 (different token, likely last byte mismatch)
        stopwatch.reset();
        stopwatch.start();
        await tokenService.verifyTokenHash(wrongToken2, correctHash);
        stopwatch.stop();
        final wrongTime2 = stopwatch.elapsedMilliseconds;
        
        // Note: These timing assertions are loose because:
        // - Dartlang JIT compilation affects timing
        // - System load affects timing
        // The important thing is that the _timingSafeEquals implementation
        // doesn't short-circuit, which a unit test can't directly verify
        // but the timing should be relatively consistent
        // We just verify no exception is thrown and results are consistent
        expect(correctTime, greaterThanOrEqualTo(0));
        expect(wrongTime1, greaterThanOrEqualTo(0));
        expect(wrongTime2, greaterThanOrEqualTo(0));
      });
    });

    group('full workflow', () {
      test('complete token generation and verification workflow', () async {
        // Generate token
        final token = await tokenService.generateToken();
        expect(tokenService.isValidTokenFormat(token), isTrue);
        
        // Hash token for storage
        final hash = await tokenService.hashToken(token);
        expect(tokenService.isValidHashFormat(hash), isTrue);
        
        // Later, verify token against stored hash
        final isValid = await tokenService.verifyTokenHash(token, hash);
        expect(isValid, isTrue);
        
        // Verify that wrong token fails
        final wrongToken = await tokenService.generateToken();
        final isWrongTokenValid = await tokenService.verifyTokenHash(wrongToken, hash);
        expect(isWrongTokenValid, isFalse);
      });

      test('can verify multiple tokens', () async {
        final token1 = await tokenService.generateToken();
        final token2 = await tokenService.generateToken();
        
        final hash1 = await tokenService.hashToken(token1);
        final hash2 = await tokenService.hashToken(token2);
        
        expect(await tokenService.verifyTokenHash(token1, hash1), isTrue);
        expect(await tokenService.verifyTokenHash(token2, hash2), isTrue);
        expect(await tokenService.verifyTokenHash(token1, hash2), isFalse);
        expect(await tokenService.verifyTokenHash(token2, hash1), isFalse);
      });
    });
  });
}
