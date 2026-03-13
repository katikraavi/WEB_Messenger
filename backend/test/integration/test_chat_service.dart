import 'package:test/test.dart';
import '../../lib/src/models/chat_model.dart';
import '../../lib/src/models/chat_member_model.dart';
import '../../lib/src/services/chat_service.dart';

void main() {
  group('ChatService', () {
    test('createChat initializes with empty archived list', () {
      final chat = ChatService.createChat(id: 'chat-1');

      expect(chat.id, 'chat-1');
      expect(chat.archivedByUserIds, isEmpty);
    });

    test('addMember creates new member', () {
      final member = ChatService.addMember(userId: 'user-1', chatId: 'chat-1');

      expect(member.userId, 'user-1');
      expect(member.chatId, 'chat-1');
      expect(member.isActive, true);
    });

    test('removeMember marks member as left', () {
      final member = ChatService.addMember(userId: 'user-1', chatId: 'chat-1');
      final removed = ChatService.removeMember(member: member);

      expect(removed.isActive, false);
      expect(removed.leftAt, isNotNull);
    });

    test('isMember checks active membership', () {
      final member = ChatService.addMember(userId: 'user-1', chatId: 'chat-1');
      final members = [member];

      expect(
        ChatService.isMember(
          members: members,
          userId: 'user-1',
          chatId: 'chat-1',
        ),
        true,
      );

      expect(
        ChatService.isMember(
          members: members,
          userId: 'user-2',
          chatId: 'chat-1',
        ),
        false,
      );
    });

    test('getActiveMembers filters out left members', () {
      final member1 = ChatService.addMember(userId: 'user-1', chatId: 'chat-1');
      final member2 = ChatService.removeMember(member: member1);
      final member3 = ChatService.addMember(userId: 'user-2', chatId: 'chat-1');

      final active = ChatService.getActiveMembers([member1, member2, member3]);

      expect(active.length, 2);
      expect(active, contains(member1));
      expect(active, isNot(contains(member2)));
    });

    test('archiveChat adds user to archived list', () {
      final chat = ChatService.createChat(id: 'chat-1');
      final archived = ChatService.archiveChat(chat: chat, userId: 'user-1');

      expect(archived.isArchivedBy('user-1'), true);
    });

    test('unarchiveChat removes user from archived list', () {
      var chat = ChatService.createChat(id: 'chat-1');
      chat = ChatService.archiveChat(chat: chat, userId: 'user-1');
      chat = ChatService.unarchiveChat(chat: chat, userId: 'user-1');

      expect(chat.isArchivedBy('user-1'), false);
    });
  });
}
