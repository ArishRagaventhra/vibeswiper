import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../profile/models/profile_model.dart';
import 'chat_media.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

enum MessageType {
  text,
  image,
  video,
  file
}

@freezed
class ChatMessage with _$ChatMessage {
  const ChatMessage._();

  const factory ChatMessage({
    required String id,
    @JsonKey(name: 'chat_room_id') required String roomId,
    required String senderId,
    @JsonKey(name: 'sender_profile') Profile? senderProfile,
    required String content,
    required MessageType type,
    required DateTime createdAt,
    required DateTime updatedAt,
    ChatMedia? media,
    @Default(false) bool isDeleted,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);

  static ChatMessage fromMap(Map<String, dynamic> map) {
    final mediaUrl = map['media_url'] as String?;
    final mediaType = map['media_type'] as String?;
    final fileName = map['file_name'] as String?;
    final mimeType = map['mime_type'] as String?;
    final fileSize = map['file_size'] as int?;
    final thumbnailUrl = map['thumbnail_url'] as String?;
    
    ChatMedia? media;
    if (mediaUrl != null && mediaType != null) {
      media = ChatMedia(
        url: mediaUrl,
        type: MediaType.values.firstWhere(
          (e) => e.toString().split('.').last == mediaType,
          orElse: () => MediaType.file,
        ),
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
        thumbnailUrl: thumbnailUrl,
      );
    }

    Profile? senderProfile;
    if (map['sender_profile'] != null) {
      senderProfile = Profile.fromJson(map['sender_profile'] as Map<String, dynamic>);
    }
    
    final messageType = map['type'] as String? ?? map['message_type'] as String;
    
    return ChatMessage(
      id: map['id'] as String,
      roomId: map['chat_room_id'] as String,
      senderId: map['sender_id'] as String,
      senderProfile: senderProfile,
      content: map['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == messageType,
        orElse: () => MessageType.text,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      media: media,
      isDeleted: map['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_room_id': roomId,
      'sender_id': senderId,
      'sender_profile': senderProfile?.toJson(),
      'content': content,
      'message_type': type.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (media != null) ...{
        'media_url': media!.url,
        'media_type': media!.type.toString().split('.').last,
      },
      'is_deleted': isDeleted,
    };
  }
}
