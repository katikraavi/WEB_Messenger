import 'package:test/test.dart';
import 'package:backend/src/services/email_service.dart';

void main() {
  group('EmailService', () {
    late EmailService emailService;

    setUp(() {
      emailService = EmailService(
        smtpHost: 'smtp.gmail.com',
        smtpPort: 587,
        senderEmail: 'noreply@messenger.app',
        senderName: 'Mobile Messenger',
      );
    });

    group('buildVerificationEmail', () {
      test('creates email with correct structure', () {
        final email = emailService.buildVerificationEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          verificationLink: 'https://app.messenger.com/verify?token=abc123',
          expiresIn: '24 hours',
        );

        expect(email.to, equals('user@example.com'));
        expect(email.subject, contains('Verify'));
        expect(email.htmlBody, isNotEmpty);
        expect(email.plainTextBody, isNotEmpty);
      });

      test('includes recipient name in email body', () {
        final email = emailService.buildVerificationEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'Jane Smith',
          verificationLink: 'https://app.messenger.com/verify?token=abc123',
          expiresIn: '24 hours',
        );

        expect(email.htmlBody, contains('Jane Smith'));
        expect(email.plainTextBody, contains('Jane Smith'));
      });

      test('includes verification link in email body', () {
        final link = 'https://app.messenger.com/verify?token=verifyToken123';
        final email = emailService.buildVerificationEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          verificationLink: link,
          expiresIn: '24 hours',
        );

        expect(email.htmlBody, contains(link));
        expect(email.plainTextBody, contains(link));
      });

      test('includes expiration time in email body', () {
        final email = emailService.buildVerificationEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          verificationLink: 'https://app.messenger.com/verify?token=abc123',
          expiresIn: '12 hours',
        );

        expect(email.htmlBody, contains('12 hours'));
        expect(email.plainTextBody, contains('12 hours'));
      });

      test('HTML body contains clickable button', () {
        final email = emailService.buildVerificationEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          verificationLink: 'https://app.messenger.com/verify?token=abc123',
          expiresIn: '24 hours',
        );

        expect(email.htmlBody, contains('button'));
        expect(email.htmlBody, contains('href'));
      });

      test('plain text body is human readable', () {
        final email = emailService.buildVerificationEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          verificationLink: 'https://app.messenger.com/verify?token=abc123',
          expiresIn: '24 hours',
        );

        // Should not contain HTML tags
        expect(email.plainTextBody, isNot(contains('<')));
        expect(email.plainTextBody, isNot(contains('>')));
      });
    });

    group('buildPasswordResetEmail', () {
      test('creates email with correct structure', () {
        final email = emailService.buildPasswordResetEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          resetLink: 'https://app.messenger.com/reset?token=reset123',
          expiresIn: '2 hours',
        );

        expect(email.to, equals('user@example.com'));
        expect(email.subject, contains('Password'));
        expect(email.htmlBody, isNotEmpty);
        expect(email.plainTextBody, isNotEmpty);
      });

      test('includes recipient name in email body', () {
        final email = emailService.buildPasswordResetEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'Alice Wonder',
          resetLink: 'https://app.messenger.com/reset?token=reset123',
          expiresIn: '2 hours',
        );

        expect(email.htmlBody, contains('Alice Wonder'));
        expect(email.plainTextBody, contains('Alice Wonder'));
      });

      test('includes reset link in email body', () {
        final link = 'https://app.messenger.com/reset?token=resetToken456';
        final email = emailService.buildPasswordResetEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          resetLink: link,
          expiresIn: '2 hours',
        );

        expect(email.htmlBody, contains(link));
        expect(email.plainTextBody, contains(link));
      });

      test('includes security alert in HTML body', () {
        final email = emailService.buildPasswordResetEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          resetLink: 'https://app.messenger.com/reset?token=reset123',
          expiresIn: '2 hours',
        );

        expect(email.htmlBody, contains('Security Alert'));
      });

      test('includes security alert in plain text body', () {
        final email = emailService.buildPasswordResetEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          resetLink: 'https://app.messenger.com/reset?token=reset123',
          expiresIn: '2 hours',
        );

        expect(email.plainTextBody, contains('SECURITY ALERT'));
      });

      test('includes expiration info in email body', () {
        final email = emailService.buildPasswordResetEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          resetLink: 'https://app.messenger.com/reset?token=reset123',
          expiresIn: '3 hours',
        );

        expect(email.htmlBody, contains('3 hours'));
        expect(email.plainTextBody, contains('3 hours'));
      });

      test('mentions one-time use of link', () {
        final email = emailService.buildPasswordResetEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          resetLink: 'https://app.messenger.com/reset?token=reset123',
          expiresIn: '2 hours',
        );

        expect(email.plainTextBody, contains('only use this link once'));
      });

      test('HTML body contains clickable button', () {
        final email = emailService.buildPasswordResetEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'John Doe',
          resetLink: 'https://app.messenger.com/reset?token=reset123',
          expiresIn: '2 hours',
        );

        expect(email.htmlBody, contains('button'));
        expect(email.htmlBody, contains('href'));
      });
    });

    group('sendEmail', () {
      test('throws when email service not configured', () async {
        final unconfiguredService = EmailService();

        final message = EmailMessage(
          to: 'user@example.com',
          subject: 'Test',
          htmlBody: '<p>Test</p>',
          plainTextBody: 'Test',
        );

        expect(
          () => unconfiguredService.sendEmail(message),
          throwsA(isA<EmailSendException>()),
        );
      });

      test('returns true for successful send', () async {
        final message = EmailMessage(
          to: 'user@example.com',
          subject: 'Test Email',
          htmlBody: '<p>This is a test</p>',
          plainTextBody: 'This is a test',
        );

        final result = await emailService.sendEmail(message);

        expect(result, isTrue);
      });

      test('handles zero recipients gracefully', () async {
        final message = EmailMessage(
          to: '',
          subject: 'Test',
          htmlBody: '<p>Test</p>',
          plainTextBody: 'Test',
        );

        // Should not throw, but send anyway (would fail in real service)
        final result = await emailService.sendEmail(message);
        expect(result, isTrue);
      });
    });

    group('EmailMessage', () {
      test('creates message with required fields', () {
        final message = EmailMessage(
          to: 'user@example.com',
          subject: 'Test Subject',
          htmlBody: '<p>HTML Body</p>',
          plainTextBody: 'Plain Text Body',
        );

        expect(message.to, equals('user@example.com'));
        expect(message.subject, equals('Test Subject'));
        expect(message.htmlBody, equals('<p>HTML Body</p>'));
        expect(message.plainTextBody, equals('Plain Text Body'));
      });

      test('creates message with CC and BCC', () {
        final message = EmailMessage(
          to: 'user@example.com',
          subject: 'Test',
          htmlBody: '<p>Test</p>',
          plainTextBody: 'Test',
          cc: ['cc@example.com'],
          bcc: ['bcc@example.com'],
        );

        expect(message.cc, equals(['cc@example.com']));
        expect(message.bcc, equals(['bcc@example.com']));
      });

      test('defaults CC and BCC to empty lists', () {
        final message = EmailMessage(
          to: 'user@example.com',
          subject: 'Test',
          htmlBody: '<p>Test</p>',
          plainTextBody: 'Test',
        );

        expect(message.cc, isEmpty);
        expect(message.bcc, isEmpty);
      });

      test('toString includes recipient and subject', () {
        final message = EmailMessage(
          to: 'user@example.com',
          subject: 'Important Email',
          htmlBody: '<p>Content</p>',
          plainTextBody: 'Content',
        );

        final str = message.toString();
        expect(str, contains('user@example.com'));
        expect(str, contains('Important Email'));
      });
    });

    group('EmailSendException', () {
      test('contains exception message', () {
        final exception = EmailSendException('Connection failed');

        expect(exception.message, equals('Connection failed'));
        expect(exception.toString(), contains('Connection failed'));
      });
    });

    group('integration', () {
      test('verification email has all required parts', () {
        final email = emailService.buildVerificationEmail(
          recipientEmail: 'newuser@example.com',
          recipientName: 'New User',
          verificationLink: 'https://app.messenger.com/verify?token=verify123token',
          expiresIn: '24 hours',
        );

        // Check all key components are present
        expect(email.to, isNotEmpty);
        expect(email.subject, isNotEmpty);
        expect(email.htmlBody, isNotEmpty);
        expect(email.plainTextBody, isNotEmpty);
        expect(email.htmlBody.length, greaterThan(email.plainTextBody.length));
      });

      test('password reset email has all required parts', () {
        final email = emailService.buildPasswordResetEmail(
          recipientEmail: 'user@example.com',
          recipientName: 'User Name',
          resetLink: 'https://app.messenger.com/reset?token=reset123token',
          expiresIn: '2 hours',
        );

        // Check all key components are present
        expect(email.to, isNotEmpty);
        expect(email.subject, isNotEmpty);
        expect(email.htmlBody, isNotEmpty);
        expect(email.plainTextBody, isNotEmpty);
        expect(email.htmlBody.length, greaterThan(email.plainTextBody.length));
      });
    });
  });
}
