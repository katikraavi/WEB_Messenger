import 'package:test/test.dart';
import '../../lib/src/models/group_chat.dart';
import '../../lib/src/services/group_invite_service.dart';

void main() {
  group('GroupInviteService (unit — no DB)', () {
    group('GroupChat model', () {
      test('creates GroupChat from map', () {
        final now = DateTime.now();
        final map = {
          'id': 'g1',
          'name': 'Encoded==',
          'created_by': 'u1',
          'created_at': now,
        };
        final chat = GroupChat.fromMap(map);
        expect(chat.id, equals('g1'));
        expect(chat.name, equals('Encoded=='));
        expect(chat.createdBy, equals('u1'));
      });

      test('GroupChat.toMap round-trips all fields', () {
        final now = DateTime.now();
        final chat = GroupChat(
          id: 'g2',
          name: 'Chat',
          createdBy: 'u1',
          createdAt: now,
          isPublic: false,
        );
        final map = chat.toMap();
        expect(map['id'], equals('g2'));
        expect(map['name'], equals('Chat'));
        expect(map['created_by'], equals('u1'));
        expect(map['created_at'], equals(now));
      });
    });

    group('GroupMember model', () {
      test('creates GroupMember from map', () {
        final now = DateTime.now();
        final map = {
          'id': 'm1',
          'group_id': 'g1',
          'user_id': 'u1',
          'role': 'owner',
          'joined_at': now,
        };
        final member = GroupMember.fromMap(map);
        expect(member.groupId, equals('g1'));
        expect(member.role, equals('owner'));
      });
    });

    group('GroupInvite model', () {
      test('creates GroupInvite from map', () {
        final now = DateTime.now();
        final map = {
          'id': 'i1',
          'group_id': 'g1',
          'sender_id': 'u1',
          'receiver_id': 'u2',
          'status': 'pending',
          'created_at': now,
        };
        final invite = GroupInvite.fromMap(map);
        expect(invite.status, equals('pending'));
        expect(invite.groupId, equals('g1'));
      });

      test('GroupInvite defaults status to pending when null', () {
        final now = DateTime.now();
        final map = {
          'id': 'i2',
          'group_id': 'g1',
          'sender_id': 'u1',
          'receiver_id': 'u2',
          'status': null,
          'created_at': now,
        };
        final invite = GroupInvite.fromMap(map);
        expect(invite.status, equals('pending'));
      });
    });

    group('GroupInviteService business logic', () {
      test('throws ArgumentError for empty group name', () {
        // GroupInviteService.validateGroupName is a pure function
        expect(
          () => GroupInviteService.validateGroupName(''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for name longer than 100 chars', () {
        final longName = 'A' * 101;
        expect(
          () => GroupInviteService.validateGroupName(longName),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accepts valid group names', () {
        // Should not throw
        expect(() => GroupInviteService.validateGroupName('Team Chat'), returnsNormally);
        expect(() => GroupInviteService.validateGroupName('A'), returnsNormally);
        expect(() => GroupInviteService.validateGroupName('A' * 100), returnsNormally);
      });
    });
  });
}
