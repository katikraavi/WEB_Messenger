import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart' as provider_pkg;
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../providers/active_chats_provider.dart';
import '../providers/chats_provider.dart';
import '../services/chat_api_service.dart';
import '../widgets/chat_list_tile_consumer.dart';
import '../widgets/archived_chats_section.dart';
import 'chat_detail_screen.dart';
import '../../auth/providers/auth_provider.dart' as auth;

/// Screen for displaying the list of active chats
/// 
/// Features:
/// - Displays active (unarchived) chats sorted by recency
/// - Shows last message preview for each chat
/// - Tap to open chat detail screen
/// - Pull-to-refresh to reload chats
/// - Empty state UI when no chats
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current user ID and token using old provider package
    final authProvider = provider_pkg.Provider.of<auth.AuthProvider>(context);
    final currentUserId = authProvider.user?.userId ?? '';
    final token = authProvider.token ?? '';

    print('[ChatListScreen] Building with token: ${token.isNotEmpty ? 'present' : 'EMPTY'}');
    print('[ChatListScreen] Current user: ${authProvider.user?.username}');

    if (token.isEmpty) {
      print('[ChatListScreen] ❌ No token available');
      return Scaffold(
        appBar: AppBar(title: const Text('Chats')),
        body: const Center(child: Text('Not authenticated')),
      );
    }

    // Get active chats with token parameter
    print('[ChatListScreen] 📡 Watching activeChatListProvider for token: ${token.substring(0, 20)}...');
    final activeChatsStream = ref.watch(activeChatListProvider(token));

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh chats from backend
        return ref.refresh(activeChatListProvider(token));
      },
      child: activeChatsStream.when(
        // Loading state
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),

        // Error state
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Failed to load chats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.refresh(activeChatListProvider(token));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),

        // Success state
        data: (chats) {
          // Empty state
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No chats yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send an invitation to start messaging',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          // Active chats list
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherUserId = chat.getOtherId(currentUserId);
              return ChatListTileConsumer(
                chat: chat,
                otherUserId: otherUserId,
                currentUserId: currentUserId,
                token: token,
                lastMessage: chat.lastMessagePreview,
              );
            },
          );
        },
      ),
    );
  }
}
