import '../models/enums.dart';
import '../models/invite_model.dart';

/// InviteService manages user invitation lifecycle
class InviteService {
  /// Create a new invite
  static Invite createInvite({
    required String id,
    required String senderId,
    required String receiverId,
  }) {
    return Invite(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      status: InviteStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  /// Accept an invite
  static Invite acceptInvite(Invite invite) {
    if (!invite.isPending) {
      throw Exception('Can only accept pending invites');
    }
    return invite.copyWith(
      status: InviteStatus.accepted,
      respondedAt: DateTime.now(),
    );
  }

  /// Decline an invite
  static Invite declineInvite(Invite invite) {
    if (!invite.isPending) {
      throw Exception('Can only decline pending invites');
    }
    return invite.copyWith(
      status: InviteStatus.declined,
      respondedAt: DateTime.now(),
    );
  }

  /// Check if invite is expired (no response within 30 days)
  static bool isExpired(Invite invite) {
    if (!invite.isPending) return false;
    const expirationWindow = Duration(days: 30);
    return DateTime.now().difference(invite.createdAt) > expirationWindow;
  }

  /// Get pending invites for a user
  static List<Invite> getPendingForUser(
    List<Invite> invites,
    String userId,
  ) {
    return invites
        .where((i) => i.receiverId == userId && i.isPending)
        .toList();
  }

  /// Get invites sent by a user
  static List<Invite> getSentByUser(
    List<Invite> invites,
    String userId,
  ) {
    return invites.where((i) => i.senderId == userId).toList();
  }

  /// Get invites received by a user
  static List<Invite> getReceivedByUser(
    List<Invite> invites,
    String userId,
  ) {
    return invites.where((i) => i.receiverId == userId).toList();
  }

  /// Check if users are connected (accepted invite between them)
  static bool areConnected(
    List<Invite> invites,
    String userId1,
    String userId2,
  ) {
    final connection = invites.where(
      (i) =>
          i.isAccepted &&
          ((i.senderId == userId1 && i.receiverId == userId2) ||
              (i.senderId == userId2 && i.receiverId == userId1)),
    );
    return connection.isNotEmpty;
  }
}
