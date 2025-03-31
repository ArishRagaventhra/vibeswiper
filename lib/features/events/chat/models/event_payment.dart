import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:scompass_07/features/events/chat/models/payment_type.dart';

class EventPayment {
  final String id;
  final String eventId;
  final String paymentInfo;
  final PaymentType paymentType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? addedBy;
  final String? paymentProcessor;

  EventPayment({
    required this.id,
    required this.eventId,
    required this.paymentInfo,
    this.paymentType = PaymentType.upi,
    required this.createdAt,
    required this.updatedAt,
    this.addedBy,
    this.paymentProcessor,
  });

  factory EventPayment.fromMap(Map<String, dynamic> map) {
    PaymentType paymentType;
    
    // Determine payment type from the database value
    switch (map['payment_type']) {
      case 'upi':
        paymentType = PaymentType.upi;
        break;
      case 'razorpay':
        paymentType = PaymentType.razorpay;
        break;
      case 'stripe':
        paymentType = PaymentType.stripe;
        break;
      default:
        paymentType = PaymentType.url;
    }

    return EventPayment(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      paymentInfo: map['payment_info'] as String,
      paymentType: paymentType,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      addedBy: map['added_by'] as String?,
      paymentProcessor: map['payment_processor'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    // Convert payment type to string for database
    String paymentTypeString;
    switch (paymentType) {
      case PaymentType.upi:
        paymentTypeString = 'upi';
        break;
      case PaymentType.razorpay:
        paymentTypeString = 'razorpay';
        break;
      case PaymentType.stripe:
        paymentTypeString = 'stripe';
        break;
      default:
        paymentTypeString = 'url';
    }

    return {
      'id': id,
      'event_id': eventId,
      'payment_info': paymentInfo,
      'payment_type': paymentTypeString,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'added_by': addedBy,
      'payment_processor': paymentProcessor,
    };
  }

  // Create a copy with some fields changed
  EventPayment copyWith({
    String? id,
    String? eventId,
    String? paymentInfo,
    PaymentType? paymentType,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? addedBy,
    String? paymentProcessor,
  }) {
    return EventPayment(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      paymentInfo: paymentInfo ?? this.paymentInfo,
      paymentType: paymentType ?? this.paymentType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedBy: addedBy ?? this.addedBy,
      paymentProcessor: paymentProcessor ?? this.paymentProcessor,
    );
  }
}
