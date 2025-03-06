class EventQuestionResponse {
  final String id;
  final String eventId;
  final String userId;
  final String questionId;
  final String responseText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventQuestionResponse({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.questionId,
    required this.responseText,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventQuestionResponse.fromJson(Map<String, dynamic> json) {
    return EventQuestionResponse(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      questionId: json['question_id'] as String,
      responseText: json['response_text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'user_id': userId,
    'question_id': questionId,
    'response_text': responseText,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class EventAcceptanceRecord {
  final String id;
  final String eventId;
  final String userId;
  final DateTime acceptedAt;
  final String acceptanceText;

  const EventAcceptanceRecord({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.acceptedAt,
    required this.acceptanceText,
  });

  factory EventAcceptanceRecord.fromJson(Map<String, dynamic> json) {
    return EventAcceptanceRecord(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      acceptedAt: DateTime.parse(json['accepted_at'] as String),
      acceptanceText: json['acceptance_text'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'user_id': userId,
    'accepted_at': acceptedAt.toIso8601String(),
    'acceptance_text': acceptanceText,
  };
}

class EventRefundAcknowledgment {
  final String id;
  final String eventId;
  final String userId;
  final DateTime acknowledgedAt;
  final String policyText;

  const EventRefundAcknowledgment({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.acknowledgedAt,
    required this.policyText,
  });

  factory EventRefundAcknowledgment.fromJson(Map<String, dynamic> json) {
    return EventRefundAcknowledgment(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      acknowledgedAt: DateTime.parse(json['acknowledged_at'] as String),
      policyText: json['policy_text'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'user_id': userId,
    'acknowledged_at': acknowledgedAt.toIso8601String(),
    'policy_text': policyText,
  };
}
