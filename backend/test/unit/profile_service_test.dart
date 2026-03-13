import 'package:test/test.dart';
import '../../lib/src/services/profile_service.dart';

void main() {
  group('ProfileService', () {
    late ProfileService profileService;

    setUp(() {
      profileService = ProfileService();
    });

    group('Image Validation', () {
      test('validates JPEG format correctly', () {
        // JPEG magic number: FF D8 FF
        final jpegBytes = [0xFF, 0xD8, 0xFF, ...List.filled(100, 0x00)];
        final error = profileService.validateImage(jpegBytes, 'test.jpg');
        expect(error, isNull);
      });

      test('validates PNG format correctly', () {
        // PNG magic number: 89 50 4E 47
        final pngBytes = [0x89, 0x50, 0x4E, 0x47, ...List.filled(100, 0x00)];
        final error = profileService.validateImage(pngBytes, 'test.png');
        expect(error, isNull);
      });

      test('rejects GIF format', () {
        final error = profileService.validateImage(List.filled(100, 0x00), 'test.gif');
        expect(error, contains('Only JPEG and PNG'));
      });

      test('rejects BMP format', () {
        final error = profileService.validateImage(List.filled(100, 0x00), 'test.bmp');
        expect(error, contains('Only JPEG and PNG'));
      });

      test('rejects files larger than 5MB', () {
        final jpegBytes = [0xFF, 0xD8, 0xFF, ...List.filled(5242881, 0x00)];
        final error = profileService.validateImage(jpegBytes, 'large.jpg');
        expect(error, contains('File must be smaller than 5MB'));
      });

      test('accepts files exactly 5MB', () {
        final jpegBytes = [0xFF, 0xD8, 0xFF, ...List.filled(5242877, 0x00)];
        final error = profileService.validateImage(jpegBytes, 'exact.jpg');
        expect(error, isNull);
      });

      test('rejects invalid JPEG magic number', () {
        final invalidJpeg = [0x00, 0x00, 0x00, ...List.filled(100, 0x00)];
        final error = profileService.validateImage(invalidJpeg, 'fake.jpg');
        expect(error, contains('Invalid JPEG'));
      });

      test('rejects invalid PNG magic number', () {
        final invalidPng = [0x00, 0x00, 0x00, 0x00, ...List.filled(100, 0x00)];
        final error = profileService.validateImage(invalidPng, 'fake.png');
        expect(error, contains('Invalid PNG'));
      });
    });

    group('Profile Validation', () {
      test('validates username length constraints', () {
        final tooShort = profileService.validateProfileUpdate(username: 'ab');
        expect(tooShort, isNotNull);
        expect(tooShort!['username'], contains('3 and 32 characters'));

        final tooLong = profileService.validateProfileUpdate(username: 'a' * 33);
        expect(tooLong, isNotNull);
        expect(tooLong!['username'], contains('3 and 32 characters'));
      });

      test('validates username character constraints', () {
        final invalid = profileService.validateProfileUpdate(username: 'test@user');
        expect(invalid, isNotNull);
        expect(invalid!['username'], contains('letters, numbers, and underscores'));
      });

      test('accepts valid username', () {
        final valid = profileService.validateProfileUpdate(username: 'test_user123');
        expect(valid, isNull);
      });

      test('validates aboutMe length constraints', () {
        final tooLong = profileService.validateProfileUpdate(aboutMe: 'x' * 501);
        expect(tooLong, isNotNull);
        expect(tooLong!['aboutMe'], contains('500 characters'));
      });

      test('accepts valid aboutMe', () {
        final valid = profileService.validateProfileUpdate(aboutMe: 'Hello world' * 20);
        expect(valid, isNull);
      });
    });

    group('Text Sanitization', () {
      test('trims whitespace from text', () {
        final result = profileService.sanitizeText('  hello  ', 10);
        expect(result, equals('hello'));
      });

      test('truncates text to max length', () {
        final result = profileService.sanitizeText('hello world', 5);
        expect(result, equals('hello'));
      });

      test('trims and truncates correctly', () {
        final result = profileService.sanitizeText('  hello world  ', 8);
        expect(result, equals('hello wo'));
      });
    });

    group('File Path Generation', () {
      test('generates unique file paths', () async {
        final path1 = profileService.generateFilePath('user-123');
        await Future.delayed(const Duration(milliseconds: 10));
        final path2 = profileService.generateFilePath('user-123');
        expect(path1, isNotEmpty);
        expect(path2, isNotEmpty);
        expect(path1, isNot(equals(path2))); // Should be unique
      });

      test('file path contains user ID', () {
        final path = profileService.generateFilePath('user-456');
        expect(path, contains('user-456'));
      });

      test('file path ends with .jpg', () {
        final path = profileService.generateFilePath('user-789');
        expect(path, endsWith('.jpg'));
      });
    });

    group('Image URL Generation', () {
      test('generates correct image URL', () {
        final url = profileService.getImageUrl('profiles/user-123-1234567890.jpg');
        expect(url, equals('/uploads/profiles/user-123-1234567890.jpg'));
      });
    });
  });
}
