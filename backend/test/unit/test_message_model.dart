import 'package:test/test.dart';
import '../../lib/src/models/enums.dart';
import '../../lib/src/models/message_model.dart';

void main() {
  group('Message Model', () {
    test('Message creation with defaults', () {
      final message = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_data',
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
      );

      expect(message.id, 'msg-1');
      expect(message.status, MessageStatus.sent);
      expect(message.isEdited, false);
      expect(message.mediaUrl, isNull);
    });

    test('Message isEdited returns true when edited', () {
      final message = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_data',
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
        editedAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(message.isEdited, true);
    });

    test('Message copyWith creates new instance', () {
      final original = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_data',
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(status: MessageStatus.read);

      expect(updated.status, MessageStatus.read);
      expect(original.status, MessageStatus.sent);
    });

    test('Message with media has mediaUrl and mediaType', () {
      final message = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_data',
        mediaUrl: 'https://example.com/image.jpg',
        mediaType: 'image/jpeg',
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
      );

      expect(message.mediaUrl, 'https://example.com/image.jpg');
      expect(message.mediaType, 'image/jpeg');
    });

    test('Message toJson and fromJson work correctly', () {
      final message = Message(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        encryptedContent: 'encrypted_data',
        status: MessageStatus.delivered,
        createdAt: DateTime.now(),
      );

      final json = message.toJson();
      final restored = Message.fromJson(json);

      expect(restored.id, message.id);
      expect(restored.status, MessageStatus.delivered);
    });
  });
}
