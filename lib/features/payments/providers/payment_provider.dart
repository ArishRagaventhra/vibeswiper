import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/razorpay_config.dart';
import '../../events/services/event_creation_service.dart';
import '../models/payment.dart';
import '../repositories/payment_repository.dart';
import '../services/platform_payment_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final paymentProvider = StateNotifierProvider<PaymentNotifier, AsyncValue<List<Payment>>>((ref) {
  final repository = ref.watch(paymentRepositoryProvider);
  return PaymentNotifier(repository, ref);
});

// Add a provider to track current payment status
final currentPaymentProvider = StateProvider<AsyncValue<Payment?>>((ref) {
  return const AsyncValue.loading();
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PaymentRepository(supabase);
});

// Provider to trigger navigation to events page after successful payment
final navigateToEventsAfterPaymentProvider = StateProvider<bool>((ref) => false);

// Provide a global way to store a navigation function that can be called from anywhere
final globalNavigationFunctionProvider = StateProvider<Function?>((ref) => null);

class PaymentNotifier extends StateNotifier<AsyncValue<List<Payment>>> {
  final PaymentRepository _repository;
  final _paymentService = PlatformPaymentService.instance;
  String? _pendingEventId; // Store eventId temporarily during payment
  String? _pendingPaymentId; // Store Razorpay payment ID for status polling
  Timer? _pollingTimer; // Timer for polling payment status
  final Ref _ref;

  PaymentNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
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

