// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String?,
      encryptedContent: json['encrypted_content'] as String,
      status: json['status'] as String? ?? 'sent',
      createdAt: DateTime.parse(json['created_at'] as String),
      editedAt: json['edited_at'] == null
          ? null
          : DateTime.parse(json['edited_at'] as String),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      recipientCount: (json['recipient_count'] as num?)?.toInt(),
      deliveredCount: (json['delivered_count'] as num?)?.toInt(),
      readCount: (json['read_count'] as num?)?.toInt(),
      decryptedContent: json['decrypted_content'] as String?,
    );

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
      'id': instance.id,
      'chat_id': instance.chatId,
      'sender_id': instance.senderId,
      'recipient_id': instance.recipientId,
      'encrypted_content': instance.encryptedContent,
      'status': instance.status,
      'created_at': instance.createdAt.toIso8601String(),
      'edited_at': instance.editedAt?.toIso8601String(),
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'is_deleted': instance.isDeleted,
      'media_url': instance.mediaUrl,
      'media_type': instance.mediaType,
      'recipient_count': instance.recipientCount,
      'delivered_count': instance.deliveredCount,
      'read_count': instance.readCount,
      'decrypted_content': instance.decryptedContent,
    };
