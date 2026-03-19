import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../services/chat_api_service.dart';
import '../providers/active_chats_provider.dart';
import '../providers/archived_chats_provider.dart';
import '../providers/user_profile_provider.dart';
import 'user_avatar_widget.dart';
import '../screens/chat_detail_screen.dart';

class ChatListTileConsumer extends ConsumerWidget {
  final String otherUserId;
  final String token;
  final Chat chat;
  final String currentUserId;
  final String? lastMessage;

  const ChatListTileConsumer({
    Key? key,
    required this.otherUserId,
    required this.token,
    required this.chat,
    required this.currentUserId,
    this.lastMessage,
  }) : super(key: key);

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
    final userProfileAsync = ref.watch(userProfileProvider((otherUserId, token)));
    return userProfileAsync.when(
      loading: () => ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[300],
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: const Text('Loading...'),
        subtitle: const Text('Fetching profile...'),
      ),
      error: (error, st) => ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.red[100],
          child: Icon(Icons.error, color: Colors.red[400]),
        ),
        title: const Text('Error loading profile'),
        subtitle: const Text('Tap to retry'),
        onTap: () {
          ref.refresh(userProfileProvider((otherUserId, token)));
        },
      ),
      data: (userProfile) {
        // No bold/unread logic, always normal style

        return ListTile(
          leading: userProfile.profilePictureUrl != null && userProfile.profilePictureUrl!.isNotEmpty
            ? UserAvatarWidget(
                imageUrl: userProfile.profilePictureUrl!,
                radius: 24,
                username: userProfile.username,
              )
            : CircleAvatar(
                radius: 24,
                backgroundImage: AssetImage('assets/images/profile/defaultProfilePic.jpg'),
                child: Text(
                  userProfile.username != null && userProfile.username!.isNotEmpty
                    ? userProfile.username![0].toUpperCase()
                    : '?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
          title: Text(
            userProfile.username ?? 'Unknown',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  chat.lastMessagePreview == null || chat.lastMessagePreview!.isEmpty
                    ? 'No messages yet'
                    : _truncatePreview(chat.lastMessagePreview!),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(
                  chatId: chat.id,
                  otherUserId: otherUserId,
                  otherUserName: userProfile.username ?? 'Unknown',
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
