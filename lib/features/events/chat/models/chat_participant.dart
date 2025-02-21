import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_participant.freezed.dart';
part 'chat_participant.g.dart';

enum ParticipantRole {
  member,
  moderator,
  admin
}

@freezed
class ChatParticipant with _$ChatParticipant {
  const ChatParticipant._(); 

  const factory ChatParticipant({
    required String id,
    required String roomId,
    required String userId,
    required ParticipantRole role,
    required DateTime joinedAt,
    DateTime? lastReadAt,
    @Default(true) bool isActive,
  }) = _ChatParticipant;

  factory ChatParticipant.fromJson(Map<String, dynamic> json) => _$ChatParticipantFromJson(json);

  static ChatParticipant fromMap(Map<String, dynamic> map) {
    return ChatParticipant(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      userId: map['user_id'] as String,
      role: ParticipantRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => ParticipantRole.member,
      ),
      joinedAt: DateTime.parse(map['joined_at'] as String),
      lastReadAt: map['last_read_at'] != null 
          ? DateTime.parse(map['last_read_at'] as String) 
          : null,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'role': role.toString().split('.').last,
      'joined_at': joinedAt.toIso8601String(),
      'last_read_at': lastReadAt?.toIso8601String(),
      'is_active': isActive,
    };
  }
}
