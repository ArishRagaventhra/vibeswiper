import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_media.freezed.dart';
part 'chat_media.g.dart';

enum MediaType {
  image,
  video,
  file
}

@freezed
class ChatMedia with _$ChatMedia {
  const ChatMedia._(); 

  const factory ChatMedia({
    required String url,
    required MediaType type,
    String? thumbnailUrl,
    String? fileName,
    String? mimeType,
  }) = _ChatMedia;

  factory ChatMedia.fromJson(Map<String, dynamic> json) => _$ChatMediaFromJson(json);

  static ChatMedia fromMap(Map<String, dynamic> map) {
    return ChatMedia(
      url: map['url'] as String,
      type: MediaType.values.firstWhere(
        (e) => e.toString().split('.').last == (map['type'] as String? ?? 'file'),
        orElse: () => MediaType.file,
      ),
      thumbnailUrl: map['thumbnail_url'] as String?,
      fileName: map['file_name'] as String?,
      mimeType: map['mime_type'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type.toString().split('.').last,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (fileName != null) 'file_name': fileName,
      if (mimeType != null) 'mime_type': mimeType,
    };
  }
}
