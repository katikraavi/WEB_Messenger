import 'package:test/test.dart';
import '../../lib/src/models/chat_member_model.dart';

void main() {
  group('ChatMember Model', () {
    test('ChatMember creation', () {
      final member = ChatMember(
        userId: 'user-1',
        chatId: 'chat-1',
        joinedAt: DateTime.now(),
      );

      expect(member.userId, 'user-1');
      expect(member.chatId, 'chat-1');
      expect(member.isActive, true);
      expect(member.leftAt, isNull);
    });

    test('ChatMember with leftAt is inactive', () {
      final now = DateTime.now();
      final member = ChatMember(
        userId: 'user-1',
        chatId: 'chat-1',
        joinedAt: now,
        leftAt: now.add(const Duration(hours: 1)),
      );

      expect(member.isActive, false);
      expect(member.status, 'left');
    });

    test('ChatMember active status returns active', () {
      final member = ChatMember(
        userId: 'user-1',
        chatId: 'chat-1',
        joinedAt: DateTime.now(),
      );

      expect(member.status, 'active');
    });

    test('ChatMember toJson and fromJson work correctly', () {
      final member = ChatMember(
        userId: 'user-1',
        chatId: 'chat-1',
        joinedAt: DateTime.now(),
      );

      final json = member.toJson();
      final restored = ChatMember.fromJson(json);

      expect(restored.userId, member.userId);
      expect(restored.chatId, member.chatId);
      expect(restored.isActive, member.isActive);
    });
  });
}
