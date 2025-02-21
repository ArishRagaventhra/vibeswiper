import '../constants/forum_constants.dart';

class ForumMessageMedia {
  final String id;
  final String messageId;
  final String url;
  final String type;
  final String? thumbnailUrl;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const ForumMessageMedia({
    required this.id,
    required this.messageId,
    required this.url,
    required this.type,
    this.thumbnailUrl,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.createdAt,
    required this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'url': url,
      'type': type,
      'thumbnail_url': thumbnailUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ForumMessageMedia.fromJson(Map<String, dynamic> json) {
    return ForumMessageMedia(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      url: json['url'] as String,
      type: json['type'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int,
      mimeType: json['mime_type'] as String,
      createdAt: DateTime.parse(json['created_at']),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  bool get isImage => type == ForumConstants.mediaTypeImage;
  bool get isVideo => type == ForumConstants.mediaTypeVideo;
  bool get isDocument => type == ForumConstants.mediaTypeDocument;
  bool get isAudio => type == ForumConstants.mediaTypeAudio;
}
