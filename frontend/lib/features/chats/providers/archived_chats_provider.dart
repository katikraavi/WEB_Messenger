import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8081');
    final chatService = ChatApiService(baseUrl: baseUrl);
    
    final chats = await chatService.fetchArchivedChats(token: token);
    
    return chats;
  } catch (e) {
    rethrow;
  }
});
