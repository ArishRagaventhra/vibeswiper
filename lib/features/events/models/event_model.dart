import 'dart:convert';
import 'package:flutter/foundation.dart';

enum EventType { free, paid, invitation }
enum EventStatus { draft, upcoming, ongoing, completed, cancelled }
enum EventVisibility { public, private, unlisted }

@immutable
class Event {
  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  final EventType eventType;
  final EventVisibility visibility;
  final int? maxParticipants;
  final String? category;
  final List<String> tags;
  final String? recurringPattern;
  final Duration? reminderBefore;
  final EventStatus status;
  final DateTime? registrationDeadline;
  final double? ticketPrice;
  final String? currency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? mediaUrls;
  final String? accessCode;
  final DateTime? deletedAt;
  final bool isPlatformFeePaid; // Track if Rs. 99 fee is paid
  final String? platformPaymentId; // Store Razorpay payment ID

  Event({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    this.location,
    required this.startTime,
    required this.endTime,
    required this.eventType,
    required this.visibility,
    this.maxParticipants,
    this.category,
    required this.tags,
    this.recurringPattern,
    this.reminderBefore,
    required this.status,
    this.registrationDeadline,
    this.ticketPrice,
    this.currency,
    required this.createdAt,
    required this.updatedAt,
    this.mediaUrls,
    this.accessCode,
    this.deletedAt,
    this.isPlatformFeePaid = false,
    this.platformPaymentId,
  });

