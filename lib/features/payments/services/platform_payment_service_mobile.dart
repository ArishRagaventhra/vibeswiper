import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../config/razorpay_config.dart';
import 'platform_payment_service.dart';
import 'package:flutter/foundation.dart';

PlatformPaymentService createPlatformPaymentService() => MobilePaymentService();

class MobilePaymentService implements PlatformPaymentService {
  late final Razorpay _razorpay;

  MobilePaymentService() {
    _razorpay = Razorpay();
  }

  @override
  Future<void> initializePayment({
    required String keyId,
    required double amount,
    required String currency,
    required String description,
    required String userEmail,
    required String userContact,
    required Function(String paymentId, String? orderId) onSuccess,
    required Function(String error) onError,
  }) async {
    try {
      // Remove any existing handlers
      _razorpay.clear();

      // Add handlers
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
        debugPrint('Payment success: paymentId=${response.paymentId}, orderId=${response.orderId}');
        if (response.paymentId != null) {
          onSuccess(response.paymentId!, response.orderId);
        } else {
          onError('Payment ID is null');
        }
      });

      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
        debugPrint('Payment error: code=${response.code}, message=${response.message}');
        try {
          // Use a safer approach when calling the error handler
          // The message might be null, so provide a fallback
          final errorMessage = response.message ?? 'Payment failed or was cancelled';
          onError(errorMessage);
        } catch (e) {
          // If callback execution fails, at least log it
          debugPrint('Error in payment error callback: $e');
        }
      });

      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
        debugPrint("External wallet selected: ${response.walletName}");
      });

      final options = {
        'key': keyId,
        'amount': (amount * 100).toInt(),
        'currency': currency,
        'description': description,
        'prefill': {
          'contact': userContact.startsWith('+') ? userContact : '+91$userContact',
          'email': userEmail,
        },
        'external': {
          'wallets': ['paytm']
        },
        'theme': {
          'color': '#6C63FF',
        },
        'send_sms_hash': true,
      };

      debugPrint('Opening Razorpay with options: $options');
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error in initializePayment: $e');
      onError('Error initializing payment: $e');
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
  }
}
