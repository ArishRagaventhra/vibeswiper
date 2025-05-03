import 'dart:convert';
import 'package:flutter/foundation.dart';

enum BookingStatus { pending, confirmed, cancelled }
enum PaymentStatus { unpaid, partially_paid, paid, refunded }

@immutable
class TicketBooking {
  final String id;
  final String bookingReference;
  final String userId;
  final String eventId;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final bool isVibePrice;
  final BookingStatus bookingStatus;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TicketBooking({
    required this.id,
    required this.bookingReference,
    required this.userId,
    required this.eventId,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.isVibePrice,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  TicketBooking copyWith({
    String? id,
    String? bookingReference,
    String? userId,
    String? eventId,
    int? quantity,
    double? unitPrice,
    double? totalAmount,
    bool? isVibePrice,
    BookingStatus? bookingStatus,
    PaymentStatus? paymentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TicketBooking(
      id: id ?? this.id,
      bookingReference: bookingReference ?? this.bookingReference,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      isVibePrice: isVibePrice ?? this.isVibePrice,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'booking_reference': bookingReference,
      'user_id': userId,
      'event_id': eventId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'is_vibe_price': isVibePrice,
      'booking_status': bookingStatus.toString().split('.').last,
      'payment_status': paymentStatus.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TicketBooking.fromMap(Map<String, dynamic> map) {
    return TicketBooking(
      id: map['id'],
      bookingReference: map['booking_reference'],
      userId: map['user_id'],
      eventId: map['event_id'],
      quantity: map['quantity'],
      unitPrice: map['unit_price'].toDouble(),
      totalAmount: map['total_amount'].toDouble(),
      isVibePrice: map['is_vibe_price'],
      bookingStatus: BookingStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['booking_status'],
        orElse: () => BookingStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['payment_status'],
        orElse: () => PaymentStatus.unpaid,
      ),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  String toJson() => json.encode(toMap());

  factory TicketBooking.fromJson(String source) =>
      TicketBooking.fromMap(json.decode(source));

  @override
  String toString() {
    return 'TicketBooking(id: $id, bookingReference: $bookingReference, eventId: $eventId, quantity: $quantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TicketBooking && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
