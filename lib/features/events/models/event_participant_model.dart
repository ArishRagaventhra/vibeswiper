import 'dart:convert';

enum ParticipantRole {
  attendee,
  organizer,
  speaker,
  volunteer;

  String get name => toString().split('.').last;
}

enum ParticipantStatus {
  pending,
  accepted,
  rejected;

  String get name => toString().split('.').last;
}

class EventParticipant {
  final String eventId;
  final String userId;
  final ParticipantRole role;
  final ParticipantStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? joinedAt;
  final DateTime? leftDate;
  final int? waitlistPosition;
  final Map<String, dynamic> notificationPreferences;
  final Map<String, dynamic> metadata;
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  EventParticipant({
    required this.eventId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.joinedAt,
    this.leftDate,
    this.waitlistPosition,
    this.notificationPreferences = const {'push': true, 'email': true},
    this.metadata = const {},
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  EventParticipant copyWith({
    String? eventId,
    String? userId,
    ParticipantRole? role,
    ParticipantStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? joinedAt,
    DateTime? leftDate,
    int? waitlistPosition,
    Map<String, dynamic>? notificationPreferences,
    Map<String, dynamic>? metadata,
    String? username,
    String? fullName,
    String? avatarUrl,
  }) {
    return EventParticipant(
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      joinedAt: joinedAt ?? this.joinedAt,
      leftDate: leftDate ?? this.leftDate,
      waitlistPosition: waitlistPosition ?? this.waitlistPosition,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
      metadata: metadata ?? this.metadata,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory EventParticipant.fromMap(Map<String, dynamic> map) {
    return EventParticipant(
      eventId: map['event_id'],
      userId: map['user_id'],
      role: ParticipantRole.values.firstWhere(
        (r) => r.name == (map['role'] ?? 'attendee'),
        orElse: () => ParticipantRole.attendee,
      ),
      status: ParticipantStatus.values.firstWhere(
        (s) => s.name == (map['status'] ?? 'pending'),
        orElse: () => ParticipantStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      joinedAt: map['joined_at'] != null ? DateTime.parse(map['joined_at']) : null,
      leftDate: map['left_date'] != null ? DateTime.parse(map['left_date']) : null,
      waitlistPosition: map['waitlist_position'],
      notificationPreferences: Map<String, dynamic>.from(map['notification_preferences'] ?? {'push': true, 'email': true}),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      username: map['profiles']?['username'],
      fullName: map['profiles']?['full_name'],
      avatarUrl: map['profiles']?['avatar_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'user_id': userId,
      'role': role.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'joined_at': joinedAt?.toIso8601String(),
      'left_date': leftDate?.toIso8601String(),
      'waitlist_position': waitlistPosition,
      'notification_preferences': notificationPreferences,
      'metadata': metadata,
      'profiles': {
        'username': username,
        'full_name': fullName,
        'avatar_url': avatarUrl,
      },
    };
  }

  String toJson() => json.encode(toMap());

  factory EventParticipant.fromJson(String source) =>
      EventParticipant.fromMap(json.decode(source));

  @override
  String toString() {
    return 'EventParticipant(eventId: $eventId, userId: $userId, status: $status, role: $role, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventParticipant &&
        other.eventId == eventId &&
        other.userId == userId;
  }

  @override
  int get hashCode => eventId.hashCode ^ userId.hashCode;
}
