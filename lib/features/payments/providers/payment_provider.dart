import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/razorpay_config.dart';
import '../../events/services/event_creation_service.dart';
import '../models/payment.dart';
import '../repositories/payment_repository.dart';
import '../services/platform_payment_service.dart';
import '../services/razorpay_order_service.dart';
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

// Add a provider to track webhook status updates
final webhookPaymentUpdateProvider = StreamProvider<Payment?>((ref) {
  final controller = StreamController<Payment?>();
  
  // This stream will be updated by the webhook handler
  return controller.stream;
});

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
    double? vibePrice,
  }) async {
    try {
      _pendingEventId = eventId; // Store eventId for use after payment
      debugPrint('Initiating payment for event: $eventId');
      
      // Calculate payment amount based on vibe price
      final paymentAmount = RazorpayConfig.calculatePaymentAmount(vibePrice);
      debugPrint('Payment amount calculated: $paymentAmount');
      
      // Generate a unique receipt ID for order creation
      final receiptId = 'receipt_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      
      // Create pending payment record first 
      final userId = _getCurrentUserId();
      String tempOrderId = 'temp_order_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create a Razorpay order first - this is required for auto-capture to work
      // Skip direct order creation on web platforms
      String? razorpayOrderId;
      if (!kIsWeb) {
        try {
          // Only create Razorpay order on mobile platforms
          final orderService = RazorpayOrderService();
          final orderData = await orderService.createOrder(
            amount: paymentAmount,
            currency: RazorpayConfig.CURRENCY,
            receiptId: receiptId,
            notes: {
              'event_id': eventId,
              'event_name': eventName,
              'user_email': userEmail,
              'user_contact': userContact,
            },
          );
          razorpayOrderId = orderData['id'];
          debugPrint('Razorpay order created: $razorpayOrderId');
          if (razorpayOrderId != null) {
            tempOrderId = razorpayOrderId;
          }
        } catch (e) {
          debugPrint('Error creating order (mobile only): $e');
          // Continue without order ID on web
        }
      }
      
      // Create a pending payment record with the order ID
      final pendingPayment = await _repository.createPayment(
        userId: userId,
        eventId: eventId,
        razorpayPaymentId: 'pending_${DateTime.now().millisecondsSinceEpoch}', // Temporary ID
        razorpayOrderId: tempOrderId, // Store the real Razorpay order ID or temp ID for web
        amount: paymentAmount,
        status: 'pending'
      );
      
      debugPrint('Created pending payment record: ${pendingPayment.id}');
      _pendingPaymentId = pendingPayment.id; // Store the database record ID, not the Razorpay ID
      
      // Update state with pending payment
      final currentPayments = state.value ?? [];
      state = AsyncValue.data([pendingPayment, ...currentPayments]);

      await _paymentService.initializePayment(
        keyId: RazorpayConfig.keyId,
        amount: paymentAmount,
        currency: RazorpayConfig.CURRENCY,
        description: RazorpayConfig.getPaymentDescription(eventName),
        userEmail: userEmail,
        userContact: userContact,
        orderId: razorpayOrderId, // Pass the Razorpay order ID to ensure auto-capture works, will be null on web
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
              amount: paymentAmount,
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
        onError: (dynamic error) async {
          // Safe handling of error which might be null when user cancels
          final errorMessage = error != null ? error.toString() : 'User cancelled payment';
          debugPrint("Payment error or cancellation: $errorMessage");
          
          try {
            // Check if we have valid IDs before proceeding
            if (_pendingPaymentId == null || _pendingEventId == null) {
              debugPrint('Missing pendingPaymentId or pendingEventId, cannot update payment');
              _pendingEventId = null;
              _pendingPaymentId = null;
              // Set a clean error state to ensure UI is updated
              try {
                state = AsyncValue.error(Exception('Payment cancelled'), StackTrace.current);
              } catch (stateError) {
                debugPrint('Error setting cancelled state: $stateError');
                state = const AsyncValue.data([]);
              }
              return;
            }
            
            // Safely update payment status to cancelled
            // Generate a unique cancel ID to avoid unique constraint violations
            final cancelId = 'cancel_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
            
            final userId = _getCurrentUserId();
            final payment = await _repository.updatePayment(
              id: _pendingPaymentId!, // This is the database ID, not Razorpay ID
              userId: userId,
              eventId: _pendingEventId!,
              razorpayPaymentId: cancelId, // Use a unique ID for cancelled payments too
              razorpayOrderId: '',
              amount: paymentAmount,
              status: 'cancelled',
              errorMessage: 'User manually cancelled payment'
            );
            
            debugPrint('Updated cancelled payment record: ${payment.id}');
            
            // Update state with updated payment
            try {
              final currentPayments = state.value ?? [];
              state = AsyncValue.data([payment, ...currentPayments.where((p) => p.id != payment.id)]);
            } catch (stateError) {
              debugPrint('Error updating payment state: $stateError');
            }
            
            // Clear pending state immediately
            _pendingEventId = null;
            _pendingPaymentId = null;
            
            // Safely notify about cancelled payment - wrap in try/catch
            try {
              onPaymentFinalized(payment);
            } catch (callbackError) {
              debugPrint('Error in payment finalization callback: $callbackError');
            }
            
            // Reload payments to ensure consistency
            await loadUserPayments();
          } catch (e) {
            debugPrint('Error handling payment cancellation: $e');
            // Last resort error handling to prevent app from getting stuck
            _pendingEventId = null;
            _pendingPaymentId = null;
            
            // Try to set a clean state
            try {
              state = const AsyncValue.data([]);
            } catch (stateError) {
              debugPrint('Error setting error recovery state: $stateError');
            }
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

  // Special method for ticket booking payments that skips direct order creation
  // and uses platform-specific implementation
  Future<void> initiateTicketBookingPayment({
    required String bookingId,
    required String eventId,
    required String eventName,
    required String userEmail,
    required String userContact,
    required double amount,
    required Function(Payment payment) onPaymentFinalized,
  }) async {
    try {
      debugPrint('Initiating ticket booking payment: $eventId, booking: $bookingId');
      
      final userId = _getCurrentUserId();
      
      // Create a pending payment record
      final pendingPayment = await _repository.createPayment(
        userId: userId,
        eventId: eventId,
        razorpayPaymentId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
        razorpayOrderId: 'booking_$bookingId',
        amount: amount,
        status: 'pending'
      );
      
      // Update state with pending payment
      final currentPayments = state.value ?? [];
      state = AsyncValue.data([pendingPayment, ...currentPayments]);

      // Skip direct order creation on web platforms
      String? razorpayOrderId;
      if (!kIsWeb) {
        try {
          // Only create Razorpay order on mobile platforms
          final receiptId = 'receipt_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
          final orderService = RazorpayOrderService();
          final orderData = await orderService.createOrder(
            amount: amount,
            currency: RazorpayConfig.CURRENCY,
            receiptId: receiptId,
            notes: {
              'booking_id': bookingId,
              'event_id': eventId,
              'event_name': eventName,
              'user_email': userEmail,
            },
          );
          razorpayOrderId = orderData['id'];
          debugPrint('Razorpay order created: $razorpayOrderId');
        } catch (e) {
          debugPrint('Error creating order (mobile only): $e');
          // Continue without order ID on web
        }
      }
      
      // Use platform-specific payment service
      await _paymentService.initializePayment(
        keyId: RazorpayConfig.keyId,
        amount: amount,
        currency: RazorpayConfig.CURRENCY,
        description: 'Booking for: $eventName',
        userEmail: userEmail,
        userContact: userContact,
        orderId: razorpayOrderId, // May be null on web platforms
        onSuccess: (paymentId, orderId) async {
          try {
            debugPrint('Payment success - paymentId: $paymentId, orderId: $orderId');
            
            // Update the payment in the database
            final updatedPayment = await _repository.updatePayment(
              id: pendingPayment.id,
              userId: userId,
              eventId: eventId,
              razorpayPaymentId: paymentId,
              razorpayOrderId: orderId ?? razorpayOrderId ?? 'auto_gen_${DateTime.now().millisecondsSinceEpoch}',
              amount: amount,
              status: 'success'
            );
            
            // Update our state
            _updatePaymentInState(updatedPayment);
            
            // Notify listener of success
            onPaymentFinalized(updatedPayment);
            
          } catch (e) {
            debugPrint('Error handling payment success: $e');
            
            // Try to create a success record anyway
            try {
              final successPayment = Payment(
                id: pendingPayment.id,
                userId: userId,
                eventId: eventId,
                razorpayPaymentId: paymentId,
                razorpayOrderId: orderId ?? 'unknown',
                amount: amount,
                status: 'success',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              
              onPaymentFinalized(successPayment);
            } catch (_) {
              // Last resort
              onPaymentFinalized(pendingPayment.copyWith(status: 'unknown'));
            }
          }
        },
        onError: (error) async {
          debugPrint('Payment error: $error');
          
          try {
            // Update payment status to failed
            final failedPayment = await _repository.updatePayment(
              id: pendingPayment.id,
              userId: userId,
              eventId: eventId,
              razorpayPaymentId: pendingPayment.razorpayPaymentId,
              razorpayOrderId: pendingPayment.razorpayOrderId,
              amount: amount,
              status: 'failed'
            );
            
            // Update our state
            _updatePaymentInState(failedPayment);
            
            // Notify listener of failure
            onPaymentFinalized(failedPayment);
          } catch (e) {
            debugPrint('Error updating payment status to failed: $e');
            
            // Fallback
            final failedPayment = pendingPayment.copyWith(status: 'failed');
            onPaymentFinalized(failedPayment);
          }
        },
      );
    } catch (e, st) {
      debugPrint('Error initiating ticket booking payment: $e');
      state = AsyncValue.error(e, st);
      
      // Create a failed payment for the callback
      final failedPayment = Payment(
        id: 'failed_${DateTime.now().millisecondsSinceEpoch}',
        userId: _getCurrentUserId(),
        eventId: eventId,
        razorpayPaymentId: 'failed',
        razorpayOrderId: 'failed',
        amount: amount,
        status: 'error',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      onPaymentFinalized(failedPayment);
    }
  }

  // Method to stop any existing polling (kept for compatibility)
  void _stopPaymentStatusPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
  
  // Helper method to update a payment in the state list
  void _updatePaymentInState(Payment updatedPayment) {
    final currentPayments = state.value ?? [];
    final updatedPayments = currentPayments.map((payment) {
      // Replace the payment with the same ID
      if (payment.id == updatedPayment.id) {
        return updatedPayment;
      }
      return payment;
    }).toList();
    
    // Update state with the new payment list
    state = AsyncValue.data(updatedPayments);
  }
  
  // Helper to get current user ID
  String _getCurrentUserId() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');
    return user.id;
  }

  void _handlePaymentError(String error) {
    _pendingEventId = null; // Clear stored eventId
    _pendingPaymentId = null; // Clear stored payment ID
    _stopPaymentStatusPolling(); // Stop any polling
    try {
      state = AsyncValue.error(Exception(error), StackTrace.current);
    } catch (e) {
      debugPrint('Error setting error state: $e');
      // Fallback to ensure we don't get stuck
      state = const AsyncValue.data([]);
    }
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
      var payment = await _repository.getPaymentByRazorpayId(paymentId);
      
      // If not found by razorpay_payment_id, it's possible this is a new payment ID
      // that needs to be associated with our pending payment
      if (payment == null) {
        debugPrint('Payment not found by razorpay_payment_id, looking for pending payment...');
        
        // Try to find the most recent pending payment for current user
        // This assumes the webhook corresponds to the most recent payment
        try {
          final userId = _getCurrentUserId();
          final pendingPayments = await _repository.getUserPaymentsWithStatus(userId, 'pending');
          
          if (pendingPayments.isNotEmpty) {
            // Assume the most recent pending payment is the one this webhook refers to
            final pendingPayment = pendingPayments.first;
            debugPrint('Found pending payment ${pendingPayment.id}, updating with real razorpay ID $paymentId');
            
            // Update the payment with the real Razorpay payment ID
            payment = await _repository.updatePayment(
              id: pendingPayment.id,
              userId: pendingPayment.userId,
              eventId: pendingPayment.eventId,
              razorpayPaymentId: paymentId, // Set the real Razorpay payment ID
              razorpayOrderId: pendingPayment.razorpayOrderId ?? '',
              amount: pendingPayment.amount,
              status: status // Update status from webhook
            );
            
            // Trigger navigation if payment is successful
            if (status == 'success') {
              _ref.read(navigateToEventsAfterPaymentProvider.notifier).state = true;
              
              // Also call global navigation function if available
              final navigateFunction = _ref.read(globalNavigationFunctionProvider);
              if (navigateFunction != null) {
                try {
                  navigateFunction();
                } catch (e) {
                  debugPrint('Error calling navigation function: $e');
                }
              }
            }
            
            // Reload payments to reflect the changes
            await loadUserPayments();
            return;
          } else {
            debugPrint('No pending payment found for current user');
          }
        } catch (e) {
          debugPrint('Error looking for pending payment: $e');
        }
        
        debugPrint('No payment found to update for webhook');
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
            
            // Trigger navigation
            _ref.read(navigateToEventsAfterPaymentProvider.notifier).state = true;
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
        
        // If payment is now successful, trigger navigation
        if (status == 'success') {
          _ref.read(navigateToEventsAfterPaymentProvider.notifier).state = true;
        }
        
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
      _pendingPaymentId = payment.id; // Store the database ID
      _pendingEventId = eventId;
      
      // Check if the payment already has a successful status
      if (payment.status == 'success') {
        debugPrint('Payment already successful, finalizing');
        onPaymentFinalized(payment);
      } else {
        debugPrint('Payment pending webhook update, current status: ${payment.status}');
        // No need to poll - we'll wait for the webhook to update the payment status
      }
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
