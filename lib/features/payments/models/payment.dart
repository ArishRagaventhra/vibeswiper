class Payment {
  final String id;
  final String userId;
  final String eventId;
  final double amount;
  final String razorpayPaymentId;
  final String razorpayOrderId;
  final String status;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.amount,
    required this.razorpayPaymentId,
    required this.razorpayOrderId,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventId: json['event_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      razorpayPaymentId: json['razorpay_payment_id'] as String,
      razorpayOrderId: json['razorpay_order_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_id': eventId,
      'amount': amount,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_order_id': razorpayOrderId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
