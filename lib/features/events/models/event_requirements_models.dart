import 'package:flutter/foundation.dart';

enum QuestionType { text, multiple_choice, yes_no }

@immutable
class EventCustomQuestion {
  final String id;
  final String eventId;
  final String questionText;
  final QuestionType questionType;
  final List<String>? options; // For multiple choice questions
  final bool isRequired;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventCustomQuestion({
    required this.id,
    required this.eventId,
    required this.questionText,
    required this.questionType,
    this.options,
    this.isRequired = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventCustomQuestion.fromJson(Map<String, dynamic> json) {
    return EventCustomQuestion(
      id: json['id'],
      eventId: json['event_id'],
      questionText: json['question_text'],
      questionType: QuestionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['question_type'],
        orElse: () => QuestionType.text,
      ),
      options: json['options'] != null 
          ? List<String>.from(json['options'])
          : null,
      isRequired: json['is_required'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'question_text': questionText,
      'question_type': questionType.toString().split('.').last,
      'options': options,
      'is_required': isRequired,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EventCustomQuestion copyWith({
    String? id,
    String? eventId,
    String? questionText,
    QuestionType? questionType,
    List<String>? options,
    bool? isRequired,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventCustomQuestion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      options: options ?? this.options,
      isRequired: isRequired ?? this.isRequired,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class EventRefundPolicy {
  final String id;
  final String eventId;
  final String policyText;
  final int? refundWindowHours;
  final double? refundPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventRefundPolicy({
    required this.id,
    required this.eventId,
    required this.policyText,
    this.refundWindowHours,
    this.refundPercentage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventRefundPolicy.fromJson(Map<String, dynamic> json) {
    return EventRefundPolicy(
      id: json['id'],
      eventId: json['event_id'],
      policyText: json['policy_text'],
      refundWindowHours: json['refund_window_hours'],
      refundPercentage: json['refund_percentage'] != null 
          ? double.parse(json['refund_percentage'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'policy_text': policyText,
      'refund_window_hours': refundWindowHours,
      'refund_percentage': refundPercentage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EventRefundPolicy copyWith({
    String? id,
    String? eventId,
    String? policyText,
    int? refundWindowHours,
    double? refundPercentage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventRefundPolicy(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      policyText: policyText ?? this.policyText,
      refundWindowHours: refundWindowHours ?? this.refundWindowHours,
      refundPercentage: refundPercentage ?? this.refundPercentage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class EventAcceptanceConfirmation {
  final String id;
  final String eventId;
  final String confirmationText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventAcceptanceConfirmation({
    required this.id,
    required this.eventId,
    required this.confirmationText,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventAcceptanceConfirmation.fromJson(Map<String, dynamic> json) {
    return EventAcceptanceConfirmation(
      id: json['id'],
      eventId: json['event_id'],
      confirmationText: json['confirmation_text'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'confirmation_text': confirmationText,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EventAcceptanceConfirmation copyWith({
    String? id,
    String? eventId,
    String? confirmationText,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventAcceptanceConfirmation(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      confirmationText: confirmationText ?? this.confirmationText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}