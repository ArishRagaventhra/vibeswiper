import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/razorpay_config.dart';
import '../models/payment.dart';
import '../repositories/payment_repository.dart';
import '../services/platform_payment_service.dart';
import 'package:flutter/foundation.dart';

// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final paymentProvider = StateNotifierProvider<PaymentNotifier, AsyncValue<List<Payment>>>((ref) {
  final repository = ref.watch(paymentRepositoryProvider);
  return PaymentNotifier(repository);
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PaymentRepository(supabase);
});

class PaymentNotifier extends StateNotifier<AsyncValue<List<Payment>>> {
  final PaymentRepository _repository;
  final _paymentService = PlatformPaymentService.instance;
  String? _pendingEventId; // Store eventId temporarily during payment

  PaymentNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadUserPayments();
  }

  Future<void> loadUserPayments() async {
    try {
      state = const AsyncValue.loading();
      final userId = _getCurrentUserId();
      final payments = await _repository.getUserPayments(userId);
      state = AsyncValue.data(payments);
    } catch (e, st) {
      debugPrint('Error loading payments: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> initiateEventPayment({
    required String eventId,
    required String eventName,
    required String userEmail,
    required String userContact,
  }) async {
    try {
      _pendingEventId = eventId; // Store eventId for use after payment
      debugPrint('Initiating payment for event: $eventId');

      await _paymentService.initializePayment(
        keyId: RazorpayConfig.keyId,
        amount: RazorpayConfig.EVENT_CREATION_FEE,
        currency: RazorpayConfig.CURRENCY,
        description: 'Platform fee for event: $eventName',
        userEmail: userEmail,
        userContact: userContact,
        onSuccess: (paymentId, orderId) async {
          try {
            debugPrint('Payment success callback - paymentId: $paymentId, orderId: $orderId');
            
            if (_pendingEventId == null) {
              throw Exception('No pending event ID found');
            }

            final userId = _getCurrentUserId();
            final payment = await _repository.createPayment(
              userId: userId,
              eventId: _pendingEventId!,
              razorpayPaymentId: paymentId,
              razorpayOrderId: orderId ?? '',
              amount: RazorpayConfig.EVENT_CREATION_FEE,
            );

            debugPrint('Payment created in database: ${payment.id}');

            // Update state with new payment
            final currentPayments = state.value ?? [];
            state = AsyncValue.data([payment, ...currentPayments]);

            _pendingEventId = null; // Clear stored eventId
            _notifyEventCreationSuccess();
          } catch (e) {
            debugPrint("Error in payment success handler: $e");
            _handlePaymentError('Failed to process payment: ${e.toString()}');
            // Reload payments to ensure consistency
            await loadUserPayments();
          }
        },
        onError: (error) {
          debugPrint("Payment error: $error");
          _handlePaymentError(error);
          // Reload payments to ensure consistency
          loadUserPayments();
        },
      );
    } catch (e) {
      debugPrint("Error initiating payment: $e");
      _handlePaymentError('Failed to initiate payment: ${e.toString()}');
      // Reload payments to ensure consistency
      await loadUserPayments();
    }
  }

  void _handlePaymentError(String error) {
    _pendingEventId = null; // Clear stored eventId
    state = AsyncValue.error(Exception(error), StackTrace.current);
  }

  String _getCurrentUserId() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');
    return user.id;
  }

  void _notifyEventCreationSuccess() {
    // Implement this based on your event creation flow
    debugPrint('Event creation success notification');
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }
}
