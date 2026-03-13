import 'package:test/test.dart';
import '../../lib/src/models/enums.dart';
import '../../lib/src/models/invite_model.dart';
import '../../lib/src/services/invite_service.dart';

void main() {
  group('InviteService', () {
    test('createInvite initializes with pending status', () {
      final invite = InviteService.createInvite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
      );

      expect(invite.isPending, true);
      expect(invite.status, InviteStatus.pending);
    });

    test('acceptInvite changes status to accepted', () {
      final invite = InviteService.createInvite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
      );

      final accepted = InviteService.acceptInvite(invite);
      expect(accepted.isAccepted, true);
      expect(accepted.respondedAt, isNotNull);
    });

    test('acceptInvite throws for non-pending invite', () {
      final invite = InviteService.createInvite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
      );
      final accepted = InviteService.acceptInvite(invite);

      expect(
        () => InviteService.acceptInvite(accepted),
        throwsException,
      );
    });

    test('declineInvite changes status to declined', () {
      final invite = InviteService.createInvite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
      );

      final declined = InviteService.declineInvite(invite);
      expect(declined.isDeclined, true);
    });

    test('isExpired returns true after 30 days', () {
      final invite = Invite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
        status: InviteStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(days: 31)),
      );

      expect(InviteService.isExpired(invite), true);
    });

    test('isExpired returns false within 30 days', () {
      final invite = Invite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
        status: InviteStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      );

      expect(InviteService.isExpired(invite), false);
    });

    test('getPendingForUser returns only pending invites for user', () {
      final inv1 = InviteService.createInvite(
        id: 'inv1',
        senderId: 'user-1',
        receiverId: 'user-2',
      );
      final inv2 = InviteService.acceptInvite(
        InviteService.createInvite(
          id: 'inv2',
          senderId: 'user-3',
          receiverId: 'user-2',
        ),
      );

      final pending = InviteService.getPendingForUser([inv1, inv2], 'user-2');
      expect(pending.length, 1);
      expect(pending[0].id, 'inv1');
    });

    test('areConnected returns true for accepted invite between users', () {
      final invite = InviteService.createInvite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
      );
      final accepted = InviteService.acceptInvite(invite);

      expect(
        InviteService.areConnected([accepted], 'user-1', 'user-2'),
        true,
      );
    });

    test('areConnected returns true regardless of invite direction', () {
      final invite = InviteService.createInvite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
      );
      final accepted = InviteService.acceptInvite(invite);

      expect(
        InviteService.areConnected([accepted], 'user-2', 'user-1'),
        true,
      );
    });
  });
}
