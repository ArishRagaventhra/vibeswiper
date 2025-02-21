// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_participant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatParticipantImpl _$$ChatParticipantImplFromJson(
        Map<String, dynamic> json) =>
    _$ChatParticipantImpl(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      userId: json['userId'] as String,
      role: $enumDecode(_$ParticipantRoleEnumMap, json['role']),
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      lastReadAt: json['lastReadAt'] == null
          ? null
          : DateTime.parse(json['lastReadAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$$ChatParticipantImplToJson(
        _$ChatParticipantImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'roomId': instance.roomId,
      'userId': instance.userId,
      'role': _$ParticipantRoleEnumMap[instance.role]!,
      'joinedAt': instance.joinedAt.toIso8601String(),
      'lastReadAt': instance.lastReadAt?.toIso8601String(),
      'isActive': instance.isActive,
    };

const _$ParticipantRoleEnumMap = {
  ParticipantRole.member: 'member',
  ParticipantRole.moderator: 'moderator',
  ParticipantRole.admin: 'admin',
};