  Event copyWith({
    String? id,
    String? creatorId,
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    EventType? eventType,
    EventVisibility? visibility,
    int? maxParticipants,
    String? category,
    List<String>? tags,
    String? recurringPattern,
    Duration? reminderBefore,
    EventStatus? status,
    DateTime? registrationDeadline,
    double? ticketPrice,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? mediaUrls,
    String? accessCode,
    DateTime? deletedAt,
    bool? isPlatformFeePaid,
    String? platformPaymentId,
  }) {
    return Event(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      eventType: eventType ?? this.eventType,
      visibility: visibility ?? this.visibility,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      recurringPattern: recurringPattern ?? this.recurringPattern,
      reminderBefore: reminderBefore ?? this.reminderBefore,
      status: status ?? this.status,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      accessCode: accessCode ?? this.accessCode,
      deletedAt: deletedAt ?? this.deletedAt,
      isPlatformFeePaid: isPlatformFeePaid ?? this.isPlatformFeePaid,
      platformPaymentId: platformPaymentId ?? this.platformPaymentId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creator_id': creatorId,
      'title': title,
      'description': description,
      'location': location,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'event_type': eventType.toString().split('.').last,
      'visibility': visibility.toString().split('.').last,
      'max_participants': maxParticipants,
      'category': category,
      'tags': tags,
      'recurring_pattern': recurringPattern,
      'reminder_before': reminderBefore?.inMinutes,
      'status': status.toString().split('.').last,
      'registration_deadline': registrationDeadline?.toIso8601String(),
      'ticket_price': ticketPrice,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'media_urls': mediaUrls,
      'access_code': accessCode,
      'deleted_at': deletedAt?.toIso8601String(),
      'is_platform_fee_paid': isPlatformFeePaid,
      'platform_payment_id': platformPaymentId,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    try {
      final eventTypeStr = map['event_type'] as String?;
      final statusStr = map['status'] as String?;
      final startTimeStr = map['start_time'] as String?;
      final endTimeStr = map['end_time'] as String?;
      final createdAtStr = map['created_at'] as String?;
      final updatedAtStr = map['updated_at'] as String?;
      final visibilityStr = map['visibility'] as String?;

      if (map['id'] == null || map['creator_id'] == null || map['title'] == null ||
          startTimeStr == null || endTimeStr == null || createdAtStr == null || updatedAtStr == null) {
        throw FormatException('Missing required fields in event data');
      }

      // Parse status with a default value of 'upcoming' if not provided
      final EventStatus eventStatus = statusStr != null
          ? EventStatus.values.firstWhere(
              (s) => s.toString().split('.').last == statusStr,
              orElse: () => EventStatus.upcoming,
            )
          : EventStatus.upcoming;

      return Event(
        id: map['id'] as String,
        creatorId: map['creator_id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        location: map['location'] as String?,
        startTime: DateTime.parse(startTimeStr),
        endTime: DateTime.parse(endTimeStr),
        eventType: eventTypeStr != null
            ? EventType.values.firstWhere(
                (e) => e.toString().split('.').last == eventTypeStr,
                orElse: () => EventType.free,
              )
            : EventType.free,
        visibility: visibilityStr != null
            ? EventVisibility.values.firstWhere(
                (v) => v.toString().split('.').last == visibilityStr,
                orElse: () => EventVisibility.public,
              )
            : EventVisibility.public,
        maxParticipants: map['max_participants'] as int?,
        category: map['category'] as String?,
        tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        recurringPattern: map['recurring_pattern'] as String?,
        reminderBefore: map['reminder_before'] != null
            ? Duration(minutes: map['reminder_before'] as int)
            : null,
        status: eventStatus,
        registrationDeadline: map['registration_deadline'] != null
            ? DateTime.parse(map['registration_deadline'] as String)
            : null,
        ticketPrice: map['ticket_price'] != null
            ? (map['ticket_price'] as num).toDouble()
            : null,
        currency: map['currency'] as String?,
        createdAt: DateTime.parse(createdAtStr),
        updatedAt: DateTime.parse(updatedAtStr),
        mediaUrls: (map['media_urls'] as List<dynamic>?)?.cast<String>() ?? [],
        accessCode: map['access_code'] as String?,
        deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
        isPlatformFeePaid: map['is_platform_fee_paid'] as bool? ?? false,
        platformPaymentId: map['platform_payment_id'] as String?,
      );
    } catch (e) {
      debugPrint('Error parsing event data: $e');
      debugPrint('Raw event data: $map');
      rethrow;
    }
  }

  String toJson() => json.encode(toMap());

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      eventType: EventType.values.firstWhere(
        (e) => e.toString() == 'EventType.${json['event_type']}',
      ),
      visibility: EventVisibility.values.firstWhere(
        (v) => v.toString() == 'EventVisibility.${json['visibility']}',
      ),
      maxParticipants: json['max_participants'] as int?,
      category: json['category'] as String?,
      tags: List<String>.from(json['tags'] as List),
      recurringPattern: json['recurring_pattern'] as String?,
      reminderBefore: json['reminder_before'] != null
          ? Duration(minutes: json['reminder_before'] as int)
          : null,
      status: EventStatus.values.firstWhere(
        (s) => s.toString() == 'EventStatus.${json['status']}',
      ),
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.parse(json['registration_deadline'] as String)
          : null,
      ticketPrice: json['ticket_price'] != null
          ? (json['ticket_price'] as num).toDouble()
          : null,
      currency: json['currency'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      mediaUrls: json['media_urls'] != null
          ? List<String>.from(json['media_urls'] as List)
          : null,
      accessCode: json['access_code'] as String?,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      isPlatformFeePaid: json['is_platform_fee_paid'] as bool? ?? false,
      platformPaymentId: json['platform_payment_id'] as String?,
    );
  }

  @override
  String toString() => 'Event(id: $id, title: $title)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Calculate event status based on current time
  EventStatus calculateStatus(DateTime currentTime) {
    if (deletedAt != null) return EventStatus.cancelled;
    if (status == EventStatus.cancelled) return EventStatus.cancelled;
    
    // Compare only dates, ignoring time component
    final now = DateTime(currentTime.year, currentTime.month, currentTime.day);
    final start = DateTime(startTime.year, startTime.month, startTime.day);
    final end = DateTime(endTime.year, endTime.month, endTime.day);
    
    if (now.isBefore(start)) {
      return EventStatus.upcoming;
    } else if (now.isAfter(end)) {
      return EventStatus.completed;
    } else if (now.isAtSameMomentAs(start) || now.isAtSameMomentAs(end) || (now.isAfter(start) && now.isBefore(end))) {
      return EventStatus.ongoing;
    } else {
      return EventStatus.completed;
    }
  }

  // Get current status
  EventStatus get currentStatus {
    return calculateStatus(DateTime.now());
  }
}