  // Utility method to generate a unique order ID
  String _generateOrderId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000).toString().padLeft(4, '0');
    return 'order_${timestamp}_$random';
  }

  Future<void> initiateEventPayment({
    required String eventId,
    required String eventName,
    required String userEmail,
    required String userContact,
    required Function(Payment payment) onPaymentFinalized,
  }) async {
    try {
      _pendingEventId = eventId; // Store eventId for use after payment
      debugPrint('Initiating payment for event: $eventId');
      
      // Create a pending payment record BEFORE opening the Razorpay UI
      // This ensures we have a record regardless of what happens with Razorpay
      final userId = _getCurrentUserId();
      final pendingPayment = await _repository.createPayment(
        userId: userId,
        eventId: eventId,
        razorpayPaymentId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
        razorpayOrderId: _generateOrderId(),
        amount: RazorpayConfig.EVENT_CREATION_FEE,
        status: 'pending'
      );
      
      debugPrint('Created pending payment record: ${pendingPayment.id}');
      _pendingPaymentId = pendingPayment.razorpayPaymentId;
      
      // Update state with pending payment
      final currentPayments = state.value ?? [];
      state = AsyncValue.data([pendingPayment, ...currentPayments]);

      // Set up a timer to start polling immediately - this will detect both success and cancellation
      _startPaymentStatusPolling(onPaymentFinalized);

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
            
            // Check if we have a pending event ID
            if (_pendingEventId == null) {
              // Look for the user's most recent payment
              // This handles the case where a payment was auto-cancelled but later succeeded
              debugPrint('No pending event ID found. Looking for user\'s most recent payment...');
              final userId = _getCurrentUserId();
              final latestPayment = await _repository.getLatestPaymentForUser(userId);
              
              if (latestPayment != null && (latestPayment.status == 'cancelled' || latestPayment.status == 'pending')) {
                debugPrint('Found latest payment: ${latestPayment.id} with status ${latestPayment.status}');
                // Update payment status to success
                final updatedPayment = await _repository.updatePayment(
                  id: latestPayment.id,
                  userId: latestPayment.userId,
                  eventId: latestPayment.eventId,
                  razorpayPaymentId: paymentId,  // Update with the real Razorpay payment ID
                  razorpayOrderId: orderId ?? _generateOrderId(), // Update with the real Razorpay order ID
                  amount: latestPayment.amount,
                  status: 'success'
                );
                
                // If this was for event creation, handle it
                if (latestPayment.eventId.startsWith('temp_')) {
                  debugPrint('This was for event creation. Triggering delayed creation...');
                  // Get the event creation service and create the event from stored data
                  final eventCreationService = _ref.read(eventCreationServiceProvider);
                  final event = await eventCreationService.createEventFromDelayedPayment(latestPayment.eventId);
                  
                  if (event != null) {
                    debugPrint('Successfully created event from delayed payment: ${event.id}');
                    
                    // Try all available navigation methods
                    
                    // 1. Update state provider
                    _ref.read(navigateToEventsAfterPaymentProvider.notifier).state = true;
                    
                    // 2. Call global navigation function if available
                    final navigateFunction = _ref.read(globalNavigationFunctionProvider);
                    if (navigateFunction != null) {
                      try {
                        navigateFunction();
                        debugPrint('Called global navigation function after payment');
                      } catch (e) {
                        debugPrint('Error calling navigation function: $e');
                      }
                    }
                    
                    // 3. Try again with delay as backup
                    Future.delayed(Duration(milliseconds: 500), () {
                      // Try state update again
                      _ref.read(navigateToEventsAfterPaymentProvider.notifier).state = true;
                      
                      // Try function again
                      final navigateFunction = _ref.read(globalNavigationFunctionProvider);
                      if (navigateFunction != null) {
                        try {
                          navigateFunction();
                          debugPrint('Called delayed global navigation function');
                        } catch (e) {
                          debugPrint('Error calling delayed navigation function: $e');
                        }
                      }
                    });
                  }
                }
                
                // Reload payments to reflect the change
                await loadUserPayments();
                return;
              }
              
              throw Exception('No recent payment found');
            }

            final userId = _getCurrentUserId();
            final payment = await _repository.updatePayment(
              id: _pendingPaymentId!,
              userId: userId,
              eventId: _pendingEventId!,
              razorpayPaymentId: paymentId,
              razorpayOrderId: orderId ?? _generateOrderId(),
              amount: RazorpayConfig.EVENT_CREATION_FEE,
              status: 'success'
            );

            debugPrint('Payment updated in database: ${payment.id}');

            // Update state with updated payment
            final currentPayments = state.value ?? [];
            state = AsyncValue.data([payment, ...currentPayments.where((p) => p.id != payment.id)]);

            // Notify about finalized payment
            onPaymentFinalized(payment);
          } catch (e) {
            debugPrint("Error in payment success handler: $e");
            _handlePaymentError('Failed to process payment: ${e.toString()}');
            // Reload payments to ensure consistency
            await loadUserPayments();
          }
        },
        onError: (error) async {
          debugPrint("Payment error: $error");
          
          // Update payment status to cancelled
          final userId = _getCurrentUserId();
          final payment = await _repository.updatePayment(
            id: _pendingPaymentId!,
            userId: userId,
            eventId: _pendingEventId!,
            razorpayPaymentId: _pendingPaymentId!,
            razorpayOrderId: '',
            amount: RazorpayConfig.EVENT_CREATION_FEE,
            status: 'cancelled'
          );
          
          debugPrint('Updated cancelled payment record: ${payment.id}');
          
          // Update state with updated payment
          final currentPayments = state.value ?? [];
          state = AsyncValue.data([payment, ...currentPayments.where((p) => p.id != payment.id)]);
          
          // Safely notify about cancelled payment - wrap in try/catch
          try {
            onPaymentFinalized(payment);
          } catch (callbackError) {
            debugPrint('Error in payment finalization callback: $callbackError');
          }
          
          _handlePaymentError(error);
          // Reload payments to ensure consistency
          try {
            await loadUserPayments();
          } catch (e) {
            debugPrint('Error reloading payments: $e');
          }
        },
      );
    } catch (e) {
      debugPrint("Error initiating payment: $e");
      _handlePaymentError('Failed to initiate payment: ${e.toString()}');
      // Reload payments to ensure consistency
      await loadUserPayments();
    }
  }

  // New method to poll payment status after webhook updates
  void _startPaymentStatusPolling(Function(Payment payment) onPaymentFinalized) {
    _stopPaymentStatusPolling(); // Cancel any existing polling
    
    if (_pendingPaymentId == null) {
      debugPrint('No pending payment ID to poll');
      return;
    }
    
    debugPrint('Starting payment status polling for: $_pendingPaymentId');
    
    // Track how many times we've polled
    int pollCount = 0;
    final maxPolls = 15; // Stop after ~30 seconds (15 polls × 2 seconds)
    
    // Poll every 2 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        pollCount++;
        debugPrint('Poll #$pollCount for payment $_pendingPaymentId');
        
        final payment = await _repository.getPaymentByRazorpayId(_pendingPaymentId!);
        
        if (payment == null) {
          debugPrint('Payment not found during polling');
          return;
        }
        
        debugPrint('Polled payment status: ${payment.status}');
        
        // If payment is finalized (success or failed), stop polling
        if (payment.isFinalized) {
          debugPrint('Payment finalized with status: ${payment.status}');
          _stopPaymentStatusPolling();
          _pendingEventId = null;
          _pendingPaymentId = null;
          
          // Update payment list
          await loadUserPayments();
          
          // Notify about finalized payment
          onPaymentFinalized(payment);
          return;
        }
        
        // Auto-cancel payment if it's still pending after timeout
        if (pollCount >= maxPolls && payment.status == 'pending') {
          debugPrint('Payment timeout - auto-cancelling payment');
          
          // Update payment to cancelled status
          try {
            final userId = _getCurrentUserId();
            final cancelledPayment = await _repository.updatePayment(
              id: payment.id,
              userId: userId,
              eventId: payment.eventId,
              razorpayPaymentId: payment.razorpayPaymentId,
              razorpayOrderId: payment.razorpayOrderId ?? _generateOrderId(),
              amount: payment.amount,
              status: 'cancelled',
              errorMessage: 'Auto-cancelled due to timeout'
            );
            
            debugPrint('Auto-cancelled payment: ${cancelledPayment.id}');
            
            // Stop polling
            _stopPaymentStatusPolling();
            _pendingEventId = null;
            _pendingPaymentId = null;
            
            // Update payment list
            await loadUserPayments();
            
            // Notify about cancelled payment
            onPaymentFinalized(cancelledPayment);
          } catch (e) {
            debugPrint('Error auto-cancelling payment: $e');
          }
        }
      } catch (e) {
        debugPrint('Error polling payment status: $e');
      }
    });
  }
  
  void _stopPaymentStatusPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _handlePaymentError(String error) {
    _pendingEventId = null; // Clear stored eventId
    _pendingPaymentId = null; // Clear stored payment ID
    _stopPaymentStatusPolling(); // Stop any polling
    state = AsyncValue.error(Exception(error), StackTrace.current);
  }

  String _getCurrentUserId() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');
    return user.id;
  }

  // Check payment status manually (can be called from UI)
  Future<Payment?> checkPaymentStatus(String razorpayPaymentId) async {
    try {
      final payment = await _repository.getPaymentByRazorpayId(razorpayPaymentId);
      return payment;
    } catch (e) {
      debugPrint('Error checking payment status: $e');
      return null;
    }
  }

  // Handle webhook update for payment - can update canceled payments if they actually succeeded
  Future<void> handleWebhookPaymentUpdate(String paymentId, String status) async {
    try {
      debugPrint('Webhook update for payment $paymentId: status=$status');
      
      // Look for any payment with this Razorpay ID
      final payment = await _repository.getPaymentByRazorpayId(paymentId);
      
      if (payment == null) {
        debugPrint('Payment not found for webhook update');
        return;
      }
      
      // If payment was previously marked as cancelled but is now successful, handle that special case
      if (payment.status == 'cancelled' && status == 'success') {
        debugPrint('Payment was previously cancelled but is now successful - special handling');
        
        // Update payment status first
        final updatedPayment = await _repository.updatePayment(
          id: payment.id,
          userId: payment.userId,
          eventId: payment.eventId,
          razorpayPaymentId: payment.razorpayPaymentId,
          razorpayOrderId: payment.razorpayOrderId ?? _generateOrderId(),
          amount: payment.amount,
          status: 'success'
        );
        
        // Check if this was a payment for event creation (eventId starts with 'temp_')
        if (payment.eventId.startsWith('temp_')) {
          // This was a payment for event creation that was cancelled but later succeeded
          // We need to trigger event creation now
          debugPrint('Triggering delayed event creation for payment: ${payment.id}');
          
          // Get the event creation service and create the event from stored data
          final eventCreationService = _ref.read(eventCreationServiceProvider);
          final event = await eventCreationService.createEventFromDelayedPayment(payment.eventId);
          
          if (event != null) {
            debugPrint('Successfully created event from delayed payment: ${event.id}');
            // Finalize the event since payment was successful
            await eventCreationService.finalizeEventCreation(event.id);
          }
        }
        
        // Reload payments
        await loadUserPayments();
      } else {
        // Normal update flow
        await _repository.updatePaymentStatus(
          paymentId: payment.id,
          status: status,
        );
        
        // Reload payments
        await loadUserPayments();
      }
    } catch (e) {
      debugPrint('Error handling webhook payment update: $e');
    }
  }

  // Monitor payments for event creation
  Future<void> monitorEventCreationPayment({
    required String eventId,
    required Function(Payment payment) onPaymentFinalized,
  }) async {
    try {
      debugPrint('Monitoring payment for event: $eventId');
      
      // Get the most recent payment for this event
      final payments = await _repository.getPaymentsByEventId(eventId);
      if (payments.isEmpty) {
        debugPrint('No payments found for event: $eventId');
        return;
      }
      
      // Get the most recent payment
      final payment = payments.first;
      _pendingPaymentId = payment.razorpayPaymentId;
      
      // Start polling for webhook updates
      _startPaymentStatusPolling(onPaymentFinalized);
    } catch (e) {
      debugPrint('Error monitoring event creation payment: $e');
    }
  }

  @override
  void dispose() {
    _stopPaymentStatusPolling();
    _paymentService.dispose();
    super.dispose();
  }
}
