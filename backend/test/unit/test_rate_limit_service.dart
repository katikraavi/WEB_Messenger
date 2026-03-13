import 'package:test/test.dart';
import 'package:backend/src/services/rate_limit_service.dart';

void main() {
  group('RateLimitService', () {
    late RateLimitService rateLimitService;

    setUp(() {
      rateLimitService = RateLimitService(
        maxAttempts: 5,
        windowDuration: Duration(hours: 1),
      );
    });

    tearDown(() async {
      await rateLimitService.clearAll();
    });

    group('isRateLimited', () {
      test('new identifier is not rate limited', () async {
        final isLimited = await rateLimitService.isRateLimited('user@example.com');

        expect(isLimited, isFalse);
      });

      test('returns false until max attempts reached', () async {
        for (int i = 0; i < 5; i++) {
          final isLimited = await rateLimitService.isRateLimited('user@example.com');
          expect(isLimited, isFalse);

          await rateLimitService.recordAttempt('user@example.com');
        }
      });

      test('returns true when max attempts exceeded', () async {
        // Record max attempts
        for (int i = 0; i < 5; i++) {
          await rateLimitService.recordAttempt('user@example.com');
        }

        // 6th check should be rate limited
        final isLimited = await rateLimitService.isRateLimited('user@example.com');

        expect(isLimited, isTrue);
      });

      test('rate limit applies per identifier', () async {
        // Fill up one identifier
        for (int i = 0; i < 5; i++) {
          await rateLimitService.recordAttempt('user1@example.com');
        }

        // Other identifier should not be limited
        final user2Limited = await rateLimitService.isRateLimited('user2@example.com');
        expect(user2Limited, isFalse);

        // First identifier should be limited
        final user1Limited = await rateLimitService.isRateLimited('user1@example.com');
        expect(user1Limited, isTrue);
      });
    });

    group('recordAttempt', () {
      test('records new attempt', () async {
        final count = await rateLimitService.recordAttempt('user@example.com');

        expect(count, equals(1));
      });

      test('increments attempt count', () async {
        await rateLimitService.recordAttempt('user@example.com');
        final count = await rateLimitService.recordAttempt('user@example.com');

        expect(count, equals(2));
      });

      test('records multiple attempts', () async {
        for (int i = 1; i <= 5; i++) {
          final count = await rateLimitService.recordAttempt('user@example.com');
          expect(count, equals(i));
        }
      });

      test('returns count after reaching max attempts', () async {
        for (int i = 0; i < 5; i++) {
          await rateLimitService.recordAttempt('user@example.com');
        }

        final count = await rateLimitService.recordAttempt('user@example.com');
        expect(count, equals(6)); // Count continues to increase
      });
    });

    group('getRemainingAttempts', () {
      test('returns max attempts for new identifier', () async {
        final remaining = await rateLimitService.getRemainingAttempts('user@example.com');

        expect(remaining, equals(5));
      });

      test('decreases as attempts are recorded', () async {
        for (int i = 0; i < 3; i++) {
          await rateLimitService.recordAttempt('user@example.com');
        }

        final remaining = await rateLimitService.getRemainingAttempts('user@example.com');

        expect(remaining, equals(2));
      });

      test('returns zero when rate limited', () async {
        for (int i = 0; i < 5; i++) {
          await rateLimitService.recordAttempt('user@example.com');
        }

        final remaining = await rateLimitService.getRemainingAttempts('user@example.com');

        expect(remaining, equals(0));
      });

      test('returns clamped value (never negative)', () async {
        for (int i = 0; i < 10; i++) {
          await rateLimitService.recordAttempt('user@example.com');
        }

        final remaining = await rateLimitService.getRemainingAttempts('user@example.com');

        expect(remaining, equals(0)); // Never negative
      });
    });

    group('getResetTime', () {
      test('returns null for identifier with no attempts', () async {
        final resetTime = await rateLimitService.getResetTime('user@example.com');

        expect(resetTime, isNull);
      });

      test('returns time in future when attempts recorded', () async {
        await rateLimitService.recordAttempt('user@example.com');
        final resetTime = await rateLimitService.getResetTime('user@example.com');

        expect(resetTime, isNotNull);
        expect(resetTime!.isAfter(DateTime.now()), isTrue);
      });

      test('reset time is oldest attempt plus window duration', () async {
        final before = DateTime.now();
        await rateLimitService.recordAttempt('user@example.com');
        final after = DateTime.now();

        final resetTime = await rateLimitService.getResetTime('user@example.com');

        // Reset time should be approximately now + 1 hour
        final expectedMin = before.add(Duration(hours: 1));
        final expectedMax = after.add(Duration(hours: 1)).add(Duration(seconds: 1));

        expect(resetTime!.isAfter(expectedMin.subtract(Duration(seconds: 1))), isTrue);
        expect(resetTime!.isBefore(expectedMax), isTrue);
      });
    });

    group('getAttemptCount', () {
      test('returns zero for new identifier', () async {
        final count = await rateLimitService.getAttemptCount('user@example.com');

        expect(count, equals(0));
      });

      test('returns correct count after attempts', () async {
        await rateLimitService.recordAttempt('user@example.com');
        await rateLimitService.recordAttempt('user@example.com');
        await rateLimitService.recordAttempt('user@example.com');

        final count = await rateLimitService.getAttemptCount('user@example.com');

        expect(count, equals(3));
      });

      test('returns count at max attempts', () async {
        for (int i = 0; i < 5; i++) {
          await rateLimitService.recordAttempt('user@example.com');
        }

        final count = await rateLimitService.getAttemptCount('user@example.com');

        expect(count, equals(5));
      });
    });

    group('clearAttempts', () {
      test('clears attempts for specific identifier', () async {
        await rateLimitService.recordAttempt('user@example.com');
        await rateLimitService.recordAttempt('user@example.com');

        await rateLimitService.clearAttempts('user@example.com');
        final count = await rateLimitService.getAttemptCount('user@example.com');

        expect(count, equals(0));
      });

      test('only clears specified identifier', () async {
        await rateLimitService.recordAttempt('user1@example.com');
        await rateLimitService.recordAttempt('user2@example.com');

        await rateLimitService.clearAttempts('user1@example.com');

        final count1 = await rateLimitService.getAttemptCount('user1@example.com');
        final count2 = await rateLimitService.getAttemptCount('user2@example.com');

        expect(count1, equals(0));
        expect(count2, equals(1));
      });

      test('allows re-recording after clear', () async {
        await rateLimitService.recordAttempt('user@example.com');
        await rateLimitService.clearAttempts('user@example.com');
        await rateLimitService.recordAttempt('user@example.com');

        final count = await rateLimitService.getAttemptCount('user@example.com');

        expect(count, equals(1));
      });
    });

    group('clearAll', () {
      test('clears all identifiers', () async {
        await rateLimitService.recordAttempt('user1@example.com');
        await rateLimitService.recordAttempt('user2@example.com');
        await rateLimitService.recordAttempt('user3@example.com');

        await rateLimitService.clearAll();

        expect(await rateLimitService.getAttemptCount('user1@example.com'), equals(0));
        expect(await rateLimitService.getAttemptCount('user2@example.com'), equals(0));
        expect(await rateLimitService.getAttemptCount('user3@example.com'), equals(0));
      });
    });

    group('sliding window cleanup', () {
      test('removes attempts older than window', () async {
        final shortWindowService = RateLimitService(
          maxAttempts: 3,
          windowDuration: Duration(milliseconds: 100),
        );

        await shortWindowService.recordAttempt('user@example.com');
        await shortWindowService.recordAttempt('user@example.com');

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        // Record new attempt
        await shortWindowService.recordAttempt('user@example.com');

        // Should have only 1 attempt (old ones cleaned up)
        final count = await shortWindowService.getAttemptCount('user@example.com');
        expect(count, equals(1));
      });

      test('cleans up during rate limit check', () async {
        final shortWindowService = RateLimitService(
          maxAttempts: 3,
          windowDuration: Duration(milliseconds: 100),
        );

        for (int i = 0; i < 3; i++) {
          await shortWindowService.recordAttempt('user@example.com');
        }

        // Should be rate limited
        var isLimited = await shortWindowService.isRateLimited('user@example.com');
        expect(isLimited, isTrue);

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        // Should no longer be rate limited
        isLimited = await shortWindowService.isRateLimited('user@example.com');
        expect(isLimited, isFalse);
      });

      test('handles cleanup with multiple identifiers', () async {
        final shortWindowService = RateLimitService(
          maxAttempts: 2,
          windowDuration: Duration(milliseconds: 100),
        );

        // Record attempts for two identifiers
        await shortWindowService.recordAttempt('user1@example.com');
        await shortWindowService.recordAttempt('user1@example.com');
        await shortWindowService.recordAttempt('user2@example.com');

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        // Check counts - old entries should be cleaned
        final count1 = await shortWindowService.getAttemptCount('user1@example.com');
        final count2 = await shortWindowService.getAttemptCount('user2@example.com');

        expect(count1, equals(0)); // All old attempts cleaned
        expect(count2, equals(0)); // All old attempts cleaned
      });
    });

    group('RateLimitInfo', () {
      test('contains all required fields', () {
        final info = RateLimitInfo(
          isLimited: false,
          attemptCount: 2,
          maxAttempts: 5,
          remainingAttempts: 3,
          resetTime: DateTime.now().add(Duration(hours: 1)),
        );

        expect(info.isLimited, isFalse);
        expect(info.attemptCount, equals(2));
        expect(info.maxAttempts, equals(5));
        expect(info.remainingAttempts, equals(3));
        expect(info.resetTime, isNotNull);
      });

      test('timeUntilReset calculates duration correctly', () {
        final futureTime = DateTime.now().add(Duration(minutes: 30));
        final info = RateLimitInfo(
          isLimited: true,
          attemptCount: 5,
          maxAttempts: 5,
          remainingAttempts: 0,
          resetTime: futureTime,
        );

        final timeUntil = info.timeUntilReset;

        expect(timeUntil, isNotNull);
        expect(timeUntil!.inMinutes, greaterThanOrEqualTo(29));
        expect(timeUntil.inMinutes, lessThanOrEqualTo(31));
      });

      test('timeUntilReset returns null when no reset time', () {
        final info = RateLimitInfo(
          isLimited: false,
          attemptCount: 0,
          maxAttempts: 5,
          remainingAttempts: 5,
          resetTime: null,
        );

        expect(info.timeUntilReset, isNull);
      });

      test('timeUntilReset returns zero when reset time passed', () {
        final pastTime = DateTime.now().subtract(Duration(minutes: 10));
        final info = RateLimitInfo(
          isLimited: false,
          attemptCount: 0,
          maxAttempts: 5,
          remainingAttempts: 5,
          resetTime: pastTime,
        );

        final timeUntil = info.timeUntilReset;

        expect(timeUntil, equals(Duration.zero));
      });
    });

    group('concurrent access', () {
      test('handles concurrent recordAttempt calls', () async {
        final futures = <Future<int>>[];

        for (int i = 0; i < 10; i++) {
          futures.add(rateLimitService.recordAttempt('concurrent@example.com'));
        }

        final results = await Future.wait(futures);

        final finalCount = await rateLimitService.getAttemptCount('concurrent@example.com');

        expect(finalCount, equals(10));
        // All counts should be unique (no race condition)
        expect(results.toSet().length, equals(10));
      });
    });
  });
}
