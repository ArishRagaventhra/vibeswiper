import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';

class PaymentRepository {
  final SupabaseClient _supabase;

  PaymentRepository(this._supabase);

  Future<Payment> createPayment({
    required String userId,
    required String eventId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required double amount,
    String status = 'pending',
  }) async {
    try {
      // First verify if the user has permission
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != userId) {
        throw Exception('Unauthorized: User not authenticated or ID mismatch');
      }

      final paymentData = {
        'user_id': userId,
        'event_id': eventId,
        'amount': amount,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_order_id': razorpayOrderId,
        'status': status, // Use the provided status parameter
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('payments')
          .insert(paymentData)
          .select()
          .single();

      return Payment.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '42501') { // RLS policy violation
        throw Exception('Permission denied: Unable to create payment. Please ensure you are logged in.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to create payment: $e');
    }
  }

  Future<List<Payment>> getUserPayments(String userId) async {
    try {
      // First verify if the user has permission
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != userId) {
        throw Exception('Unauthorized: User not authenticated or ID mismatch');
      }

      final response = await _supabase
          .from('payments')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((json) => Payment.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      if (e.code == '42501') { // RLS policy violation
        throw Exception('Permission denied: Unable to fetch payments. Please ensure you are logged in.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to fetch payments: $e');
    }
  }
  
  // Get payments for a user with a specific status
  Future<List<Payment>> getUserPaymentsWithStatus(String userId, String status) async {
    try {
      // First verify if the user has permission
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != userId) {
        throw Exception('Unauthorized: User not authenticated or ID mismatch');
      }

      final response = await _supabase
          .from('payments')
          .select()
          .eq('user_id', userId)
          .eq('status', status)
          .order('created_at', ascending: false);

      return response.map((json) => Payment.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      if (e.code == '42501') { // RLS policy violation
        throw Exception('Permission denied: Unable to fetch payments. Please ensure you are logged in.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to fetch payments with status: $e');
    }
  }

  Future<Payment?> getPaymentByEventId(String eventId) async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .eq('event_id', eventId)
          .maybeSingle();

      return response == null ? null : Payment.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '42501') { // RLS policy violation
        throw Exception('Permission denied: Unable to fetch payment. Please ensure you are logged in.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to fetch payment: $e');
    }
  }
  
  // New method to check payment status by Razorpay payment ID
  Future<Payment?> getPaymentByRazorpayId(String razorpayPaymentId) async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .eq('razorpay_payment_id', razorpayPaymentId)
          .maybeSingle();

      return response == null ? null : Payment.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '42501') { // RLS policy violation
        throw Exception('Permission denied: Unable to fetch payment. Please ensure you are logged in.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to fetch payment: $e');
    }
  }

  // Get all payments for a specific event ID, ordered by newest first
  Future<List<Payment>> getPaymentsByEventId(String eventId) async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      return response.map((json) => Payment.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      if (e.code == '42501') { // RLS policy violation
        throw Exception('Permission denied: Unable to fetch payments. Please ensure you are logged in.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to fetch payments for event: $e');
    }
  }

  Future<void> updatePaymentStatus({
    required String paymentId,
    required String status,
  }) async {
    try {
      await _supabase
          .from('payments')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', paymentId);
    } on PostgrestException catch (e) {
      if (e.code == '42501') { // RLS policy violation
        throw Exception('Permission denied: Unable to update payment status. Please ensure you are logged in.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to update payment status: $e');
    }
  }

  // Update an existing payment record
  Future<Payment> updatePayment({
    required String id,
    required String userId,
    required String eventId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required double amount,
    required String status,
    Map<String, dynamic>? paymentDetails,
    String? errorMessage,
  }) async {
    try {
      // First verify if the user has permission
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != userId) {
        throw Exception('Unauthorized: User not authenticated or ID mismatch');
      }

      final paymentData = {
        'user_id': userId,
        'event_id': eventId,
        'amount': amount,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_order_id': razorpayOrderId,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Add optional fields if provided
      if (paymentDetails != null) {
        paymentData['payment_details'] = paymentDetails;
      }
      
      if (errorMessage != null) {
        paymentData['error_message'] = errorMessage;
      }

      final response = await _supabase
          .from('payments')
          .update(paymentData)
          .eq('id', id)
          .select()
          .single();

      return Payment.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '42501') { // RLS policy violation
        throw Exception('Permission denied: Unable to update payment. Please ensure you are logged in.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to update payment: $e');
    }
  }

  // Get the latest payment for a specific user
  Future<Payment?> getLatestPaymentForUser(String userId) async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response == null ? null : Payment.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '42501') { // RLS policy violation
        throw Exception('Permission denied: Unable to fetch payment. Please ensure you are logged in.');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to fetch latest payment: $e');
    }
  }
}
