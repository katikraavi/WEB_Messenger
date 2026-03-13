import 'package:test/test.dart';
import 'package:backend/src/services/verification_service.dart';

void main() {
  group('VerificationService', () {
    group('VerificationStatus', () {
      test('creates status with required fields', () {
        final now = DateTime.now().toUtc();
        final status = VerificationStatus(
          userId: 'user-123',
          isVerified: false,
          userCreatedAt: now,
          activeTokenCount: 1,
        );

        expect(status.userId, equals('user-123'));
        expect(status.isVerified, isFalse);
        expect(status.userCreatedAt, equals(now));
        expect(status.activeTokenCount, equals(1));
      });

      test('isVerified and verifiedAt set together', () {
        final verifiedTime = DateTime.now().toUtc();
        final status = VerificationStatus(
          userId: 'user-123',
          isVerified: true,
          verifiedAt: verifiedTime,
          userCreatedAt: DateTime.now().toUtc().subtract(Duration(days: 1)),
          activeTokenCount: 0,
        );

        expect(status.isVerified, isTrue);
        expect(status.verifiedAt, equals(verifiedTime));
      });

      test('daysSinceCreation calculates correctly', () {
        final createdAt = DateTime.now().toUtc().subtract(Duration(days: 5));
        final status = VerificationStatus(
          userId: 'user-123',
          isVerified: false,
          userCreatedAt: createdAt,
          activeTokenCount: 1,
        );

        expect(status.daysSinceCreation, equals(5));
      });

      test('canVerify true when active tokens', () {
        final status = VerificationStatus(
          userId: 'user-123',
          isVerified: false,
          userCreatedAt: DateTime.now().toUtc(),
          activeTokenCount: 1,
        );

        expect(status.canVerify, isTrue);
      });

      test('canVerify false when no active tokens', () {
        final status = VerificationStatus(
          userId: 'user-123',
          isVerified: false,
          userCreatedAt: DateTime.now().toUtc(),
          activeTokenCount: 0,
        );

        expect(status.canVerify, isFalse);
      });

      test('canVerify false when verified', () {
        final status = VerificationStatus(
          userId: 'user-123',
          isVerified: true,
          verifiedAt: DateTime.now().toUtc(),
          userCreatedAt: DateTime.now().toUtc().subtract(Duration(days: 1)),
          activeTokenCount: 0,
        );

        expect(status.canVerify, isFalse);
      });

      test('toString includes key information', () {
        final status = VerificationStatus(
          userId: 'user-123',
          isVerified: true,
          verifiedAt: DateTime.now().toUtc(),
          userCreatedAt: DateTime.now().toUtc(),
          activeTokenCount: 0,
        );

        final str = status.toString();
        expect(str, contains('user-123'));
        expect(str, contains('isVerified'));
        expect(str, contains('VerificationStatus'));
      });
    });

    group('VerificationException', () {
      test('contains exception message', () {
        final exception = VerificationException('Token not found');

        expect(exception.message, equals('Token not found'));
      });

      test('toString includes message', () {
        final exception = VerificationException('Invalid token format');

        expect(exception.toString(), contains('Invalid token format'));
        expect(exception.toString(), contains('VerificationException'));
      });

      test('multiple exceptions with different messages', () {
        final exceptions = [
          VerificationException('Token expired'),
          VerificationException('Token already used'),
          VerificationException('User not found'),
        ];

        expect(exceptions[0].message, equals('Token expired'));
        expect(exceptions[1].message, equals('Token already used'));
        expect(exceptions[2].message, equals('User not found'));
      });
    });

    group('TOKEN_EXPIRATION constant', () {
      test('is 24 hours', () {
        expect(
          VerificationService.TOKEN_EXPIRATION,
          equals(Duration(hours: 24)),
        );
      });
    });

    group('verification workflow properties', () {
      test('new unverified user has correct status', () {
        final createdAt = DateTime.now().toUtc();
        final status = VerificationStatus(
          userId: 'new-user',
          isVerified: false,
          verifiedAt: null,
          userCreatedAt: createdAt,
          activeTokenCount: 1,
          lastTokenExpiresAt: createdAt.add(VerificationService.TOKEN_EXPIRATION),
        );

        expect(status.isVerified, isFalse);
        expect(status.canVerify, isTrue);
        expect(status.verifiedAt, isNull);
        expect(status.activeTokenCount, equals(1));
      });

      test('verified user has no active tokens', () {
        final verifiedTime = DateTime.now().toUtc();
        final status = VerificationStatus(
          userId: 'verified-user',
          isVerified: true,
          verifiedAt: verifiedTime,
          userCreatedAt: verifiedTime.subtract(Duration(days: 1)),
          activeTokenCount: 0,
        );

        expect(status.isVerified, isTrue);
        expect(status.canVerify, isFalse);
        expect(status.activeTokenCount, equals(0));
      });

      test('multiple token scenarios', () {
        // Zero tokens
        var status = VerificationStatus(
          userId: 'user',
          isVerified: false,
          userCreatedAt: DateTime.now().toUtc(),
          activeTokenCount: 0,
        );
        expect(status.canVerify, isFalse);

        // One token
        status = VerificationStatus(
          userId: 'user',
          isVerified: false,
          userCreatedAt: DateTime.now().toUtc(),
          activeTokenCount: 1,
        );
        expect(status.canVerify, isTrue);

        // Multiple tokens (shouldn't happen, but handle gracefully)
        status = VerificationStatus(
          userId: 'user',
          isVerified: false,
          userCreatedAt: DateTime.now().toUtc(),
          activeTokenCount: 5,
        );
        expect(status.canVerify, isTrue);
      });
    });

    group('duration calculations', () {
      test('daysSinceCreation for new user', () {
        final now = DateTime.now().toUtc();
        final status = VerificationStatus(
          userId: 'new',
          isVerified: false,
          userCreatedAt: now,
          activeTokenCount: 1,
        );

        expect(status.daysSinceCreation, equals(0));
      });

      test('daysSinceCreation for old user', () {
        final createdAt = DateTime(2024, 1, 1).toUtc();
        final status = VerificationStatus(
          userId: 'old',
          isVerified: true,
          verifiedAt: createdAt.add(Duration(days: 7)),
          userCreatedAt: createdAt,
          activeTokenCount: 0,
        );

        // This test might be fragile depending on current date
        // but we check that it's a reasonable value
        expect(status.daysSinceCreation, greaterThan(0));
      });
    });

    group('edge cases', () {
      test('handles null verifiedAt', () {
        final status = VerificationStatus(
          userId: 'user',
          isVerified: false,
          verifiedAt: null,
          userCreatedAt: DateTime.now().toUtc(),
          activeTokenCount: 0,
        );

        expect(status.verifiedAt, isNull);
        expect(status.isVerified, isFalse);
      });

      test('handles large activeTokenCount', () {
        final status = VerificationStatus(
          userId: 'user',
          isVerified: false,
          userCreatedAt: DateTime.now().toUtc(),
          activeTokenCount: 1000,
        );

        expect(status.activeTokenCount, equals(1000));
        expect(status.canVerify, isTrue);
      });

      test('lastTokenExpiresAt can be null', () {
        final status = VerificationStatus(
          userId: 'user',
          isVerified: false,
          userCreatedAt: DateTime.now().toUtc(),
          activeTokenCount: 0,
          lastTokenExpiresAt: null,
        );

        expect(status.lastTokenExpiresAt, isNull);
      });
    });

    group('state transitions', () {
      test('transition from unverified to verified', () {
        final createdAt = DateTime.now().toUtc();
        final verifiedAt = createdAt.add(Duration(hours: 12));

        // Before verification
        var status = VerificationStatus(
          userId: 'user',
          isVerified: false,
          verifiedAt: null,
          userCreatedAt: createdAt,
          activeTokenCount: 1,
        );

        expect(status.isVerified, isFalse);
        expect(status.canVerify, isTrue);

        // After verification
        status = VerificationStatus(
          userId: 'user',
          isVerified: true,
          verifiedAt: verifiedAt,
          userCreatedAt: createdAt,
          activeTokenCount: 0,
        );

        expect(status.isVerified, isTrue);
        expect(status.canVerify, isFalse);
      });

      test('token expiration scenario', () {
        final createdAt = DateTime.now().toUtc();
        final expiresAt = createdAt.add(VerificationService.TOKEN_EXPIRATION);

        // Active token
        var status = VerificationStatus(
          userId: 'user',
          isVerified: false,
          userCreatedAt: createdAt,
          activeTokenCount: 1,
          lastTokenExpiresAt: expiresAt,
        );

        expect(status.canVerify, isTrue);

        // After expiration (token count goes to 0)
        status = VerificationStatus(
          userId: 'user',
          isVerified: false,
          userCreatedAt: createdAt,
          activeTokenCount: 0,
          lastTokenExpiresAt: expiresAt,
        );

        expect(status.canVerify, isFalse);
      });
    });
  });
}
