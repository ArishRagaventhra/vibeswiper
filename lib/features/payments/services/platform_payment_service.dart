import 'package:flutter/foundation.dart';
import 'platform_payment_service_web.dart' if (dart.library.io) 'platform_payment_service_mobile.dart';

abstract class PlatformPaymentService {
  static PlatformPaymentService get instance => createPlatformPaymentService();

  Future<void> initializePayment({
    required String keyId,
    required double amount,
    required String currency,
    required String description,
    required String userEmail,
    required String userContact,
    required Function(String paymentId, String? orderId) onSuccess,
    required Function(String error) onError,
  });

  void dispose();
}
