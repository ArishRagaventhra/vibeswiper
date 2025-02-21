import 'dart:html' as html;
import 'dart:js' as js;
import 'platform_payment_service.dart';

PlatformPaymentService createPlatformPaymentService() => WebPaymentService();

class WebPaymentService implements PlatformPaymentService {
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
    // Create options for Razorpay web checkout
    final options = js.JsObject.jsify({
      'key': keyId,
      'amount': (amount * 100).toInt(),
      'currency': currency,
      'description': description,
      'prefill': {
        'email': userEmail,
        'contact': userContact,
      },
      'handler': js.allowInterop((response) {
        final paymentId = response['razorpay_payment_id'];
        final orderId = response['razorpay_order_id'];
        onSuccess(paymentId, orderId);
      }),
      'modal': {
        'ondismiss': js.allowInterop(() {
          onError('Payment cancelled by user');
        }),
      },
      'theme': {
        'color': '#6C63FF',
      },
    });

    // Load Razorpay script if not already loaded
    if (!_isRazorpayLoaded()) {
      await _loadRazorpayScript();
    }

    // Initialize Razorpay checkout
    try {
      final razorpay = js.context['Razorpay'];
      final checkout = js.JsObject(razorpay, [options]);
      checkout.callMethod('open');
    } catch (e) {
      onError('Error initializing payment: $e');
    }
  }

  bool _isRazorpayLoaded() {
    return js.context.hasProperty('Razorpay');
  }

  Future<void> _loadRazorpayScript() async {
    final script = html.ScriptElement()
      ..src = 'https://checkout.razorpay.com/v1/checkout.js'
      ..type = 'text/javascript';

    html.document.head!.append(script);

    // Wait for script to load
    await script.onLoad.first;
  }

  @override
  void dispose() {
    // No cleanup needed for web
  }
}
