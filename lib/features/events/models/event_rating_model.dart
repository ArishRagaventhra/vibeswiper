import 'dart:convert';

class EventRating {
  final String id;
  final String eventId;
  final String userId;
  final double overallRating;
  final double organizationRating;
  final double contentRating;
  final double venueRating;
  final String? reviewText;
  final DateTime reviewDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventRating({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.overallRating,
    required this.organizationRating,
    required this.contentRating,
    required this.venueRating,
    this.reviewText,
    required this.reviewDate,
    required this.createdAt,
    required this.updatedAt,
  });

  EventRating copyWith({
    String? id,
    String? eventId,
    String? userId,
    double? overallRating,
    double? organizationRating,
    double? contentRating,
    double? venueRating,
    String? reviewText,
    DateTime? reviewDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventRating(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      overallRating: overallRating ?? this.overallRating,
      organizationRating: organizationRating ?? this.organizationRating,
      contentRating: contentRating ?? this.contentRating,
      venueRating: venueRating ?? this.venueRating,
      reviewText: reviewText ?? this.reviewText,
      reviewDate: reviewDate ?? this.reviewDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'overall_rating': overallRating,
      'organization_rating': organizationRating,
      'content_rating': contentRating,
      'venue_rating': venueRating,
      'review_text': reviewText,
      'review_date': reviewDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory EventRating.fromMap(Map<String, dynamic> map) {
    return EventRating(
      id: map['id'] ?? '',
      eventId: map['event_id'] ?? '',
      userId: map['user_id'] ?? '',
      overallRating: (map['overall_rating'] as num?)?.toDouble() ?? 0.0,
      organizationRating: (map['organization_rating'] as num?)?.toDouble() ?? 0.0,
      contentRating: (map['content_rating'] as num?)?.toDouble() ?? 0.0,
      venueRating: (map['venue_rating'] as num?)?.toDouble() ?? 0.0,
      reviewText: map['review_text'],
      reviewDate: DateTime.parse(map['review_date'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  String toJson() => json.encode(toMap());

  factory EventRating.fromJson(String source) =>
      EventRating.fromMap(json.decode(source));

  @override
  String toString() {
    return 'EventRating(id: $id, eventId: $eventId, userId: $userId, overallRating: $overallRating, organizationRating: $organizationRating, contentRating: $contentRating, venueRating: $venueRating, reviewText: $reviewText, reviewDate: $reviewDate, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is EventRating &&
      other.id == id &&
      other.eventId == eventId &&
      other.userId == userId &&
      other.overallRating == overallRating &&
      other.organizationRating == organizationRating &&
      other.contentRating == contentRating &&
      other.venueRating == venueRating &&
      other.reviewText == reviewText &&
      other.reviewDate == reviewDate &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      eventId.hashCode ^
      userId.hashCode ^
      overallRating.hashCode ^
      organizationRating.hashCode ^
      contentRating.hashCode ^
      venueRating.hashCode ^
      reviewText.hashCode ^
      reviewDate.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
  }
}
