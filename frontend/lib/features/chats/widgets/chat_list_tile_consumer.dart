import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../providers/user_profile_provider.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(
      userProfileProvider((otherUserId, token)),
    );
    return userProfileAsync.when(
      loading: () => ListTile(
        key: ValueKey('chat-loading-${chat.id}'),
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
      error: (error, st) => ListTile(
        key: ValueKey('chat-error-${chat.id}'),
        leading: const UserAvatarWidget(radius: 24),
        title: const Text('Error loading profile'),
        subtitle: const Text('Tap to retry'),
        onTap: () {
          ref.invalidate(userProfileProvider((otherUserId, token)));
        },
      ),
      data: (userProfile) {
        // No bold/unread logic, always normal style

        return ListTile(
          key: ValueKey('chat-data-${chat.id}'),
          leading: UserAvatarWidget(
            imageUrl: userProfile.profilePictureUrl,
            radius: 24,
            username: userProfile.username,
          ),
          title: Text(
            userProfile.username,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  chat.lastMessagePreview == null ||
                          chat.lastMessagePreview!.isEmpty
                      ? 'No messages yet'
                      : _truncatePreview(chat.lastMessagePreview!),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
                icon: const Icon(Icons.delete_outlined, color: Colors.red),
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
        );
      },
    );
  }
}
