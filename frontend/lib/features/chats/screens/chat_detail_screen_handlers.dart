part of 'chat_detail_screen.dart';

extension _ChatDetailScreenStateHandlers on _ChatDetailScreenState {
  void _sendTypingEvent(String eventType) {
    try {
      if (eventType == 'typing.start') {
        _webSocketNotifier.sendTyping(widget.chatId);
      } else if (eventType == 'typing.stop') {
        _webSocketNotifier.stopTyping(widget.chatId);
      }

    } catch (e) {
      AppExceptionLogger.log(e, context: 'ChatDetailScreen._sendTypingEvent');
    }
  }

  /// Scroll to bottom of message list (newest messages)
  void _scrollToBottom() {
    // Schedule scroll after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Handle message retry (T025 error state)
  Future<void> _handleRetry(
    Message failedMessage,
    String token,
    String currentUserId,
  ) async {
    // Only allow retry for messages with errors
    if (failedMessage.error == null) {
      return;
    }

    await ref
        .read(sendMessageProvider.notifier)
        .retryMessage(
          failedMessage: failedMessage,
          token: token,
          currentUserId: currentUserId,
        );
    _scrollToBottom();
  }

  /// Show context menu for message edit/delete (T052, T061)
  void _showMessageContextMenu(Message message, String token) {
    // Don't show menu for already deleted messages
    if (message.isDeleted) {
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditMessageDialog(message, token);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmationDialog(message, token);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show edit message dialog (T052, T053)
  void _showEditMessageDialog(Message message, String token) {
    showDialog(
      context: context,
      builder: (context) => EditMessageDialog(
        messageId: message.id,
        currentContent: message.getDisplayContent(),
        onSave: (newContent) {
          _handleEditMessage(message, newContent, token);
        },
      ),
    );
  }

  /// Show delete confirmation dialog (T061)
  void _showDeleteConfirmationDialog(Message message, String token) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              unawaited(_handleDeleteMessage(message, token));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Handle message edit (T055)
  Future<void> _handleEditMessage(
    Message message,
    String newContent,
    String token,
  ) async {
    try {
      final encryptedContent = MessageEncryptionService.encryptMessage(
        newContent,
      );
      final editedMessage = await ChatApiService(baseUrl: _backendBaseUrl)
          .editMessage(
            token: token,
            chatId: widget.chatId,
            messageId: message.id,
            newEncryptedContent: encryptedContent,
          );
      final decryptedMessage = await MessageEncryptionService.decryptMessage(
        editedMessage,
      );

      _localMessagesNotifier?.upsertMessage(decryptedMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message edited successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to edit: $e')));
    }
  }

  /// Handle message delete (T062)
  Future<void> _handleDeleteMessage(Message message, String token) async {
    try {
      await ChatApiService(baseUrl: _backendBaseUrl).deleteMessage(
        token: token,
        chatId: widget.chatId,
        messageId: message.id,
      );

      _localMessagesNotifier?.markMessageDeleted(message.id);


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  /// Handle image attachment (T079)
  Future<void> _handleImageAttachment(String token) async {
    try {

      // Pick image from device
      final pickedMedia = await MediaPickerService.pickImage();
      if (pickedMedia == null) {
        return;
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading image...'),
          duration: Duration(seconds: 30),
        ),
      );

      // Upload media to backend
      final uploadService = MediaUploadService();
      final uploadedMedia = await uploadService.uploadMedia(
        pickedMedia: pickedMedia,
        token: token,
      );


      final chatApiService = ChatApiService(baseUrl: 'http://localhost:8081');
      final mediaPath = '/uploads/media/${uploadedMedia.fileName}';
      final sentMessage = await chatApiService.sendMessage(
        token: token,
        chatId: widget.chatId,
        encryptedContent: base64Encode(utf8.encode('[Image]')),
        mediaUrl: mediaPath,
        mediaType: uploadedMedia.mimeType,
      );
      final decryptedMessage = await MessageEncryptionService.decryptMessage(
        sentMessage,
      );

      ref
          .read(
            localMessagesProvider((
              chatId: widget.chatId,
              token: token,
              currentUserId: currentUserIdFromContext(),
            )).notifier,
          )
          .upsertMessage(decryptedMessage);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Image sent: ${uploadedMedia.originalName ?? uploadedMedia.fileName}',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    }
  }

  /// Handle video attachment (T080)
  Future<void> _handleVideoAttachment(String token) async {
    try {

      // Pick video from device
      final pickedMedia = await MediaPickerService.pickVideo();
      if (pickedMedia == null) {
        return;
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading video...'),
          duration: Duration(seconds: 60),
        ),
      );

      // Upload media to backend
      final uploadService = MediaUploadService();
      final uploadedMedia = await uploadService.uploadMedia(
        pickedMedia: pickedMedia,
        token: token,
      );


      final chatApiService = ChatApiService(baseUrl: 'http://localhost:8081');
      final mediaPath = '/uploads/media/${uploadedMedia.fileName}';
      final sentMessage = await chatApiService.sendMessage(
        token: token,
        chatId: widget.chatId,
        encryptedContent: base64Encode(utf8.encode('[Video]')),
        mediaUrl: mediaPath,
        mediaType: uploadedMedia.mimeType,
      );
      final decryptedMessage = await MessageEncryptionService.decryptMessage(
        sentMessage,
      );

      ref
          .read(
            localMessagesProvider((
              chatId: widget.chatId,
              token: token,
              currentUserId: currentUserIdFromContext(),
            )).notifier,
          )
          .upsertMessage(decryptedMessage);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Video sent: ${uploadedMedia.originalName ?? uploadedMedia.fileName}',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload video: $e')));
    }
  }

  Future<void> _handleAudioRecordingTap(String token) async {
    final recordingService = AudioRecordingService.instance;

    try {
      if (!recordingService.isRecording) {
        await recordingService.startRecording();
        if (!mounted) {
          return;
        }
        setState(() {
          _isRecordingAudio = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording audio... tap the mic again to send'),
          ),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _isRecordingAudio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading audio...'),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final pickedMedia = await recordingService.stopRecording();
      final uploadService = MediaUploadService();
      final uploadedMedia = await uploadService.uploadMedia(
        pickedMedia: pickedMedia,
        token: token,
      );

      final chatApiService = ChatApiService(baseUrl: 'http://localhost:8081');
      final mediaPath = '/uploads/media/${uploadedMedia.fileName}';
      final sentMessage = await chatApiService.sendMessage(
        token: token,
        chatId: widget.chatId,
        encryptedContent: base64Encode(utf8.encode('[Audio]')),
        mediaUrl: mediaPath,
        mediaType: uploadedMedia.mimeType,
      );
      final decryptedMessage = await MessageEncryptionService.decryptMessage(
        sentMessage,
      );

      ref
          .read(
            localMessagesProvider((
              chatId: widget.chatId,
              token: token,
              currentUserId: currentUserIdFromContext(),
            )).notifier,
          )
          .upsertMessage(decryptedMessage);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Audio message sent')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecordingAudio = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to record audio: $e')));
      }
    }
  }

  Future<void> _loadNotificationSettings(String token) async {
    try {
      final isMuted = await ChatNotificationSettingsService.instance
          .fetchMuteStatus(token: token, chatId: widget.chatId);
      if (!mounted) {
        return;
      }
      setState(() {
        _isChatMuted = isMuted;
        _notificationSettingsLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationSettingsLoaded = true;
      });
    }
  }

  Future<void> _toggleChatMute(String token) async {
    final nextValue = !_isChatMuted;
    try {
      await ChatNotificationSettingsService.instance.setMuted(
        token: token,
        chatId: widget.chatId,
        isMuted: nextValue,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isChatMuted = nextValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue
                ? 'Chat notifications muted'
                : 'Chat notifications unmuted',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update notifications: $e')),
      );
    }
  }

  String currentUserIdFromContext() {
    final authProvider = provider_pkg.Provider.of<auth.AuthProvider>(
      context,
      listen: false,
    );
    return authProvider.user!.userId;
  }

}
