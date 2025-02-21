import 'package:flutter/foundation.dart';

@immutable
class EventAction {
  final String id;
  final String eventId;
  final String userId;
  final EventActionType actionType;
  final String reason;
  final DateTime createdAt;

  const EventAction({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.actionType,
    required this.reason,
    required this.createdAt,
  });

  factory EventAction.fromJson(Map<String, dynamic> json) {
    return EventAction(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      actionType: EventActionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['action_type'],
      ),
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'action_type': actionType.toString().split('.').last,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum EventActionType {
  cancelled,
  deleted,
}
