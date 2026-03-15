import 'package:serverpod/serverpod.dart';
import '../services/invite_service.dart';
import '../services/firebase_notification_service.dart';
import '../models/chat_invite.dart';

/// Invites endpoint
/// 
/// Handles chat invitation management:
/// - POST /api/invites/send - Send a new invitation (FR-003)
/// - GET /api/invites/pending - Get pending invitations (FR-004)
/// - GET /api/invites/sent - Get sent invitations (FR-015)
/// - POST /api/invites/{id}/accept - Accept invitation (FR-005)
/// - POST /api/invites/{id}/decline - Decline invitation (FR-011)
class InvitesEndpoint extends Endpoint {
  late InviteService inviteService;

  @override
  Future<void> initialize(Session session) async {
    super.initialize(session);
    // Initialize service with database connection
    inviteService = InviteService(session.connection);
  }

  /// POST /api/invites/send
  /// Send a new invitation to a user
  /// 
  /// Implementation notes:
  /// - FR-001: No self-invites
  /// - FR-002: No invites to existing chats
  /// - FR-003: Create invite record
  /// - T048: Send push notification to recipient
  /// 
  /// Returns: ChatInvite (201)
  /// Errors: 400 (validation), 401 (auth), 404 (not found), 409 (duplicate)
  Future<ChatInvite> sendInvite(String recipientId) async {
    // Auth check (FR-010): User must be authenticated
    final userId = session.userId;
    if (userId == null) {
      throw ForceFailure(HttpStatus.unauthorized, 'Authentication required');
    }

    try {
      final invite = await inviteService.sendInvite(
        senderId: userId,
        recipientId: recipientId,
      );
      
      // T048: Send push notification to recipient
      try {
        final notificationService = FirebaseNotificationService();
        // Get sender name from database for notification
        // In production, this would fetch the actual sender name
        final senderName = 'User'; // TODO: Fetch from users table
        
        await notificationService.sendInvitationNotification(
          recipientUserId: recipientId,
          senderName: senderName,
          inviteId: invite.id,
        );
      } catch (e) {
        // Log notification error but don't fail the request
        print('[Notification Error] Failed to send push notification: $e');
      }
      
      return invite;
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('already exists')) {
        throw ForceFailure(HttpStatus.conflict, 'Pending invitation already exists');
      }
      if (msg.contains('already have a chat') || msg.contains('active chat')) {
        throw ForceFailure(HttpStatus.badRequest, 'Users already have a chat');
      }
      if (msg.contains('yourself')) {
        throw ForceFailure(HttpStatus.badRequest, 'Cannot invite yourself');
      }
      if (msg.contains('not found')) {
        throw ForceFailure(HttpStatus.notFound, 'User not found');
      }
      throw ForceFailure(HttpStatus.badRequest, e.toString());
    }
  }

  /// GET /api/invites/pending
  /// Get pending invitations for the current user
  /// 
  /// Returns: List<ChatInvite> (200)
  /// Errors: 401 (auth)
  Future<List<ChatInvite>> getPendingInvites() async {
    final userId = session.userId;
    if (userId == null) {
      throw ForceFailure(HttpStatus.unauthorized, 'Authentication required');
    }

    final result = await inviteService.getPendingInvites(userId);
    return result
        .map((row) => ChatInvite(
              id: row['id'] as String,
              senderId: row['sender_id'] as String,
              recipientId: row['recipient_id'] as String,
              status: row['status'] as String,
              createdAt: row['created_at'] as DateTime,
              updatedAt: row['updated_at'] as DateTime,
              deletedAt: row['deleted_at'] as DateTime?,
            ))
        .toList();
  }

  /// GET /api/invites/sent
  /// Get sent invitations for the current user
  /// 
  /// Returns: List<ChatInvite> (200)
  /// Errors: 401 (auth)
  Future<List<ChatInvite>> getSentInvites() async {
    final userId = session.userId;
    if (userId == null) {
      throw ForceFailure(HttpStatus.unauthorized, 'Authentication required');
    }

    final result = await inviteService.getSentInvites(userId);
    return result
        .map((row) => ChatInvite(
              id: row['id'] as String,
              senderId: row['sender_id'] as String,
              recipientId: row['recipient_id'] as String,
              status: row['status'] as String,
              createdAt: row['created_at'] as DateTime,
              updatedAt: row['updated_at'] as DateTime,
              deletedAt: row['deleted_at'] as DateTime?,
            ))
        .toList();
  }

  /// GET /api/invites/pending/count
  /// Get count of pending invitations (for badge)
  /// 
  /// Returns: int (200)
  /// Errors: 401 (auth)
  Future<int> getPendingInviteCount() async {
    final userId = session.userId;
    if (userId == null) {
      throw ForceFailure(HttpStatus.unauthorized, 'Authentication required');
    }

    return await inviteService.getPendingInviteCount(userId);
  }

  /// POST /api/invites/{id}/accept
  /// Accept an invitation
  /// 
  /// Implementation notes:
  /// - FR-005: Create chat on accept
  /// - FR-006: Add both users to chat
  /// - FR-007: Update invite status
  /// - FR-008: Remove from pending
  /// 
  /// Returns: ChatInvite (200)
  /// Errors: 400 (validation), 401 (auth), 404 (not found)
  Future<ChatInvite> acceptInvite(String inviteId) async {
    final userId = session.userId;
    if (userId == null) {
      throw ForceFailure(HttpStatus.unauthorized, 'Authentication required');
    }

    try {
      final invite = await inviteService.acceptInvite(inviteId);
      
      // Verify current user is the recipient
      if (invite.recipientId != userId) {
        throw ForceFailure(HttpStatus.forbidden, 'Not authorized to accept this invite');
      }

      return invite;
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('not found')) {
        throw ForceFailure(HttpStatus.notFound, 'Invitation not found');
      }
      if (msg.contains('no longer pending')) {
        throw ForceFailure(HttpStatus.badRequest, 'Invitation  is no longer pending');
      }
      throw ForceFailure(HttpStatus.badRequest, e.toString());
    }
  }

  /// POST /api/invites/{id}/decline
  /// Decline an invitation
  /// 
  /// Implementation notes:
  /// - FR-011: Allow decline without block
  /// - FR-008: Remove from pending
  /// 
  /// Returns: ChatInvite (200)
  /// Errors: 400 (validation), 401 (auth), 404 (not found)
  Future<ChatInvite> declineInvite(String inviteId) async {
    final userId = session.userId;
    if (userId == null) {
      throw ForceFailure(HttpStatus.unauthorized, 'Authentication required');
    }

    try {
      final invite = await inviteService.declineInvite(inviteId);
      
      // Verify current user is the recipient
      if (invite.recipientId != userId) {
        throw ForceFailure(HttpStatus.forbidden, 'Not authorized to decline this invite');
      }

      return invite;
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('not found')) {
        throw ForceFailure(HttpStatus.notFound, 'Invitation not found');
      }
      if (msg.contains('no longer pending')) {
        throw ForceFailure(HttpStatus.badRequest, 'Invitation is no longer pending');
      }
      throw ForceFailure(HttpStatus.badRequest, e.toString());
    }
  }
}
