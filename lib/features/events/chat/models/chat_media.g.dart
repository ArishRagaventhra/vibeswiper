// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMediaImpl _$$ChatMediaImplFromJson(Map<String, dynamic> json) =>
    _$ChatMediaImpl(
      url: json['url'] as String,
      type: $enumDecode(_$MediaTypeEnumMap, json['type']),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
    );

Map<String, dynamic> _$$ChatMediaImplToJson(_$ChatMediaImpl instance) =>
    <String, dynamic>{
      'url': instance.url,
      'type': _$MediaTypeEnumMap[instance.type]!,
      'thumbnailUrl': instance.thumbnailUrl,
      'fileName': instance.fileName,
      'mimeType': instance.mimeType,
    };

const _$MediaTypeEnumMap = {
  MediaType.image: 'image',
  MediaType.video: 'video',
  MediaType.file: 'file',
};
