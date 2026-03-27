import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_client.dart';
import '../models/chat_model.dart';
import '../services/chat_api_service.dart';

/// Provider for archived chats list for the current user
/// 
/// This provider fetches all archived chats from the backend.
/// It's a family provider that takes the JWT token as parameter.
/// 
/// Usage:
/// ```dart
/// final archivedChats = ref.watch(archivedChatsProvider(token));
/// ```
final archivedChatsProvider = FutureProvider.family<List<Chat>, String>((ref, token) async {
  try {
    
    final baseUrl = ApiClient.getBaseUrl();
    final chatService = ChatApiService(baseUrl: baseUrl);
    
    final chats = await chatService.fetchArchivedChats(token: token);
    
    return chats;
  } catch (e) {
    rethrow;
  }
});
