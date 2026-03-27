import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_client.dart';
import '../models/chat_model.dart';
import '../providers/archived_chats_provider.dart';
import '../services/chat_api_service.dart';
import '../providers/active_chats_provider.dart';
import '../providers/chats_provider.dart';
import '../providers/user_profile_provider.dart';
import 'user_avatar_widget.dart';

/// Widget that displays the archived chats section
///
/// Shows:
/// - Toggle button to expand/collapse archived chats list
/// - Count of archived chats
/// - List of archived chat tiles with unarchive buttons
class ArchivedChatsSection extends ConsumerStatefulWidget {
  final String token;
  final String currentUserId;

  const ArchivedChatsSection({
    super.key,
    required this.token,
    required this.currentUserId,
  });

  @override
  ConsumerState<ArchivedChatsSection> createState() =>
      _ArchivedChatsSectionState();
}

class _ArchivedChatsSectionState extends ConsumerState<ArchivedChatsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final archivedChatsAsync = ref.watch(archivedChatsProvider(widget.token));

    return archivedChatsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          height: 50,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (error, st) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          leading: Icon(Icons.error_outline, color: Colors.red),
          title: Text('Error loading archived chats'),
          subtitle: Text(error.toString()),
        ),
      ),
      data: (archivedChats) {
        if (archivedChats.isEmpty) {
          return SizedBox.shrink();
        }

        return Column(
          children: [
            // Header with toggle button
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE0E8F5)),
              ),
              child: ListTile(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                leading: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[600],
                ),
                title: Text(
                  'Archived Chats',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${archivedChats.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
            // Expanded list of archived chats
            if (_isExpanded)
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: archivedChats.length,
                itemBuilder: (context, index) {
                  final chat = archivedChats[index];
                  final otherUserId =
                      chat.participant1Id == widget.currentUserId
                      ? chat.participant2Id
                      : chat.participant1Id;

                  return _ArchivedChatTile(
                    chat: chat,
                    otherUserId: otherUserId,
                    currentUserId: widget.currentUserId,
                    token: widget.token,
                    onUnarchived: () {
                      // Refresh both active and archived chats
                      ref.invalidate(chatsProvider(widget.token));
                      ref.invalidate(activeChatListProvider(widget.token));
                      ref.invalidate(archivedChatsProvider(widget.token));
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// Individual tile for an archived chat
class _ArchivedChatTile extends ConsumerWidget {
  final Chat chat;
  final String otherUserId;
  final String currentUserId;
  final String token;
  final VoidCallback onUnarchived;

  const _ArchivedChatTile({
    required this.chat,
    required this.otherUserId,
    required this.currentUserId,
    required this.token,
    required this.onUnarchived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(
      userProfileProvider((otherUserId, token)),
    );

    return userProfileAsync.when(
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4ECF7)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: const UserAvatarWidget(radius: 20),
          title: const Text('Loading...'),
          subtitle: Text(
            'Archived on ${chat.updatedAt.toString().split('.')[0]}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      ),
      error: (error, st) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4ECF7)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: const UserAvatarWidget(radius: 20),
          title: const Text('Unknown user'),
          subtitle: Text(
            'Archived on ${chat.updatedAt.toString().split('.')[0]}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          trailing: _buildUnarchiveButton(context),
        ),
      ),
      data: (userProfile) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4ECF7)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: UserAvatarWidget(
            imageUrl: userProfile.profilePictureUrl,
            radius: 20,
            username: userProfile.username,
          ),
          title: Text(
            userProfile.username,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Archived on ${chat.updatedAt.toString().split('.')[0]}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          trailing: _buildUnarchiveButton(context),
        ),
      ),
    );
  }

  Widget _buildUnarchiveButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        try {
          final baseUrl = ApiClient.getBaseUrl();
          final chatService = ChatApiService(baseUrl: baseUrl);

          await chatService.unarchiveChat(token: token, chatId: chat.id);

          if (!context.mounted) {
            return;
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Chat unarchived')));

          onUnarchived();
        } catch (e) {
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unarchive: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      icon: const Icon(Icons.unarchive, size: 16),
      label: const Text('Unarchive'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}
