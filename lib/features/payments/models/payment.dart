class Payment {
  final String id;
  final String userId;
  final String eventId;
  final double amount;
  final String razorpayPaymentId;
  final String razorpayOrderId;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? errorMessage;
  final Map<String, dynamic>? paymentDetails;

  const Payment({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.amount,
    required this.razorpayPaymentId,
    required this.razorpayOrderId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.errorMessage,
    this.paymentDetails,
  });

  // Simplified constructor for placeholder payments
  Payment.placeholder({
    required this.razorpayPaymentId,
    required bool isSuccessful,
  }) : 
    id = 'placeholder_id',
    userId = 'placeholder_user',
    eventId = '00000000-0000-0000-0000-000000000000',
    amount = 499.0,
    razorpayOrderId = 'placeholder_order',
    status = isSuccessful ? 'success' : 'failed',
    createdAt = DateTime.now(),
    updatedAt = DateTime.now(),
    errorMessage = isSuccessful ? null : 'Test payment error',
    paymentDetails = {
      'test': true,
      'environment': 'development'
    };

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
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      errorMessage: json['error_message'] as String?,
      paymentDetails: json['payment_details'] as Map<String, dynamic>?,
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
      'updated_at': updatedAt?.toIso8601String(),
      'error_message': errorMessage,
      'payment_details': paymentDetails,
    };
  }

  bool get isSuccessful => status == 'success';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';
  bool get isFinalized => isSuccessful || isFailed;

  @override
  String toString() => 'Payment{id: $id, status: $status}';
}
