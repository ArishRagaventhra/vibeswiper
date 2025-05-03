import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ticket_booking_model.dart';
import '../models/event_model.dart';
import '../providers/event_providers.dart';
import '../repositories/ticket_booking_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../payments/services/platform_payment_service.dart';
import '../../payments/services/razorpay_order_service.dart';
import '../../payments/providers/payment_provider.dart';
import '../../../config/razorpay_config.dart';
import 'package:flutter/foundation.dart';

// Booking state that tracks the current booking
class BookingState {
  final Event? event;
  final int quantity;
  final bool isVibePrice;
  final String? error;
  final bool isLoading;
  final TicketBooking? confirmedBooking;

  BookingState({
    this.event,
    this.quantity = 1,
    this.isVibePrice = true,
    this.error,
    this.isLoading = false,
    this.confirmedBooking,
  });

  BookingState copyWith({
    Event? event,
    int? quantity,
    bool? isVibePrice,
    String? error,
    bool? isLoading,
    TicketBooking? confirmedBooking,
  }) {
    return BookingState(
      event: event ?? this.event,
      quantity: quantity ?? this.quantity,
      isVibePrice: isVibePrice ?? this.isVibePrice,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      confirmedBooking: confirmedBooking ?? this.confirmedBooking,
    );
  }

  // Calculate the total amount based on the current state
  double get totalAmount {
    if (event == null) return 0.0;
    final price = isVibePrice ? event!.vibePrice : event!.ticketPrice;
    return (price ?? 0.0) * quantity;
  }

  double get regularTotal {
    if (event == null) return 0.0;
    return (event!.ticketPrice ?? 0.0) * quantity;
  }

  double get discount {
    if (event == null || !isVibePrice) return 0.0;
    final regularPrice = event!.ticketPrice ?? 0.0;
    final vibePrice = event!.vibePrice ?? 0.0;
    return (regularPrice - vibePrice) * quantity;
  }
}

final ticketBookingControllerProvider = StateNotifierProvider.autoDispose<TicketBookingController, BookingState>((ref) {
  return TicketBookingController(
    ref.watch(ticketBookingRepositoryProvider),
    ref,
  );
});

class TicketBookingController extends StateNotifier<BookingState> {
  final TicketBookingRepository _repository;
  final Ref _ref;
  final _paymentService = PlatformPaymentService.instance;
  final _razorpayOrderService = RazorpayOrderService();

  TicketBookingController(
    this._repository,
    this._ref,
  ) : super(BookingState());

  // Initialize with event
  void setEvent(Event event) {
    state = state.copyWith(
      event: event,
      quantity: 1,
      isVibePrice: true,
      error: null,
      isLoading: false,
      confirmedBooking: null,
    );
  }

  // Update ticket quantity
  void updateQuantity(int quantity) {
    if (quantity < 1) quantity = 1;
    state = state.copyWith(quantity: quantity);
  }

  // Toggle between Vibe Price and Regular Price
  void togglePriceType() {
    state = state.copyWith(isVibePrice: !state.isVibePrice);
  }

