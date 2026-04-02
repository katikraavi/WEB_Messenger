part of '../../server.dart';

Handler _createHandler(
  TokenService tokenService,
  EmailService emailService,
  RateLimitService rateLimitService,
  Connection database,
  EncryptionService encryptionService,
  VerificationService verificationService,
  PasswordResetService passwordResetService,
  PollService pollService,
) {
  return (Request request) async {
    try {
      var path = request.url.path;
      final method = request.method;

      if (path.startsWith('/')) {
        path = path.substring(1);
      }
      if (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }

      if (path.startsWith('api/auth/') || path == 'api/auth') {
        path = path.replaceFirst('api/', '');
      }
      if (path.startsWith('api/ws/') || path == 'api/ws') {
        path = path.replaceFirst('api/', '');
      }
      if (path.startsWith('api/profile/') || path == 'api/profile') {
        path = path.replaceFirst('api/', '');
      }
      if (path.startsWith('api/search/') || path == 'api/search') {
        path = path.replaceFirst('api/', '');
      }

      if (_verboseBackendLogs) {
        print(
            '[DEBUG] Received request: $method /$path (raw: ${request.url.path})');
      }

      // --- Public / probe endpoints ---

      if (path.isEmpty && method == 'GET') {
        return Response.ok(
          jsonEncode({
            'service': 'messenger-backend',
            'status': 'healthy',
            'environment':
                Platform.environment['SERVERPOD_ENV'] ?? 'development',
            'timestamp': DateTime.now().toIso8601String(),
            'endpoints': {'health': '/health', 'schema': '/schema'},
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (path.isEmpty && method == 'HEAD') {
        return Response.ok('', headers: {'Content-Type': 'application/json'});
      }

      if (path.startsWith('uploads/')) {
        return _serveStaticFile(request, path);
      }

      if (path == 'health' && method == 'GET') {
        return Response.ok(
          jsonEncode({
            'status': 'healthy',
            'timestamp': DateTime.now().toIso8601String()
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (path == 'health' && method == 'HEAD') {
        return Response.ok('', headers: {'Content-Type': 'application/json'});
      }

      if (path == 'schema' && method == 'GET') {
        return Response.ok(
          jsonEncode({
            'status':
                'Schema tables created via migrations: users, chats, chat_members, messages, invites, verification_token, password_reset_token, password_reset_attempt'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Render/Neon can occasionally drop long-lived idle DB connections.
      // Before handling DB-backed routes, ensure connection is alive.
      // Skip for WebSocket upgrades - they have their own connection management
      final isWebSocketUpgrade = request.headers['upgrade']?.toLowerCase() == 'websocket';
      final requiresDatabase =
          !isWebSocketUpgrade &&
          !(path.isEmpty ||
              path == 'health' ||
              path == 'schema' ||
              path.startsWith('uploads/'));
      if (requiresDatabase) {
        final ready = await _ensureDatabaseConnection(database);
        if (!ready) {
          return Response(
            503,
            body: jsonEncode({
              'error': 'Database temporarily unavailable. Please retry shortly.'
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      if (path == 'reset' && method == 'GET') {
        return _handlePasswordResetPage(request);
      }

      // --- Auth ---

      if (path == 'auth/register' && method == 'POST') {
        return await _handleRegister(
            request, database, tokenService, emailService, verificationService);
      }

      if (path == 'auth/login' && method == 'POST') {
        return await _handleLogin(request, database, tokenService);
      }

      if (path == 'auth/me' && method == 'GET') {
        return await _handleValidateSession(request, database, tokenService);
      }

      if (path == 'auth/logout' && method == 'POST') {
        return await _handleLogout(request, database, tokenService);
      }

      if (path == 'api/admin/users/delete-preview' && method == 'POST') {
        return await _handleAdminDeletePreview(request, database);
      }

      if (path == 'api/admin/users/delete' && method == 'POST') {
        return await _handleAdminDeleteUser(request, database);
      }

      if (path == 'auth/sessions' && method == 'GET') {
        return await _handleListDeviceSessions(request, database, tokenService);
      }

      if (path.startsWith('auth/sessions/') && method == 'DELETE') {
        final deviceId = path.replaceFirst('auth/sessions/', '');
        return await _handleRevokeDeviceSession(
            request, database, tokenService, deviceId);
      }

      // --- Groups ---

      if (path == 'api/groups' && method == 'POST') {
        return await _handleCreateGroup(request, database, encryptionService);
      }

      if (path == 'api/groups' && method == 'GET') {
        return await _handleListGroups(request, database, encryptionService);
      }

      if (path.startsWith('api/groups/') &&
          path.endsWith('/invite') &&
          method == 'POST') {
        final groupId =
            path.replaceFirst('api/groups/', '').replaceFirst('/invite', '');
        return await _handleSendGroupInvite(
            request, database, encryptionService, groupId);
      }

      if (path.startsWith('api/groups/') &&
          path.endsWith('/members') &&
          method == 'GET') {
        final groupId =
            path.replaceFirst('api/groups/', '').replaceFirst('/members', '');
        return await _handleListGroupMembers(
            request, database, encryptionService, groupId);
      }

      if (path.startsWith('api/groups/') &&
          path.endsWith('/invites') &&
          method == 'GET') {
        final groupId =
            path.replaceFirst('api/groups/', '').replaceFirst('/invites', '');
        return await _handleListGroupSentInvites(
            request, database, encryptionService, groupId);
      }

      if (path.startsWith('api/groups/') &&
          path.endsWith('/leave') &&
          method == 'DELETE') {
        final groupId =
            path.replaceFirst('api/groups/', '').replaceFirst('/leave', '');
        return await _handleLeaveGroup(
            request, database, encryptionService, groupId);
      }

      if (path.startsWith('api/groups/invites/') &&
          path.endsWith('/accept') &&
          method == 'PATCH') {
        final inviteId = path
            .replaceFirst('api/groups/invites/', '')
            .replaceFirst('/accept', '');
        return await _handleAcceptGroupInvite(
            request, database, encryptionService, inviteId);
      }

      if (path.startsWith('api/groups/invites/') &&
          path.endsWith('/decline') &&
          method == 'PATCH') {
        final inviteId = path
            .replaceFirst('api/groups/invites/', '')
            .replaceFirst('/decline', '');
        return await _handleDeclineGroupInvite(
            request, database, encryptionService, inviteId);
      }

      if (path.startsWith('api/groups/invites/') && method == 'DELETE') {
        final inviteId = path.replaceFirst('api/groups/invites/', '');
        return await _handleDeleteGroupInvite(
            request, database, encryptionService, inviteId);
      }

      if (path == 'api/groups/invites/pending' && method == 'GET') {
        return await _handlePendingGroupInvites(
            request, database, encryptionService);
      }

      if (path.startsWith('api/groups/') && method == 'GET') {
        final groupId = path.replaceFirst('api/groups/', '');
        return await _handleGetGroupDetails(
            request, database, encryptionService, groupId);
      }

      // --- Email verification & password reset ---

      if (path == 'auth/verify-email/send' && method == 'POST') {
        return await sendVerificationEmail(
            request, tokenService, emailService, rateLimitService,
            verificationService);
      }

      if (path == 'auth/verify-email/confirm' && method == 'POST') {
        return await verifyEmailToken(request, tokenService, verificationService);
      }

      if (path == 'auth/password-reset/request' && method == 'POST') {
        return await requestPasswordReset(
            request, emailService, rateLimitService, passwordResetService);
      }

      if (path == 'auth/password-reset/confirm' && method == 'POST') {
        return await confirmPasswordReset(request, passwordResetService);
      }

      // --- Profile ---

      if (path.startsWith('profile/view/') && method == 'GET') {
        final userId = path.replaceFirst('profile/view/', '');
        return await profileEndpoint.getProfile(request, userId);
      }

      if (path == 'profile/edit' && method == 'PATCH') {
        return await profileEndpoint.updateProfile(request);
      }

      if (path == 'profile/picture/upload' && method == 'POST') {
        return await profileEndpoint.uploadProfilePicture(request);
      }

      if (path == 'profile/picture/url' && method == 'POST') {
        return await profileEndpoint.updateProfilePictureUrl(request);
      }

      if (path == 'profile/picture' && method == 'DELETE') {
        return await profileEndpoint.deleteProfilePicture(request);
      }

      // --- Search ---

      if (path == 'search/username' && method == 'GET') {
        try {
          return await _handleSearchByUsername(request, database);
        } catch (e) {
          return Response.internalServerError(
            body: jsonEncode({'error': 'Search service error: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      if (path == 'search/email' && method == 'GET') {
        try {
          return await _handleSearchByEmail(request, database);
        } catch (e) {
          return Response.internalServerError(
            body: jsonEncode({'error': 'Search service error: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      if (path == 'api/messages/search' && method == 'GET') {
        return await _handleMessageSearch(request, database);
      }

      // --- Invites ---

      if (path.startsWith('api/users/') &&
          path.contains('/invites/pending/count') &&
          method == 'GET') {
        final parts = path.split('/');
        final idx = parts.indexOf('users') + 1;
        final userId =
            idx > 0 && idx < parts.length ? parts[idx] : null;
        if (userId == null) {
          return Response(400,
              body: jsonEncode({'error': 'User ID not found in path'}),
              headers: {'Content-Type': 'application/json'});
        }
        return await _handleInvitePendingCount(request, database, userId);
      }

      if (path.startsWith('api/users/') &&
          path.contains('/invites/pending') &&
          method == 'GET') {
        final parts = path.split('/');
        final idx = parts.indexOf('users') + 1;
        final userId =
            idx > 0 && idx < parts.length ? parts[idx] : null;
        if (userId == null) {
          return Response(400,
              body: jsonEncode({'error': 'User ID not found in path'}),
              headers: {'Content-Type': 'application/json'});
        }
        return await _handleInvitePending(request, database, userId);
      }

      if (path.startsWith('api/users/') &&
          path.contains('/invites/sent') &&
          method == 'GET') {
        final parts = path.split('/');
        final idx = parts.indexOf('users') + 1;
        final userId =
            idx > 0 && idx < parts.length ? parts[idx] : null;
        if (userId == null) {
          return Response(400,
              body: jsonEncode({'error': 'User ID not found in path'}),
              headers: {'Content-Type': 'application/json'});
        }
        return await _handleInviteSent(request, database, userId);
      }

      if (path == 'api/invites' && method == 'POST') {
        return await _handleSendInvite(request, database);
      }

      if (path.contains('api/invites/') &&
          path.endsWith('/accept') &&
          method == 'POST') {
        final inviteId = path
            .replaceFirst('api/invites/', '')
            .replaceFirst('/accept', '');
        return await _handleAcceptInvite(request, database, inviteId);
      }

      if (path.contains('api/invites/') &&
          path.endsWith('/decline') &&
          method == 'POST') {
        final inviteId = path
            .replaceFirst('api/invites/', '')
            .replaceFirst('/decline', '');
        return await _handleDeclineInvite(request, database, inviteId);
      }

      if (path.contains('api/invites/') &&
          path.endsWith('/cancel') &&
          method == 'POST') {
        final inviteId = path
            .replaceFirst('api/invites/', '')
            .replaceFirst('/cancel', '');
        return await _handleCancelInvite(request, database, inviteId);
      }

      // --- Chats (delete must be before other /api/chats/* routes) ---

      if (path.startsWith('api/chats/') &&
          !path.contains('/messages') &&
          !path.contains('/notification-settings') &&
          !path.contains('/archive') &&
          !path.contains('/unarchive') &&
          method == 'DELETE') {
        final chatId = path.replaceFirst('api/chats/', '').split('/').first;
        return await _handleDeleteChat(request, database, chatId);
      }

      if (path == 'ws/messages' && method == 'GET') {
        final wsHandler =
            WebSocketHandler.createWebSocketHandler(database, request: request);
        return await wsHandler(request);
      }

      if (path == 'api/chats' && method == 'GET') {
        return await _handleGetChats(request, database, encryptionService);
      }

      if (path == 'api/chats/archived' && method == 'GET') {
        return await _handleGetArchivedChats(request, database, encryptionService);
      }

      if (path.startsWith('api/chats/') &&
          path.endsWith('/messages') &&
          method == 'GET') {
        final chatId =
            path.replaceFirst('api/chats/', '').replaceFirst('/messages', '');
        return await _handleGetChatMessages(
            request, database, encryptionService, chatId);
      }

      if (path.startsWith('api/chats/') &&
          path.endsWith('/messages') &&
          method == 'POST') {
        try {
          final chatId =
              path.replaceFirst('api/chats/', '').replaceFirst('/messages', '');
          return await MessageHandlers.sendMessage(request, chatId, database);
        } on AuthException {
          return Response(401,
              body: jsonEncode({'error': 'Invalid token'}),
              headers: {'Content-Type': 'application/json'});
        } catch (e) {
          print('[MessageHandler] ❌ Error sending message: $e');
          return Response(500,
              body: jsonEncode({'error': 'Failed to send message: $e'}),
              headers: {'Content-Type': 'application/json'});
        }
      }

      if (path.startsWith('api/chats/') &&
          path.contains('/messages/') &&
          !path.endsWith('/status') &&
          method == 'PUT') {
        try {
          final parts = path.split('/');
          if (parts.length == 5 &&
              parts[0] == 'api' &&
              parts[1] == 'chats' &&
              parts[3] == 'messages') {
            return await MessageHandlers.editMessage(
                request, parts[2], parts[4], database);
          }
        } on AuthException {
          return Response(401,
              body: jsonEncode({'error': 'Invalid token'}),
              headers: {'Content-Type': 'application/json'});
        } catch (e) {
          print('[MessageHandler] ❌ Error editing message: $e');
          return Response(500,
              body: jsonEncode({'error': 'Failed to edit message: $e'}),
              headers: {'Content-Type': 'application/json'});
        }
      }

      if (path.startsWith('api/chats/') &&
          path.contains('/messages/') &&
          !path.endsWith('/status') &&
          method == 'DELETE') {
        try {
          final parts = path.split('/');
          if (parts.length >= 5 &&
              parts[0] == 'api' &&
              parts[1] == 'chats' &&
              parts[3] == 'messages') {
            return await MessageHandlers.deleteMessage(
                request, parts[2], parts[4], database);
          }
        } on AuthException {
          return Response(401,
              body: jsonEncode({'error': 'Invalid token'}),
              headers: {'Content-Type': 'application/json'});
        } catch (e) {
          print('[MessageHandler] ❌ Error deleting message: $e');
          return Response(500,
              body: jsonEncode({'error': 'Failed to delete message: $e'}),
              headers: {'Content-Type': 'application/json'});
        }
      }

      if (path.startsWith('api/chats/') &&
          path.endsWith('/messages/status') &&
          method == 'PUT') {
        try {
          final parts = path.split('/');
          if (parts.length >= 4 &&
              parts[0] == 'api' &&
              parts[1] == 'chats' &&
              parts[3] == 'messages') {
            return await MessageHandlers.updateMessageStatus(
                request, parts[2], database);
          }
        } on AuthException {
          return Response(401,
              body: jsonEncode({'error': 'Invalid token'}),
              headers: {'Content-Type': 'application/json'});
        } catch (e) {
          print('[MessageHandler] ❌ Error updating message status: $e');
          return Response(500,
              body: jsonEncode(
                  {'error': 'Failed to update message status: $e'}),
              headers: {'Content-Type': 'application/json'});
        }
      }

      // --- Media ---

      if (path == 'api/media/upload' && method == 'POST') {
        try {
          return await MediaHandlers.uploadMedia(request, database);
        } on AuthException {
          return Response(401,
              body: jsonEncode({'error': 'Invalid token'}),
              headers: {'Content-Type': 'application/json'});
        } catch (e) {
          print('[MediaHandler] ❌ Error uploading media: $e');
          return Response(500,
              body: jsonEncode({'error': 'Failed to upload media: $e'}),
              headers: {'Content-Type': 'application/json'});
        }
      }

      if (path.startsWith('api/media/') &&
          path.contains('/download') &&
          method == 'GET') {
        try {
          final parts = path.split('/');
          if (parts.length >= 4 &&
              parts[0] == 'api' &&
              parts[1] == 'media' &&
              parts[3] == 'download') {
            return await MediaHandlers.downloadMedia(request, parts[2]);
          }
        } on AuthException {
          return Response(401,
              body: jsonEncode({'error': 'Invalid token'}),
              headers: {'Content-Type': 'application/json'});
        } catch (e) {
          print('[MediaHandler] ❌ Error downloading media: $e');
          return Response(500,
              body: jsonEncode({'error': 'Failed to download media: $e'}),
              headers: {'Content-Type': 'application/json'});
        }
      }

      if (path.startsWith('api/messages/') &&
          path.contains('/attach-media') &&
          method == 'PUT') {
        try {
          final parts = path.split('/');
          if (parts.length >= 4 &&
              parts[0] == 'api' &&
              parts[1] == 'messages' &&
              parts[3] == 'attach-media') {
            return await MediaHandlers.attachMediaToMessage(
                request, parts[2], database);
          }
        } on AuthException {
          return Response(401,
              body: jsonEncode({'error': 'Invalid token'}),
              headers: {'Content-Type': 'application/json'});
        } catch (e) {
          print('[MediaHandler] ❌ Error attaching media: $e');
          return Response(500,
              body: jsonEncode({'error': 'Failed to attach media: $e'}),
              headers: {'Content-Type': 'application/json'});
        }
      }

      // --- Notifications ---

      if (path == 'api/notifications/device-token' && method == 'POST') {
        return await _handleRegisterDeviceToken(request, database);
      }

      if (path == 'api/notifications/muted-chats' && method == 'GET') {
        return await _handleGetMutedChats(request, database);
      }

      if (path.startsWith('api/chats/') &&
          path.endsWith('/notification-settings') &&
          method == 'GET') {
        final chatId = path
            .replaceFirst('api/chats/', '')
            .replaceFirst('/notification-settings', '');
        return await _handleGetChatNotificationSettings(
            request, database, chatId);
      }

      if (path.startsWith('api/chats/') &&
          path.endsWith('/notification-settings') &&
          method == 'PUT') {
        final chatId = path
            .replaceFirst('api/chats/', '')
            .replaceFirst('/notification-settings', '');
        return await _handleSetChatNotificationSettings(
            request, database, chatId);
      }

      if (path.startsWith('api/chats/') &&
          path.endsWith('/archive') &&
          method == 'PUT') {
        final chatId =
            path.replaceFirst('api/chats/', '').replaceFirst('/archive', '');
        return await _handleArchiveChat(request, database, chatId);
      }

      if (path.startsWith('api/chats/') &&
          path.endsWith('/unarchive') &&
          method == 'PUT') {
        final chatId =
            path.replaceFirst('api/chats/', '').replaceFirst('/unarchive', '');
        return await _handleUnarchiveChat(request, database, chatId);
      }

      // --- Polls ---

      if (path == 'api/polls' && method == 'POST') {
        return await _handleCreatePoll(request, database, pollService);
      }

      if (path.startsWith('api/polls/') &&
          method == 'GET' &&
          !path.contains('/vote') &&
          !path.contains('/close')) {
        final pollId = path.replaceFirst('api/polls/', '');
        return await _handleGetPoll(request, database, pollService, pollId);
      }

      if (path.startsWith('api/polls/') &&
          path.endsWith('/vote') &&
          method == 'POST') {
        final pollId =
            path.replaceFirst('api/polls/', '').replaceFirst('/vote', '');
        return await _handleVotePoll(request, database, pollService, pollId);
      }

      if (path.startsWith('api/polls/') &&
          path.endsWith('/vote') &&
          method == 'DELETE') {
        final pollId =
            path.replaceFirst('api/polls/', '').replaceFirst('/vote', '');
        return await _handleRetractVote(request, database, pollService, pollId);
      }

      if (path.startsWith('api/polls/') &&
          path.endsWith('/close') &&
          method == 'POST') {
        final pollId =
            path.replaceFirst('api/polls/', '').replaceFirst('/close', '');
        return await _handleClosePoll(request, database, pollService, pollId);
      }

      return Response.notFound(
        jsonEncode({'error': 'Endpoint not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      print('[ERROR] Request handler error: $e');
      print('[ERROR] Stack: $st');
      return Response.internalServerError(
        body: jsonEncode(
            {'error': 'Internal server error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  };
}

Response _handlePasswordResetPage(Request request) {
  final token = request.url.queryParameters['token'] ?? '';
  if (token.isEmpty) {
    return Response.badRequest(
      body: 'Missing token',
      headers: {'Content-Type': 'text/plain; charset=utf-8'},
    );
  }

  final html = '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Reset Password</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f5f7fb; margin: 0; }
    .card { max-width: 420px; margin: 48px auto; background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 24px; }
    h1 { margin: 0 0 12px; font-size: 24px; }
    p { color: #475569; margin: 0 0 20px; }
    label { display: block; font-weight: 600; margin-bottom: 8px; }
    input { width: 100%; box-sizing: border-box; padding: 10px 12px; border: 1px solid #cbd5e1; border-radius: 8px; margin-bottom: 12px; }
    button { width: 100%; padding: 11px 12px; background: #2563eb; color: #fff; border: 0; border-radius: 8px; font-weight: 600; cursor: pointer; }
    button:disabled { opacity: 0.7; cursor: not-allowed; }
    .msg { margin-top: 14px; font-size: 14px; }
    .err { color: #b91c1c; }
    .ok { color: #166534; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Reset your password</h1>
    <p>Enter your new password below.</p>
    <label for="pw">New password</label>
    <input id="pw" type="password" autocomplete="new-password" placeholder="At least 8 characters" />
    <label for="cpw">Confirm password</label>
    <input id="cpw" type="password" autocomplete="new-password" placeholder="Repeat password" />
    <button id="submit">Update Password</button>
    <div id="msg" class="msg"></div>
  </div>

  <script>
    const token = ${jsonEncode(token)};
    const submit = document.getElementById('submit');
    const msg = document.getElementById('msg');
    const pw = document.getElementById('pw');
    const cpw = document.getElementById('cpw');

    function show(text, ok) {
      msg.textContent = text;
      msg.className = 'msg ' + (ok ? 'ok' : 'err');
    }

    submit.addEventListener('click', async () => {
      if (!pw.value) return show('Please enter a new password.', false);
      if (pw.value !== cpw.value) return show('Passwords do not match.', false);

      submit.disabled = true;
      show('Updating password...', true);

      try {
        const res = await fetch('/api/auth/password-reset/confirm', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token, newPassword: pw.value }),
        });

        const data = await res.json().catch(() => ({}));
        if (res.ok) {
          show(data.message || 'Password reset successfully. You can now log in.', true);
          pw.value = '';
          cpw.value = '';
        } else {
          show(data.error || 'Failed to reset password.', false);
        }
      } catch (_) {
        show('Network error while resetting password.', false);
      } finally {
        submit.disabled = false;
      }
    });
  </script>
</body>
</html>
''';

  return Response.ok(
    html,
    headers: {'Content-Type': 'text/html; charset=utf-8'},
  );
}
