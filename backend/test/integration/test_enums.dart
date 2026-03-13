import 'package:test/test.dart';
import '../../lib/src/models/enums.dart';

void main() {
  group('Message Status Enum', () {
    test('MessageStatus has all expected values', () {
      expect(MessageStatus.values, contains(MessageStatus.sent));
      expect(MessageStatus.values, contains(MessageStatus.delivered));
      expect(MessageStatus.values, contains(MessageStatus.read));
      expect(MessageStatus.values.length, 3);
    });

    test('toDbString returns correct string values', () {
      expect(MessageStatus.sent.toDbString(), 'sent');
      expect(MessageStatus.delivered.toDbString(), 'delivered');
      expect(MessageStatus.read.toDbString(), 'read');
    });

    test('fromString parses all valid statuses', () {
      expect(MessageStatusExtension.fromString('sent'), MessageStatus.sent);
      expect(MessageStatusExtension.fromString('delivered'), MessageStatus.delivered);
      expect(MessageStatusExtension.fromString('read'), MessageStatus.read);
    });

    test('fromString throws on invalid status', () {
      expect(
        () => MessageStatusExtension.fromString('invalid'),
        throwsArgumentError,
      );
    });
  });

  group('Invite Status Enum', () {
    test('InviteStatus has all expected values', () {
      expect(InviteStatus.values, contains(InviteStatus.pending));
      expect(InviteStatus.values, contains(InviteStatus.accepted));
      expect(InviteStatus.values, contains(InviteStatus.declined));
      expect(InviteStatus.values.length, 3);
    });

    test('toDbString returns correct string values', () {
      expect(InviteStatus.pending.toDbString(), 'pending');
      expect(InviteStatus.accepted.toDbString(), 'accepted');
      expect(InviteStatus.declined.toDbString(), 'declined');
    });

    test('fromString parses all valid statuses', () {
      expect(InviteStatusExtension.fromString('pending'), InviteStatus.pending);
      expect(InviteStatusExtension.fromString('accepted'), InviteStatus.accepted);
      expect(InviteStatusExtension.fromString('declined'), InviteStatus.declined);
    });

    test('fromString throws on invalid status', () {
      expect(
        () => InviteStatusExtension.fromString('invalid'),
        throwsArgumentError,
      );
    });
  });
}