  // Create a booking
  Future<void> createBooking() async {
    if (state.event == null) {
      state = state.copyWith(
        error: 'No event selected',
        isLoading: false,
      );
      return;
    }

    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = state.copyWith(
        error: 'You must be logged in to book tickets',
        isLoading: false,
      );
      return;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      final unitPrice = state.isVibePrice 
          ? state.event!.vibePrice 
          : state.event!.ticketPrice;
      
      if (unitPrice == null) {
        state = state.copyWith(
          error: 'Ticket price not available',
          isLoading: false,
        );
        return;
      }

      final booking = await _repository.createBooking(
        userId: currentUser.id,
        eventId: state.event!.id,
        quantity: state.quantity,
        unitPrice: unitPrice,
        totalAmount: state.totalAmount,
        isVibePrice: state.isVibePrice,
      );

      // Record the interaction
      await _repository.recordPaymentInteraction(
        userId: currentUser.id,
        eventId: state.event!.id,
        interactionType: 'booking_initiated',
        bookingId: booking.id,
      );

      state = state.copyWith(
        confirmedBooking: booking,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to create booking: $e',
        isLoading: false,
      );
    }
  }

  // Record payment interaction (QR scan, link touch, etc.)
  Future<void> recordInteraction(
    String interactionType, 
    {String? paymentMethod, bool? succeeded}
  ) async {
    try {
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser == null || state.event == null) return;

      await _repository.recordPaymentInteraction(
        userId: currentUser.id,
        eventId: state.event!.id,
        interactionType: interactionType,
        bookingId: state.confirmedBooking?.id,
        paymentMethod: paymentMethod,
        succeeded: succeeded,
      );
    } catch (e) {
      // Log error but don't update state since this is a background operation
      print('Failed to record interaction: $e');
    }
  }

  // Process payment for a booking
  Future<void> processPayment({
    required String paymentMethod,
    String? paymentProvider,
    String? paymentReference,
  }) async {
    if (state.confirmedBooking == null) {
      state = state.copyWith(
        error: 'No active booking to process payment',
        isLoading: false,
      );
      return;
    }

    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = state.copyWith(
        error: 'You must be logged in to process payment',
        isLoading: false,
      );
      return;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      // Create payment transaction
      await _repository.createPaymentTransaction(
        bookingId: state.confirmedBooking!.id,
        userId: currentUser.id,
        paymentMethod: paymentMethod,
        paymentProvider: paymentProvider,
        amount: state.totalAmount,
        status: 'completed',
        paymentReference: paymentReference,
      );

      // Update booking payment status
      await _repository.updatePaymentStatus(
        bookingId: state.confirmedBooking!.id,
        status: PaymentStatus.paid,
      );

      // Update booking status
      await _repository.updateBookingStatus(
        bookingId: state.confirmedBooking!.id,
        status: BookingStatus.confirmed,
      );

      // Get updated booking
      final updatedBooking = await _repository.getBookingById(
        state.confirmedBooking!.id,
      );

      // Record the interaction
      await _repository.recordPaymentInteraction(
        userId: currentUser.id,
        eventId: state.event!.id,
        interactionType: 'payment_completed',
        bookingId: state.confirmedBooking!.id,
        paymentMethod: paymentMethod,
        succeeded: true,
      );

      state = state.copyWith(
        confirmedBooking: updatedBooking,
        isLoading: false,
      );
    } catch (e) {
      // Record failed payment
      await _repository.recordPaymentInteraction(
        userId: currentUser.id,
        eventId: state.event!.id,
        interactionType: 'payment_failed',
        bookingId: state.confirmedBooking!.id,
        paymentMethod: paymentMethod,
        succeeded: false,
      );

      state = state.copyWith(
        error: 'Payment processing failed: $e',
        isLoading: false,
      );
    }
  }

  // Process payment using Razorpay
  Future<void> processRazorpayPayment({
    required String userEmail,
    required String userContact,
    required Function(bool success, String? message) onPaymentComplete,
  }) async {
    if (state.confirmedBooking == null) {
      state = state.copyWith(
        error: 'No active booking to process payment',
        isLoading: false,
      );
      onPaymentComplete(false, 'No active booking to process payment');
      return;
    }

    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = state.copyWith(
        error: 'You must be logged in to process payment',
        isLoading: false,
      );
      onPaymentComplete(false, 'You must be logged in to process payment');
      return;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // Record interaction: payment_initiated
      await recordInteraction('payment_initiated', paymentMethod: 'razorpay');
      
      // Get payment provider from the imported provider
      final paymentNotifier = _ref.read(paymentProvider.notifier);
      
      // Use the booking-specific payment method that handles platform differences
      await paymentNotifier.initiateTicketBookingPayment(
        bookingId: state.confirmedBooking!.id,
        eventId: state.event!.id,
        eventName: state.event!.title,
        userEmail: userEmail,
        userContact: userContact,
        amount: state.totalAmount, // Use booking amount
        onPaymentFinalized: (payment) async {
          try {
            if (payment.status == 'success') {
              debugPrint('Payment successful: ${payment.razorpayPaymentId}');
              
              // Now update our booking records AFTER payment is successful
              await _repository.updatePaymentStatus(
                bookingId: state.confirmedBooking!.id,
                status: PaymentStatus.paid,
              );
              
              await _repository.updateBookingStatus(
                bookingId: state.confirmedBooking!.id,
                status: BookingStatus.confirmed,
              );
              
              // Link the payment to our booking
              await _repository.createPaymentTransaction(
                bookingId: state.confirmedBooking!.id,
                userId: currentUser.id,
                paymentMethod: 'razorpay',
                paymentProvider: 'razorpay',
                amount: state.totalAmount,
                status: 'completed',
                paymentReference: payment.razorpayPaymentId,
                metadata: {
                  'order_id': payment.razorpayOrderId,
                },
              );
              
              // Record interaction: payment_completed
              await recordInteraction(
                'payment_completed', 
                paymentMethod: 'razorpay',
                succeeded: true,
              );
              
              // Get updated booking
              final updatedBooking = await _repository.getBookingById(
                state.confirmedBooking!.id,
              );
              
              state = state.copyWith(
                confirmedBooking: updatedBooking,
                isLoading: false,
              );
              
              onPaymentComplete(true, 'Payment completed successfully');
            } else {
              // Handle failed payment
              debugPrint('Payment failed: ${payment.status}');
              
              // Record payment failure
              await recordInteraction(
                'payment_failed',
                paymentMethod: 'razorpay',
                succeeded: false,
              );
              
              state = state.copyWith(
                error: 'Payment failed',
                isLoading: false,
              );
              
              onPaymentComplete(false, 'Payment failed');
            }
          } catch (e) {
            debugPrint('Error handling payment: $e');
            
            // Record error
            await recordInteraction(
              'payment_error_handling',
              paymentMethod: 'razorpay',
              succeeded: false,
            );
            
            state = state.copyWith(
              error: 'Error processing payment: $e',
              isLoading: false,
            );
            
            onPaymentComplete(false, 'Error processing payment: $e');
          }
        },
      );
    } catch (e) {
      debugPrint('Error initiating payment: $e');
      
      // Record payment initiation failure
      await recordInteraction(
        'payment_initiation_failed', 
        paymentMethod: 'razorpay',
        succeeded: false,
      );
      
      state = state.copyWith(
        error: 'Error initiating payment: $e',
        isLoading: false,
      );
      
      onPaymentComplete(false, 'Error initiating payment: $e');
    }
  }

  @override
  void dispose() {
    // Dispose of Razorpay instance if needed
    _paymentService.dispose();
    super.dispose();
  }
}
