import 'package:test/test.dart';
import '../../lib/src/models/enums.dart';
import '../../lib/src/models/invite_model.dart';

void main() {
  group('Invite Model', () {
    test('Invite creation with pending status', () {
      final invite = Invite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
        status: InviteStatus.pending,
        createdAt: DateTime.now(),
      );

      expect(invite.isPending, true);
      expect(invite.isAccepted, false);
      expect(invite.isDeclined, false);
    });

    test('Invite with accepted status', () {
      final invite = Invite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
        status: InviteStatus.accepted,
        createdAt: DateTime.now(),
        respondedAt: DateTime.now(),
      );

      expect(invite.isAccepted, true);
      expect(invite.responseTime, isNotNull);
    });

    test('Invite responseTime calculates duration', () {
      final now = DateTime.now();
      final invite = Invite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
        status: InviteStatus.accepted,
        createdAt: now,
        respondedAt: now.add(const Duration(hours: 2)),
      );

      expect(invite.responseTime!.inHours, 2);
    });

    test('Invite copyWith creates new instance', () {
      final original = Invite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
        status: InviteStatus.pending,
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(status: InviteStatus.accepted);

      expect(updated.isPending, false);
      expect(updated.isAccepted, true);
      expect(original.isPending, true);
    });

    test('Invite toJson and fromJson work correctly', () {
      final invite = Invite(
        id: 'invite-1',
        senderId: 'user-1',
        receiverId: 'user-2',
        status: InviteStatus.pending,
        createdAt: DateTime.now(),
      );

      final json = invite.toJson();
      final restored = Invite.fromJson(json);

      expect(restored.id, invite.id);
      expect(restored.senderId, 'user-1');
      expect(restored.isPending, true);
    });
  });
}
