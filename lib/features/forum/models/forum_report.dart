class ForumReport {
  final String id;
  final String forumId;
  final String reporterId;
  final String? reportedMessageId;
  final String? reportedUserId;
  final String reason;
  final String status;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final String? notes;

  ForumReport({
    required this.id,
    required this.forumId,
    required this.reporterId,
    this.reportedMessageId,
    this.reportedUserId,
    required this.reason,
    required this.status,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'forum_id': forumId,
      'reporter_id': reporterId,
      'reported_message_id': reportedMessageId,
      'reported_user_id': reportedUserId,
      'reason': reason,
      'status': status,
      'resolved_by': resolvedBy,
      'resolved_at': resolvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory ForumReport.fromJson(Map<String, dynamic> json) {
    return ForumReport(
      id: json['id'],
      forumId: json['forum_id'],
      reporterId: json['reporter_id'],
      reportedMessageId: json['reported_message_id'],
      reportedUserId: json['reported_user_id'],
      reason: json['reason'],
      status: json['status'],
      resolvedBy: json['resolved_by'],
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      notes: json['notes'],
    );
  }

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
  bool get isDismissed => status == 'dismissed';
}
