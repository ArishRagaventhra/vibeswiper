import 'package:flutter/foundation.dart';

@immutable
class CreatorPaymentSettings {
  final String id;
  final String userId;
  final String upiId;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreatorPaymentSettings({
    required this.id,
    required this.userId,
    required this.upiId,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create a new instance with UPI details for convenience
  factory CreatorPaymentSettings.create({
    required String id,
    required String userId,
    required String upiId,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool isVerified = false,
  }) {
    return CreatorPaymentSettings(
      id: id,
      userId: userId,
      upiId: upiId,
      isVerified: isVerified,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Check if UPI ID is valid
  bool get isValid => upiId.isNotEmpty;

  factory CreatorPaymentSettings.fromJson(Map<String, dynamic> json) {
    return CreatorPaymentSettings(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      upiId: json['upi_id'] as String,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'upi_id': upiId,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Allow for updating fields
  CreatorPaymentSettings copyWith({
    String? upiId,
    bool? isVerified,
  }) {
    return CreatorPaymentSettings(
      id: id,
      userId: userId,
      upiId: upiId ?? this.upiId,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
