import 'package:test/test.dart';
import '../../lib/src/models/user_model.dart';
import '../../lib/src/models/chat_model.dart';
import '../../lib/src/models/message_model.dart';
import '../../lib/src/models/invite_model.dart';
import '../../lib/src/models/enums.dart';

void main() {
  group('E2E Feature Integration', () {
    test('User registration and profile update workflow', () {
      final user = User(
        id: 'user-123',
        email: 'alice@example.com',
        username: 'alice_wonder',
        passwordHash: 'hashed_pwd_123',
        emailVerified: false,
        createdAt: DateTime.now(),
      );

      expect(user.email, 'alice@example.com');

      final verified = user.copyWith(emailVerified: true);
      expect(verified.emailVerified, true);

      final withProfile = verified.copyWith(
        profilePictureUrl: 'https://example.com/alice.jpg',
        aboutMe: 'Alice in Wonderland',
      );

      expect(withProfile.aboutMe, 'Alice in Wonderland');
    });

    test('Chat creation with members and archiving', () {
      final chat = Chat(
        id: 'chat-group-1',
        createdAt: DateTime.now(),
        archivedByUserIds: [],
      );

      expect(chat.id, 'chat-group-1');

      var archivedByAlice = chat.archiveFor('alice');
      expect(archivedByAlice.isArchivedBy('alice'), true);

      var archivedByBob = archivedByAlice.archiveFor('bob');
      expect(archivedByBob.archivedByUserIds.length, 2);

      final unarchived = archivedByBob.unarchiveFor('alice');
      expect(unarchived.isArchivedBy('alice'), false);
      expect(unarchived.isArchivedBy('bob'), true);
    });

    test('Message sending with encryption and status tracking', () {
      final message = Message(
        id: 'msg-encrypted-1',
        chatId: 'chat-1',
        senderId: 'alice',
        encryptedContent: 'encrypted_secret_message',
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
      );

      expect(message.status, MessageStatus.sent);
      expect(message.isEdited, false);

      final delivered = message.copyWith(status: MessageStatus.delivered);
      expect(delivered.status, MessageStatus.delivered);

      final read = delivered.copyWith(status: MessageStatus.read);
      expect(read.status, MessageStatus.read);
    });

    test('User invitation lifecycle', () {
      final invite = Invite(
        id: 'invite-1',
        senderId: 'alice',
        receiverId: 'charlie',
        status: InviteStatus.pending,
        createdAt: DateTime.now(),
      );

      expect(invite.isPending, true);
      expect(invite.isAccepted, false);

      final accepted = invite.copyWith(
        status: InviteStatus.accepted,
        respondedAt: DateTime.now(),
      );

      expect(accepted.isAccepted, true);
      expect(accepted.responseTime, isNotNull);
    });

    test('Multiple users connecting through invites', () {
      final invites = [
        Invite(
          id: 'inv-1',
          senderId: 'alice',
          receiverId: 'bob',
          status: InviteStatus.accepted,
          createdAt: DateTime.now(),
        ),
        Invite(
          id: 'inv-2',
          senderId: 'bob',
          receiverId: 'charlie',
          status: InviteStatus.accepted,
          createdAt: DateTime.now(),
        ),
        Invite(
          id: 'inv-3',
          senderId: 'alice',
          receiverId: 'charlie',
          status: InviteStatus.pending,
          createdAt: DateTime.now(),
        ),
      ];

      final aliceBobAccepted = invites
          .where((i) =>
              i.isAccepted &&
              ((i.senderId == 'alice' && i.receiverId == 'bob') ||
                  (i.senderId == 'bob' && i.receiverId == 'alice')))
          .isNotEmpty;

      expect(aliceBobAccepted, true);

      final aliceCharlieAccepted = invites
          .where((i) =>
              i.isAccepted &&
              ((i.senderId == 'alice' && i.receiverId == 'charlie') ||
                  (i.senderId == 'charlie' && i.receiverId == 'alice')))
          .isEmpty;

      expect(aliceCharlieAccepted, true); // No accepted invite (only pending)
    });
  });
}
