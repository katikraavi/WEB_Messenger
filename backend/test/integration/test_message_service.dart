import 'package:test/test.dart';
import '../../lib/src/models/enums.dart';
import '../../lib/src/models/message_model.dart';
import '../../lib/src/services/message_service.dart';

void main() {
  group('MessageService', () {
    test('createMessage initializes with sent status', () {
      final message = MessageService.createMessage(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_text',
      );

      expect(message.status, MessageStatus.sent);
      expect(message.createdAt, isNotNull);
    });

    test('markDelivered updates status', () {
      final message = MessageService.createMessage(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_text',
      );

      final delivered = MessageService.markDelivered(message);
      expect(delivered.status, MessageStatus.delivered);
      expect(message.status, MessageStatus.sent); // original unchanged
    });

    test('markRead updates status', () {
      final message = MessageService.createMessage(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_text',
      );

      final read = MessageService.markRead(message);
      expect(read.status, MessageStatus.read);
    });

    test('editMessage updates content and sets editedAt', () {
      final message = MessageService.createMessage(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'old_encrypted_text',
      );

      final edited = MessageService.editMessage(
        message: message,
        newEncryptedContent: 'new_encrypted_text',
      );

      expect(edited.encryptedContent, 'new_encrypted_text');
      expect(edited.editedAt, isNotNull);
    });

    test('canEdit returns true within 15 minutes', () {
      final now = DateTime.now();
      final message = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_text',
        status: MessageStatus.sent,
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      expect(MessageService.canEdit(message), true);
    });

    test('canEdit returns false after 15 minutes', () {
      final now = DateTime.now();
      final message = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_text',
        status: MessageStatus.sent,
        createdAt: now.subtract(const Duration(minutes: 20)),
      );

      expect(MessageService.canEdit(message), false);
    });

    test('canDelete returns true within 24 hours', () {
      final now = DateTime.now();
      final message = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_text',
        status: MessageStatus.sent,
        createdAt: now.subtract(const Duration(hours: 12)),
      );

      expect(MessageService.canDelete(message), true);
    });

    test('filterByStatus returns only matching messages', () {
      final msg1 = MessageService.createMessage(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'text',
      );
      final msg2 = MessageService.markRead(msg1.copyWith(status: MessageStatus.read));
      
      final filtered = MessageService.filterByStatus(
        [msg1, msg2],
        MessageStatus.sent,
      );

      expect(filtered.length, 1);
      expect(filtered[0].status, MessageStatus.sent);
    });

    test('sortByDate orders messages chronologically', () {
      final now = DateTime.now();
      final msg1 = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'text',
        status: MessageStatus.sent,
        createdAt: now.add(const Duration(hours: 1)),
      );
      final msg2 = Message(
        id: 'msg-2',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'text',
        status: MessageStatus.sent,
        createdAt: now,
      );

      final sorted = MessageService.sortByDate([msg1, msg2]);

      expect(sorted[0].id, 'msg-2');
      expect(sorted[1].id, 'msg-1');
    });
  });
}
