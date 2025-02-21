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
        'status': 'success',
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

  Future<void> updatePaymentStatus({
    required String paymentId,
    required String status,
  }) async {
    try {
      await _supabase
          .from('payments')
          .update({'status': status})
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
}
