import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_type.dart';
import '../repository/payment_repository.dart';
import '../models/event_payment.dart';


// Provider to get all payment methods for an event
final eventPaymentsProvider = FutureProvider.family<List<EventPayment>, String>((ref, eventId) async {
  return ref.watch(paymentRepositoryProvider).getEventPayments(eventId);
});

// Provider to get a specific payment type for an event
final eventPaymentByTypeProvider = FutureProvider.family<EventPayment?, ({String eventId, PaymentType paymentType})>((ref, params) async {
  return ref.watch(paymentRepositoryProvider).getEventPaymentByType(params.eventId, params.paymentType);
});

// Legacy provider for a single payment
final eventPaymentProvider = FutureProvider.family<EventPayment?, String>((ref, eventId) async {
  return ref.watch(paymentRepositoryProvider).getEventPayment(eventId);
});

// Stream provider for real-time payment updates - all payment types
final eventPaymentsStreamProvider = StreamProvider.family<List<EventPayment>, String>((ref, eventId) {
  return ref.watch(paymentRepositoryProvider).watchEventPayments(eventId);
});

// Stream provider for real-time payment updates - single payment (legacy)
final eventPaymentStreamProvider = StreamProvider.family<EventPayment?, String>((ref, eventId) {
  return ref.watch(paymentRepositoryProvider).watchEventPayment(eventId);
});

// Controller for payment operations
final paymentControllerProvider = StateNotifierProvider<PaymentController, AsyncValue<void>>((ref) {
  return PaymentController(ref.watch(paymentRepositoryProvider));
});

class PaymentController extends StateNotifier<AsyncValue<void>> {
  final PaymentRepository _repository;

  PaymentController(this._repository) : super(const AsyncValue.data(null));

  Future<List<EventPayment>> getEventPayments(String eventId) async {
    try {
      state = const AsyncValue.loading();
      final payments = await _repository.getEventPayments(eventId);
      state = const AsyncValue.data(null);
      return payments;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return [];
    }
  }

  Future<EventPayment?> getEventPaymentByType(String eventId, PaymentType paymentType) async {
    try {
      state = const AsyncValue.loading();
      final payment = await _repository.getEventPaymentByType(eventId, paymentType);
      state = const AsyncValue.data(null);
      return payment;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  // Legacy method
  Future<EventPayment?> getEventPayment(String eventId) async {
    try {
      state = const AsyncValue.loading();
      final payment = await _repository.getEventPayment(eventId);
      state = const AsyncValue.data(null);
      return payment;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  Future<EventPayment?> saveEventPayment({
    required String eventId, 
    required String paymentInfo, 
    required PaymentType paymentType,
    String? paymentProcessor,
  }) async {
    try {
      state = const AsyncValue.loading();
      
      final payment = await _repository.saveEventPayment(
        eventId: eventId, 
        paymentInfo: paymentInfo, 
        paymentType: paymentType,
        paymentProcessor: paymentProcessor,
      );
      
      state = const AsyncValue.data(null);
      return payment;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
  
  // Remove a specific payment type
  Future<bool> removeEventPaymentByType(String eventId, PaymentType paymentType) async {
    try {
      state = const AsyncValue.loading();
      final result = await _repository.removeEventPaymentByType(eventId, paymentType);
      state = const AsyncValue.data(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
  
  // Legacy method to remove all payments
  Future<bool> removeEventPayment(String eventId) async {
    try {
      state = const AsyncValue.loading();
      final result = await _repository.removeEventPayment(eventId);
      state = const AsyncValue.data(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
  
  // Detect payment processor from URL
  PaymentType detectPaymentType(String url) {
    final urlLower = url.toLowerCase();
    
    if (urlLower.contains('razorpay.com') || urlLower.contains('rzp.io')) {
      return PaymentType.razorpay;
    } else if (urlLower.contains('stripe.com') || urlLower.contains('checkout.stripe.com')) {
      return PaymentType.stripe;
    } else if (url.contains('@') && !url.startsWith('http')) {
      return PaymentType.upi;
    }
    
    return PaymentType.url;
  }

  Future<bool> isEventCreator(String eventId) async {
    try {
      final currentUserId = _repository.currentUserId;
      if (currentUserId == null) return false;
      
      return await _repository.isEventCreator(eventId, currentUserId);
    } catch (e) {
      debugPrint('Error checking if user is event creator: $e');
      return false;
    }
  }
}
