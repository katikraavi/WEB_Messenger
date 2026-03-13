import 'package:test/test.dart';
import 'package:backend/src/services/password_reset_service.dart';

void main() {
  group('PasswordResetService', () {
    group('validatePassword', () {
      final service = PasswordResetService(
        db: null as dynamic,
        tokenService: null as dynamic,
      );

      test('accepts valid password', () {
        final validation = service.validatePassword('SecurePass123!');

        expect(validation.isValid, isTrue);
        expect(validation.errors, isEmpty);
      });

      test('rejects empty password', () {
        final validation = service.validatePassword('');

        expect(validation.isValid, isFalse);
        expect(validation.errors, contains('Password is required'));
      });

      test('rejects password too short', () {
        final validation = service.validatePassword('Short1!');

        expect(validation.isValid, isFalse);
        expect(validation.errors, contains(contains('at least 8 characters')));
      });

      test('rejects password too long', () {
        final validation = service.validatePassword('A' * 129 + 'b1!');

        expect(validation.isValid, isFalse);
        expect(validation.errors, contains(contains('must not exceed')));
      });

      test('requires uppercase letter', () {
        final validation = service.validatePassword('securepass123!');

        expect(validation.isValid, isFalse);
        expect(
          validation.errors,
          contains(
            predicate<String>((e) => e.contains('uppercase') || e.contains('Uppercase')),
          ),
        );
      });

      test('requires lowercase letter', () {
        final validation = service.validatePassword('SECUREPASS123!');

        expect(validation.isValid, isFalse);
        expect(
          validation.errors,
          contains(
            predicate<String>((e) => e.contains('lowercase') || e.contains('Lowercase')),
          ),
        );
      });

      test('requires digit', () {
        final validation = service.validatePassword('SecurePass!');

        expect(validation.isValid, isFalse);
        expect(
          validation.errors,
          contains(
            predicate<String>((e) => e.contains('digit') || e.contains('Digit')),
          ),
        );
      });

      test('requires special character', () {
        final validation = service.validatePassword('SecurePass123');

        expect(validation.isValid, isFalse);
        expect(
          validation.errors,
          contains(
            predicate<String>((e) => e.contains('special') || e.contains('Special')),
          ),
        );
      });

      test('accepts various special characters', () {
        const specialChars = '!@#\$%^&*()_+-=[]{};\':\",./<>?\\|`~';

        for (final char in specialChars.split('')) {
          final password = 'SecurePass123$char';
          final validation = service.validatePassword(password);

          expect(
            validation.isValid,
            isTrue,
            reason: 'Should accept special character: $char',
          );
        }
      });

      test('validates multiple requirements simultaneously', () {
        final testCases = [
          ('', false), // Empty
          ('short', false), // Too short, missing requirements
          ('ShortPass1!', true), // Valid
          ('ValidPassword123!ValidPassword123!ValidPassword123!ValidPassword123!'
              'ValidPassword123!ValidPassword123!', true), // Long but valid
          ('NoDigitsHere!', false), // Missing digit
          ('nouppercasehere123!', false), // Missing uppercase
          ('NOUPPERCASEHERE123!', false), // Missing lowercase
          ('NoNumbers!', false), // Missing digit
          ('NoSpecial123', false), // Missing special
        ];

        for (final (password, expected) in testCases) {
          final validation = service.validatePassword(password);
          expect(
            validation.isValid,
            expected,
            reason: 'Password: "$password"',
          );
        }
      });
    });

    group('PasswordResetValidation', () {
      test('isValid true when no errors', () {
        final validation = PasswordResetValidation(
          isValid: true,
          errors: [],
        );

        expect(validation.isValid, isTrue);
      });

      test('isValid false when errors present', () {
        final validation = PasswordResetValidation(
          isValid: false,
          errors: ['Password too short'],
        );

        expect(validation.isValid, isFalse);
      });

      test('contains error messages', () {
        final errors = [
          'Password too short',
          'Missing uppercase',
          'Missing digit',
        ];
        final validation = PasswordResetValidation(
          isValid: false,
          errors: errors,
        );

        expect(validation.errors, equals(errors));
      });

      test('toString includes validation details', () {
        final validation = PasswordResetValidation(
          isValid: false,
          errors: ['Error 1', 'Error 2'],
        );

        final str = validation.toString();
        expect(str, contains('PasswordResetValidation'));
        expect(str, contains('isValid'));
      });
    });

    group('PasswordResetException', () {
      test('contains exception message', () {
        final exception = PasswordResetException('Password reset failed');

        expect(exception.message, equals('Password reset failed'));
      });

      test('toString includes message', () {
        final exception = PasswordResetException('Connection timeout');

        expect(exception.toString(), contains('Connection timeout'));
        expect(exception.toString(), contains('PasswordResetException'));
      });
    });

    group('constants', () {
      test('MIN_PASSWORD_LENGTH is 8', () {
        expect(PasswordResetService.MIN_PASSWORD_LENGTH, equals(8));
      });

      test('MAX_PASSWORD_LENGTH is 128', () {
        expect(PasswordResetService.MAX_PASSWORD_LENGTH, equals(128));
      });

      test('TOKEN_EXPIRATION is 2 hours', () {
        expect(
          PasswordResetService.TOKEN_EXPIRATION,
          equals(Duration(hours: 2)),
        );
      });
    });
  });
}
