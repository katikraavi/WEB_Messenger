/// Shared enums for messaging system
enum MessageStatus { sent, delivered, read }
enum InviteStatus { pending, accepted, declined }

/// Extension methods for enum string conversion
extension MessageStatusExtension on MessageStatus {
  String toDbString() {
    switch (this) {
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.read:
        return 'read';
    }
  }

  static MessageStatus fromString(String value) {
    switch (value) {
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      default:
        throw ArgumentError('Invalid message status: $value');
    }
  }
}

extension InviteStatusExtension on InviteStatus {
  String toDbString() {
    switch (this) {
      case InviteStatus.pending:
        return 'pending';
      case InviteStatus.accepted:
        return 'accepted';
      case InviteStatus.declined:
        return 'declined';
    }
  }

  static InviteStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return InviteStatus.pending;
      case 'accepted':
        return InviteStatus.accepted;
      case 'declined':
        return InviteStatus.declined;
      default:
        throw ArgumentError('Invalid invite status: $value');
    }
  }
}
