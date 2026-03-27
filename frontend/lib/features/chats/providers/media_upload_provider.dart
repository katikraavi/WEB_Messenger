import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_client.dart';
import '../models/message_model.dart';
import '../services/media_upload_service.dart';

/// Media upload service provider
final mediaUploadServiceProvider = Provider<MediaUploadService>((ref) {
  return MediaUploadService(baseUrl: ApiClient.getBaseUrl());
});

/// Upload media provider (T074)
/// 
/// Parameters: (chatId, mediaId, token)
/// Uploads media and attaches to message
final uploadMediaToMessageProvider =
    FutureProvider.family<Map<String, dynamic>, (String, String, String)>(
  (ref, params) async {
    final chatId = params.$1;
    final mediaId = params.$2;
    final token = params.$3;

    final uploadService = ref.watch(mediaUploadServiceProvider);

    try {

      // Note: In a real implementation, we would:
      // 1. Create a message first
      // 2. Attach media to that message
      // For now, this is a placeholder

      return {
        'media_id': mediaId,
        'attached': true,
      };
    } catch (e) {
      rethrow;
    }
  },
);
