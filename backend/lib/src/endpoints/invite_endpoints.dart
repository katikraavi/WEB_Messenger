import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/enums.dart';
import '../models/invite_model.dart';
import '../services/invite_service.dart';

/// Invite endpoints handler for managing user invitations
class InviteEndpoints {
  static final _uuid = const Uuid();
  static final _invites = <String, Invite>{};

  /// Route configuration
  static Router get router {
    final router = Router();
    router.post('/api/invites', _sendInvite);
    router.get('/api/invites/<inviteId>', _getInvite);
    router.post('/api/invites/<inviteId>/accept', _acceptInvite);
    router.post('/api/invites/<inviteId>/decline', _declineInvite);
    router.get('/api/users/<userId>/invites/pending', _getPendingInvites);
    return router;
  }

  /// Send a new invite
  static Future<Response> _sendInvite(Request request) async {
    try {
      final json = await request.readAsString();
      final body = _parseJson(json);

      final senderId = body['sender_id'] as String?;
      final receiverId = body['receiver_id'] as String?;

      if (senderId == null || receiverId == null) {
        return Response.badRequest(
          body: '{"error": "Missing sender_id or receiver_id"}',
        );
      }

      if (senderId == receiverId) {
        return Response.badRequest(
          body: '{"error": "Cannot invite yourself"}',
        );
      }

      final inviteId = _uuid.v4();
      final invite = InviteService.createInvite(
        id: inviteId,
        senderId: senderId,
        receiverId: receiverId,
      );

      _invites[inviteId] = invite;

      return Response.ok(
        _toJson(invite),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: '{"error": "Failed to send invite"}',
      );
    }
  }

  /// Get invite details
  static Future<Response> _getInvite(Request request, String inviteId) async {
    try {
      final invite = _invites[inviteId];
      if (invite == null) {
        return Response.notFound('{"error": "Invite not found"}');
      }

      return Response.ok(
        _toJson(invite),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Accept an invite
  static Future<Response> _acceptInvite(Request request, String inviteId) async {
    try {
      final invite = _invites[inviteId];
      if (invite == null) {
        return Response.notFound('{"error": "Invite not found"}');
      }

      if (!invite.isPending) {
        return Response(400, body: '{"error": "Invite is not pending"}');
      }

      final accepted = InviteService.acceptInvite(invite);
      _invites[inviteId] = accepted;

      return Response.ok(
        _toJson(accepted),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Decline an invite
  static Future<Response> _declineInvite(Request request, String inviteId) async {
    try {
      final invite = _invites[inviteId];
      if (invite == null) {
        return Response.notFound('{"error": "Invite not found"}');
      }

      if (!invite.isPending) {
        return Response(400, body: '{"error": "Invite is not pending"}');
      }

      final declined = InviteService.declineInvite(invite);
      _invites[inviteId] = declined;

      return Response.ok(
        _toJson(declined),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Get pending invites for a user
  static Future<Response> _getPendingInvites(Request request, String userId) async {
    try {
      final pending = InviteService.getPendingForUser(
        _invites.values.toList(),
        userId,
      );
      final json = _invitesToJson(pending);

      return Response.ok(
        json,
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  static Map<String, dynamic> _parseJson(String json) {
    try {
      return Map<String, dynamic>.from(Uri.splitQueryString(json));
    } catch (_) {
      return {};
    }
  }

  static String _toJson(Invite invite) {
    return '{"id":"${invite.id}","sender_id":"${invite.senderId}","receiver_id":"${invite.receiverId}","status":"${invite.status.toDbString()}","created_at":"${invite.createdAt.toIso8601String()}"}';
  }

  static String _invitesToJson(List<Invite> invites) {
    final items = invites.map(_toJson).join(',');
    return '[$items]';
  }
}
