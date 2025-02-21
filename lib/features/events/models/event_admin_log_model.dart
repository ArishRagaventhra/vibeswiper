import 'dart:convert';

enum AdminActionType {
  roleChange,
  statusChange,
  participantRemoved,
  settingsChanged;

  String get name => toString().split('.').last;
}

class EventAdminLog {
  final String id;
  final String eventId;
  final String actorId;
  final String? targetUserId;
  final AdminActionType actionType;
  final Map<String, dynamic> changes;
  final String? notes;
  final DateTime createdAt;

  EventAdminLog({
    required this.id,
    required this.eventId,
    required this.actorId,
    this.targetUserId,
    required this.actionType,
    required this.changes,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'actor_id': actorId,
      'target_user_id': targetUserId,
      'action_type': actionType.name,
      'changes': changes,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory EventAdminLog.fromMap(Map<String, dynamic> map) {
    return EventAdminLog(
      id: map['id'],
      eventId: map['event_id'],
      actorId: map['actor_id'],
      targetUserId: map['target_user_id'],
      actionType: AdminActionType.values.firstWhere(
        (t) => t.name == map['action_type'],
        orElse: () => AdminActionType.settingsChanged,
      ),
      changes: Map<String, dynamic>.from(map['changes'] ?? {}),
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  String toJson() => json.encode(toMap());

  factory EventAdminLog.fromJson(String source) =>
      EventAdminLog.fromMap(json.decode(source));

  @override
  String toString() {
    return 'EventAdminLog(id: $id, eventId: $eventId, actorId: $actorId, targetUserId: $targetUserId, actionType: $actionType, changes: $changes, notes: $notes, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventAdminLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
