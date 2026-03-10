/// User Invite Data Model
/// Represents a user invitation or friend request

class InviteModel {
  final String inviteId;
  final String senderUserId;
  final String recipientUserId;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;
  
  InviteModel({
    required this.inviteId,
    required this.senderUserId,
    required this.recipientUserId,
    required this.status,
    required this.createdAt,
  });
}
