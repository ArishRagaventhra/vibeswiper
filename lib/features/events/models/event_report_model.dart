import 'dart:convert';

enum ReportStatus {
  pending,
  inProgress,
  resolved,
  dismissed,
}

extension ReportStatusExtension on ReportStatus {
  String get name => toString().split('.').last;

  static ReportStatus fromString(String status) {
    return ReportStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => ReportStatus.pending,
    );
  }
}

class EventReport {
  final String id;
  final String eventId;
  final String userId;
  final String reason;
  final String description;
  final ReportStatus status;
  final String? adminNotes;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventReport({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.reason,
    required this.description,
    required this.status,
    this.adminNotes,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  EventReport copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? reason,
    String? description,
    ReportStatus? status,
    String? adminNotes,
    String? resolvedBy,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventReport(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'reason': reason,
      'description': description,
      'status': status.name,
      'admin_notes': adminNotes,
      'resolved_by': resolvedBy,
      'resolved_at': resolvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory EventReport.fromMap(Map<String, dynamic> map) {
    return EventReport(
      id: map['id'] ?? '',
      eventId: map['event_id'] ?? '',
      userId: map['user_id'] ?? '',
      reason: map['reason'] ?? '',
      description: map['description'] ?? '',
      status: ReportStatusExtension.fromString(map['status'] ?? ''),
      adminNotes: map['admin_notes'],
      resolvedBy: map['resolved_by'],
      resolvedAt: map['resolved_at'] != null 
          ? DateTime.parse(map['resolved_at'])
          : null,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  String toJson() => json.encode(toMap());

  factory EventReport.fromJson(String source) =>
      EventReport.fromMap(json.decode(source));

  @override
  String toString() {
    return 'EventReport(id: $id, eventId: $eventId, userId: $userId, reason: $reason, description: $description, status: $status, adminNotes: $adminNotes, resolvedBy: $resolvedBy, resolvedAt: $resolvedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is EventReport &&
      other.id == id &&
      other.eventId == eventId &&
      other.userId == userId &&
      other.reason == reason &&
      other.description == description &&
      other.status == status &&
      other.adminNotes == adminNotes &&
      other.resolvedBy == resolvedBy &&
      other.resolvedAt == resolvedAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      eventId.hashCode ^
      userId.hashCode ^
      reason.hashCode ^
      description.hashCode ^
      status.hashCode ^
      adminNotes.hashCode ^
      resolvedBy.hashCode ^
      resolvedAt.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
  }
}
