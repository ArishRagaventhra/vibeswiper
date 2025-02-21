import 'package:supabase_flutter/supabase_flutter.dart';

class EventOrganizerContact {
  final String id;
  final String eventId;
  final String name;
  final String email;
  final String phone;
  final bool contactVerified;
  final DateTime? verificationDeadline;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventOrganizerContact({
    required this.id,
    required this.eventId,
    required this.name,
    required this.email,
    required this.phone,
    this.contactVerified = false,
    this.verificationDeadline,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventOrganizerContact.fromJson(Map<String, dynamic> json) {
    return EventOrganizerContact(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      contactVerified: json['contact_verified'] as bool? ?? false,
      verificationDeadline: json['verification_deadline'] != null
          ? DateTime.parse(json['verification_deadline'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'email': email,
      'phone': phone,
      'contact_verified': contactVerified,
      'verification_deadline': verificationDeadline?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EventOrganizerContact copyWith({
    String? id,
    String? eventId,
    String? name,
    String? email,
    String? phone,
    bool? contactVerified,
    DateTime? verificationDeadline,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventOrganizerContact(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      contactVerified: contactVerified ?? this.contactVerified,
      verificationDeadline: verificationDeadline ?? this.verificationDeadline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
