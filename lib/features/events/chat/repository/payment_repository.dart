import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/event_payment.dart';
import '../models/payment_type.dart';

final paymentRepositoryProvider = Provider((ref) => PaymentRepository());

class PaymentRepository {
  final _supabase = Supabase.instance.client;
  
  String? get currentUserId => _supabase.auth.currentUser?.id;
  
  // Get all payments for an event
  Future<List<EventPayment>> getEventPayments(String eventId) async {
    try {
      final response = await _supabase
          .from('event_payments')
          .select()
          .eq('event_id', eventId)
          .order('created_at');
          
      if (response == null || response.isEmpty) {
        return [];
      }
      
      return response.map<EventPayment>((data) => EventPayment.fromMap(data)).toList();
    } catch (e) {
      debugPrint('Error getting event payments: $e');
      return [];
    }
  }
  
  // Get payment for event - legacy support for single payment
  Future<EventPayment?> getEventPayment(String eventId) async {
    try {
      final response = await _supabase
          .from('event_payments')
          .select()
          .eq('event_id', eventId)
          .limit(1)
          .maybeSingle();
          
      if (response == null) {
        return null;
      }
      
      return EventPayment.fromMap(response);
    } catch (e) {
      debugPrint('Error getting event payment: $e');
      return null;
    }
  }
  
  // Check if payment type already exists for this event
  Future<EventPayment?> getEventPaymentByType(String eventId, PaymentType paymentType) async {
    String paymentTypeString = _paymentTypeToString(paymentType);
    
    try {
      final response = await _supabase
          .from('event_payments')
          .select()
          .eq('event_id', eventId)
          .eq('payment_type', paymentTypeString)
          .maybeSingle();
          
      if (response == null) {
        return null;
      }
      
      return EventPayment.fromMap(response);
    } catch (e) {
      debugPrint('Error getting event payment by type: $e');
      return null;
    }
  }
  
  // Convert payment type to database string
  String _paymentTypeToString(PaymentType paymentType) {
    switch (paymentType) {
      case PaymentType.upi:
        return 'upi';
      case PaymentType.razorpay:
        return 'razorpay';
      case PaymentType.stripe:
        return 'stripe';
      default:
        return 'url';
    }
  }
  
  // Create or update payment
  Future<EventPayment?> saveEventPayment({
    required String eventId,
    required String paymentInfo,
    required PaymentType paymentType,
    String? paymentProcessor,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;
      
      // First check if the user is authorized to add a payment (is event creator)
      final isCreator = await isEventCreator(eventId, userId);
      if (!isCreator) {
        debugPrint('User is not authorized to add payment info');
        return null;
      }
      
      // Convert payment type to string for database
      String paymentTypeString = _paymentTypeToString(paymentType);
      
      // Check if this payment type already exists for the event
      final existingPayment = await getEventPaymentByType(eventId, paymentType);
      final now = DateTime.now();
      
      if (existingPayment != null) {
        // Update existing payment
        final result = await _supabase
            .from('event_payments')
            .update({
              'payment_info': paymentInfo,
              'payment_processor': paymentProcessor,
              'updated_at': now.toIso8601String(),
            })
            .eq('id', existingPayment.id)
            .select()
            .single();
            
        return EventPayment.fromMap(result);
      } else {
        // Create new payment
        final uuid = const Uuid().v4();
        
        final result = await _supabase
            .from('event_payments')
            .insert({
              'id': uuid,
              'event_id': eventId,
              'payment_info': paymentInfo,
              'payment_type': paymentTypeString,
              'payment_processor': paymentProcessor,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'added_by': userId,
            })
            .select()
            .single();
            
        return EventPayment.fromMap(result);
      }
    } catch (e) {
      debugPrint('Error saving event payment: $e');
      return null;
    }
  }
  
  // Remove specific payment type
  Future<bool> removeEventPaymentByType(String eventId, PaymentType paymentType) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;
      
      // Check if the user is authorized
      final isCreator = await isEventCreator(eventId, userId);
      if (!isCreator) {
        debugPrint('User is not authorized to remove payment info');
        return false;
      }
      
      String paymentTypeString = _paymentTypeToString(paymentType);
      
      // Delete the payment of specific type
      await _supabase
          .from('event_payments')
          .delete()
          .eq('event_id', eventId)
          .eq('payment_type', paymentTypeString);
          
      return true;
    } catch (e) {
      debugPrint('Error removing event payment: $e');
      return false;
    }
  }

  // Remove all payments for event - legacy support
  Future<bool> removeEventPayment(String eventId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;
      
      // Check if the user is authorized
      final isCreator = await isEventCreator(eventId, userId);
      if (!isCreator) {
        debugPrint('User is not authorized to remove payment info');
        return false;
      }
      
      // Delete all payments for this event
      await _supabase
          .from('event_payments')
          .delete()
          .eq('event_id', eventId);
          
      return true;
    } catch (e) {
      debugPrint('Error removing event payments: $e');
      return false;
    }
  }
  
  // Stream payment updates - for all payment types
  Stream<List<EventPayment>> watchEventPayments(String eventId) {
    return _supabase
        .from('event_payments')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .map((payments) {
          if (payments.isEmpty) return [];
          return payments.map<EventPayment>((data) => EventPayment.fromMap(data)).toList();
        });
  }
  
  // Legacy stream for single payment
  Stream<EventPayment?> watchEventPayment(String eventId) {
    return _supabase
        .from('event_payments')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .map((payments) {
          if (payments.isEmpty) return null;
          return EventPayment.fromMap(payments.first);
        });
  }
  
  Future<bool> isEventCreator(String eventId, String userId) async {
    try {
      final event = await _supabase
          .from('events')
          .select('creator_id')
          .eq('id', eventId)
          .single();
      
      return event['creator_id'] == userId;
    } catch (e) {
      debugPrint('Error checking if user is event creator: $e');
      return false;
    }
  }
}
