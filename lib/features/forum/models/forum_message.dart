import '../constants/forum_constants.dart';
import 'forum_message_media.dart';

class ForumMessage {
  final String id;
  final String forumId;
  final String senderId;
  final String? content;
  final String messageType;
  final String? replyToId;
  final bool isPinned;
  final bool isAnnouncement;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
  final ForumMessageMedia? media;

  const ForumMessage({
    required this.id,
    required this.forumId,
    required this.senderId,
    this.content,
    required this.messageType,
    this.replyToId,
    required this.isPinned,
    required this.isAnnouncement,
    this.editedAt,
    this.deletedAt,
    required this.createdAt,
    required this.metadata,
    this.media,
  });

  factory ForumMessage.fromJson(Map<String, dynamic> json) {
    return ForumMessage(
      id: json['id'] as String,
      forumId: json['forum_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String?,
      messageType: json['message_type'] as String,
      replyToId: json['reply_to_id'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      isAnnouncement: json['is_announcement'] as bool? ?? false,
      editedAt: json['edited_at'] != null ? DateTime.parse(json['edited_at']) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      media: json['media'] != null ? ForumMessageMedia.fromJson(json['media']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'forum_id': forumId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'reply_to_id': replyToId,
      'is_pinned': isPinned,
      'is_announcement': isAnnouncement,
      'edited_at': editedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
      'media': media?.toJson(),
    };
  }

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
  bool get isText => messageType == ForumConstants.messageTypeText;
  bool get isMedia => messageType == ForumConstants.messageTypeMedia;
  bool get isSystem => messageType == ForumConstants.messageTypeSystem;
  bool get hasMedia => media != null;
  
  String get state {
    if (isDeleted) return ForumConstants.messageStateDeleted;
    if (isAnnouncement) return ForumConstants.messageStateAnnouncement;
    if (isPinned) return ForumConstants.messageStatePinned;
    if (isEdited) return ForumConstants.messageStateEdited;
    return ForumConstants.messageStateNormal;
  }
}
