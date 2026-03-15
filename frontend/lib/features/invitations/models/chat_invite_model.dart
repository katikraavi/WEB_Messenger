import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_invite_model.freezed.dart';

/// Frontend representation of a chat invitation
@freezed
class ChatInviteModel with _$ChatInviteModel {
  const factory ChatInviteModel({
    required String id,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String recipientId,
    required String status, // 'pending', 'accepted', 'declined'
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _ChatInviteModel;

  factory ChatInviteModel.fromJson(Map<String, dynamic> json) {
    return ChatInviteModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      recipientId: json['recipient_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null 
        ? DateTime.parse(json['deleted_at'] as String)
        : null,
    );
  }
}
