import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/payment.dart';
import '../providers/payment_provider.dart';

final eventPaymentServiceProvider = Provider((ref) => EventPaymentService(ref));

class EventPaymentService {
  final Ref _ref;

  EventPaymentService(this._ref);

  // Function to navigate after successful payment
  void navigateToEventsListScreen(BuildContext context) {
    // Navigate to events list screen
    context.go('/events');
  }

  Future<void> initiateEventCreationPayment({
    required String eventId,
    required String eventName,
    required String userEmail,
    required String userContact,
    BuildContext? context,
    double? vibePrice, 
  }) async {
    try {
      await _ref.read(paymentProvider.notifier).initiateEventPayment(
            eventId: eventId,
            eventName: eventName,
            userEmail: userEmail,
            userContact: userContact, 
            vibePrice: vibePrice, 
            onPaymentFinalized: (Payment payment) {
              // If payment is successful and we have context, navigate to events list
              if (payment.isSuccessful && context != null) {
                // Short delay to ensure UI updates complete
                Future.delayed(Duration(milliseconds: 500), () {
                  navigateToEventsListScreen(context);
                });
              }
            },
          );
    } catch (e) {
      // Handle any errors during payment initiation
      rethrow;
    }
  }

  // Add this method to your event creation flow
  Future<void> handleEventCreationWithPayment({
    required String eventName,
    required String userEmail,
    required String userContact,
    double? vibePrice, 
    // Add other event creation parameters as needed
  }) async {
    try {
      // 1. Create a draft event first
      final eventId = await _createDraftEvent(/* pass event details */);

      // 2. Initiate payment
      await initiateEventCreationPayment(
        eventId: eventId,
        eventName: eventName,
        userEmail: userEmail,
        userContact: userContact,
        vibePrice: vibePrice, 
      );

      // Note: The event will be published after successful payment
      // This is handled in the PaymentNotifier._handlePaymentSuccess method
    } catch (e) {
      // Handle any errors during the process
      rethrow;
    }
  }

  Future<String> _createDraftEvent(/* Add parameters as needed */) async {
    // Implement draft event creation
    // Return the event ID
    throw UnimplementedError();
  }
}
