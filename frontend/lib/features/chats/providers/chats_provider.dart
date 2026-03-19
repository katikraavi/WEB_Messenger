import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../services/chat_api_service.dart';
import './chat_cache_invalidator.dart';

/// Provider for the chat API service instance
final chatApiServiceProvider = Provider((ref) {
  return ChatApiService(baseUrl: 'http://localhost:8081');
});

/// FutureProvider for fetching chats
/// 
/// For MVP: Requires passing JWT token from UI
/// Token should come from the old provider package's AuthProvider
/// Watches cache invalidator to force refresh when needed (e.g., on tab switch)
final chatsProvider = FutureProvider.family<List<Chat>, String>((ref, token) async {
  print('[ChatsProvider] Called with token: ${token.isNotEmpty ? 'present' : 'EMPTY'}');
  
  // Watch cache invalidator to trigger refresh
  ref.watch(chatsCacheInvalidatorProvider);
  
  if (token.isEmpty) {
    print('[ChatsProvider] ❌ No authentication token provided');
    throw Exception('No authentication token');
  }

  final apiService = ref.watch(chatApiServiceProvider);
  
  try {
    print('[ChatsProvider] 📡 Fetching chats from API...');
    final chats = await apiService.fetchChats(token: token);
    print('[ChatsProvider] ✅ Successfully fetched ${chats.length} chats');
    // Sort by lastMessageTimestamp descending
    final sortedChats = List<Chat>.from(chats)
      ..sort((a, b) {
        final aTime = a.lastMessageTimestamp ?? a.updatedAt;
        final bTime = b.lastMessageTimestamp ?? b.updatedAt;
        return bTime.compareTo(aTime);
      });
    return sortedChats;
  } catch (e) {
    print('[ChatsProvider] ❌ Error fetching chats: $e');
    rethrow;
  }
});
