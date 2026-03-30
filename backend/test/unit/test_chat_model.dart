import 'package:test/test.dart';
import '../../lib/src/models/chat_model.dart';

void main() {
  group('Chat Model', () {
    test('Chat creation with defaults', () {
      final chat = Chat(
        id: 'chat-123',
        participant1Id: 'user-1',
        participant2Id: 'user-2',
        isParticipant1Archived: false,
        isParticipant2Archived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(chat.id, 'chat-123');
      expect(chat.isArchivedForUser('user-1'), isFalse);
    });

    test('isArchivedForUser returns true for archived user', () {
      final chat = Chat(
        id: 'chat-123',
        participant1Id: 'user-1',
        participant2Id: 'user-2',
        isParticipant1Archived: true,
        isParticipant2Archived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(chat.isArchivedForUser('user-1'), true);
      expect(chat.isArchivedForUser('user-3'), false);
    });

    test('getArchiveStatus reads per-participant archive flag', () {
      final chat = Chat(
        id: 'chat-123',
        participant1Id: 'user-1',
        participant2Id: 'user-2',
        isParticipant1Archived: true,
        isParticipant2Archived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(chat.getArchiveStatus('user-1'), true);
      expect(chat.getArchiveStatus('user-2'), false);
    });

    test('isParticipant detects both members', () {
      final chat = Chat(
        id: 'chat-123',
        participant1Id: 'user-1',
        participant2Id: 'user-2',
        isParticipant1Archived: false,
        isParticipant2Archived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(chat.isParticipant('user-1'), isTrue);
      expect(chat.isParticipant('user-2'), isTrue);
      expect(chat.isParticipant('user-3'), isFalse);
    });

    test('getOtherId returns opposite participant', () {
      final chat = Chat(
        id: 'chat-123',
        participant1Id: 'user-1',
        participant2Id: 'user-2',
        isParticipant1Archived: false,
        isParticipant2Archived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(chat.getOtherId('user-1'), 'user-2');
      expect(chat.getOtherId('user-2'), 'user-1');
    });

    test('Chat toJson and fromJson work correctly', () {
      final chat = Chat(
        id: 'chat-123',
        participant1Id: 'user-1',
        participant2Id: 'user-2',
        isParticipant1Archived: true,
        isParticipant2Archived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = chat.toJson();
      final restored = Chat.fromJson(json);

      expect(restored.id, chat.id);
      expect(restored.participant1Id, chat.participant1Id);
      expect(restored.isParticipant1Archived, chat.isParticipant1Archived);
    });
  });
}
