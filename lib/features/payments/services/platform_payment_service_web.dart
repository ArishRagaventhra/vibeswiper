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
    String? orderId,
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
      // Track payment interactions (as per user preference)
      'notes': {
        'platform': 'web',
        'source': 'vibe_swiper'
      },
      // Auto-capture payment immediately instead of just authorizing
      'capture': true,
      'handler': js.allowInterop((response) {
        try {
          final paymentId = response['razorpay_payment_id'];
          final orderId = response['razorpay_order_id'];
          onSuccess(paymentId, orderId);
        } catch (e) {
          print('Error in payment success handler: $e');
          onError('Payment processing error: $e');
        }
      }),
      'modal': {
        'ondismiss': js.allowInterop((_) {
          try {
            print('Payment modal dismissed by user');
            onError('Payment cancelled by user');
          } catch (e) {
            print('Error in ondismiss handler: $e');
            // Last resort to prevent app freezing
            try {
              onError('Payment cancelled');
            } catch (_) {}
          }
        }),
        'escape': true,
        'animation': true
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
      
      // Add order ID if provided - critical for auto-capture
      if (orderId != null) {
        options['order_id'] = orderId;
        print('Using Razorpay Order ID: $orderId');
      }
      
      // Add explicit handling for payment failed events
      checkout['on'] = js.allowInterop((String event, js.JsFunction handler) {
        if (event == 'payment.failed') {
          handler.callMethod('call', [js.JsObject.jsify({
            'error': {
              'description': 'Payment failed',
            }
          })]);
        }
      });
      
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
