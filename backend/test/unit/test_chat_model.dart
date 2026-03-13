import 'package:test/test.dart';
import '../../lib/src/models/chat_model.dart';

void main() {
  group('Chat Model', () {
    test('Chat creation with defaults', () {
      final chat = Chat(
        id: 'chat-123',
        createdAt: DateTime.now(),
        archivedByUserIds: [],
      );

      expect(chat.id, 'chat-123');
      expect(chat.archivedByUserIds, isEmpty);
    });

    test('isArchivedBy returns true for archived user', () {
      final chat = Chat(
        id: 'chat-123',
        createdAt: DateTime.now(),
        archivedByUserIds: ['user-1', 'user-2'],
      );

      expect(chat.isArchivedBy('user-1'), true);
      expect(chat.isArchivedBy('user-3'), false);
    });

    test('archiveFor adds user to archived list', () {
      final chat = Chat(
        id: 'chat-123',
        createdAt: DateTime.now(),
        archivedByUserIds: [],
      );

      final archived = chat.archiveFor('user-1');
      expect(archived.isArchivedBy('user-1'), true);
      expect(archived.archivedByUserIds, contains('user-1'));
    });

    test('archiveFor is idempotent', () {
      final chat = Chat(
        id: 'chat-123',
        createdAt: DateTime.now(),
        archivedByUserIds: ['user-1'],
      );

      final archived = chat.archiveFor('user-1');
      expect(archived.archivedByUserIds.length, 1);
    });

    test('unarchiveFor removes user from archived list', () {
      final chat = Chat(
        id: 'chat-123',
        createdAt: DateTime.now(),
        archivedByUserIds: ['user-1', 'user-2'],
      );

      final unarchived = chat.unarchiveFor('user-1');
      expect(unarchived.isArchivedBy('user-1'), false);
      expect(unarchived.archivedByUserIds, ['user-2']);
    });

    test('Chat toJson and fromJson work correctly', () {
      final chat = Chat(
        id: 'chat-123',
        createdAt: DateTime.now(),
        archivedByUserIds: ['user-1'],
      );

      final json = chat.toJson();
      final restored = Chat.fromJson(json);

      expect(restored.id, chat.id);
      expect(restored.archivedByUserIds, chat.archivedByUserIds);
    });
  });
}
