import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_room.freezed.dart';
part 'chat_room.g.dart';

@freezed
class ChatRoom with _$ChatRoom {
  const ChatRoom._(); 

  const factory ChatRoom({
    required String id,
    required String eventId,
    required String name,
    required String roomType,
    String? description,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? lastMessageAt,
    @Default(true) bool isActive,
  }) = _ChatRoom;

  factory ChatRoom.fromJson(Map<String, dynamic> json) => _$ChatRoomFromJson(json);

  static ChatRoom fromMap(Map<String, dynamic> map) {
    return ChatRoom(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      name: map['name'] as String,
      roomType: map['room_type'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastMessageAt: map['last_message_at'] != null 
          ? DateTime.parse(map['last_message_at'] as String) 
          : null,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'room_type': roomType,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'is_active': isActive,
    };
  }
}
