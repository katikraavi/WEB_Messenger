import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../providers/user_profile_provider.dart';
import '../providers/messages_provider.dart';
import '../services/message_encryption_service.dart';
import 'user_avatar_widget.dart';
import '../screens/chat_detail_screen.dart';

class ChatListTileConsumer extends ConsumerWidget {
  final String otherUserId;
  final String token;
  final Chat chat;
  final String currentUserId;
  final String? lastMessage;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const ChatListTileConsumer({
    super.key,
    required this.otherUserId,
    required this.token,
    required this.chat,
    required this.currentUserId,
    this.lastMessage,
    this.onArchive,
    this.onDelete,
  });

  String _truncatePreview(String preview) {
    return preview.length > 50 ? '${preview.substring(0, 50)}...' : preview;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    if (now.difference(timestamp).inDays == 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(timestamp).inDays == 1) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String _buildGroupTitle(Chat chat) {
    final groupName = chat.displayName?.trim() ?? '';
    if (groupName.isNotEmpty && groupName.toLowerCase() != 'group') {
      return groupName;
    }

    final participants = (chat.participantNames ?? const <String>[])
        .where((name) => name.trim().isNotEmpty)
        .toList();
    if (participants.isNotEmpty) {
      return participants.join(', ');
    }

    return 'Group';
  }

  Widget _wrapTile(BuildContext context, Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4ECF7)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (chat.isGroup) {
      final groupTitle = _buildGroupTitle(chat);

      final groupMessages = ref.watch(
        localMessagesProvider((
          chatId: chat.id,
          token: token,
          currentUserId: currentUserId,
        )),
      );
      final unreadCount = groupMessages
          .where((m) => m.senderId != currentUserId && m.status != 'read')
          .length;

      return _wrapTile(
        context,
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                  chatId: chat.id,
                  otherUserId: chat.id,
                  otherUserName: groupTitle,
                  isGroup: true,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.indigo.shade100,
                  child: const Icon(Icons.group, color: Colors.indigo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: groupTitle,
                        child: Text(
                          groupTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat.memberCount == null
                            ? (chat.lastMessagePreview ?? 'Group chat')
                            : '${chat.memberCount} member${chat.memberCount == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      chat.lastMessageTimestamp != null
                          ? _formatTimestamp(chat.lastMessageTimestamp!)
                          : _formatTimestamp(chat.updatedAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final userProfileAsync = ref.watch(
      userProfileProvider((otherUserId, token)),
    );
    return userProfileAsync.when(
      loading: () => _wrapTile(
        context,
        ListTile(
          key: ValueKey('chat-loading-${chat.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Stack(
            alignment: Alignment.center,
            children: [
              const UserAvatarWidget(radius: 24),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
          title: const Text('Loading...'),
          subtitle: const Text('Fetching profile...'),
        ),
      ),
      error: (error, st) => _wrapTile(
        context,
        ListTile(
          key: ValueKey('chat-error-${chat.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: const UserAvatarWidget(radius: 24),
          title: const Text('Error loading profile'),
          subtitle: const Text('Tap to retry'),
          onTap: () {
            ref.invalidate(userProfileProvider((otherUserId, token)));
          },
        ),
      ),
      data: (userProfile) {
        // Fetch and decrypt messages for this chat to show actual last message content
        final messages = ref.watch(
          localMessagesProvider((
            chatId: chat.id,
            token: token,
            currentUserId: currentUserId,
          )),
        );

        return _wrapTile(
          context,
          ListTile(
            key: ValueKey('chat-data-${chat.id}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: UserAvatarWidget(
              imageUrl: userProfile.profilePictureUrl,
              radius: 24,
              username: userProfile.username,
            ),
            title: Text(
              userProfile.username,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Display the last message if available, otherwise use backend preview
                      String displayText = 'No messages yet';
                      
                      if (messages.isNotEmpty) {
                        // Use the decrypted content of the last message
                        displayText = messages.last.getDisplayContent();
                      } else if (chat.lastMessagePreview != null && 
                                 chat.lastMessagePreview!.isNotEmpty) {
                        displayText = chat.lastMessagePreview!;
                      }
                      
                      return Text(
                        _truncatePreview(displayText),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    chat.lastMessageTimestamp != null
                        ? _formatTimestamp(chat.lastMessageTimestamp!)
                        : _formatTimestamp(chat.updatedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'Archive chat',
                  onPressed: onArchive,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete chat',
                  onPressed: onDelete,
                ),
              ],
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(
                    chatId: chat.id,
                    otherUserId: otherUserId,
                    otherUserName: userProfile.username,
                    otherUserAvatarUrl: userProfile.profilePictureUrl,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
