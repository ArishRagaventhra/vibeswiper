import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ticket_booking_model.dart';
import '../models/event_model.dart';

final ticketBookingRepositoryProvider = Provider((ref) => TicketBookingRepository(
  supabase: Supabase.instance.client,
));

class TicketBookingRepository {
  final SupabaseClient _supabase;

  TicketBookingRepository({required SupabaseClient supabase}) : _supabase = supabase;

  // Create a new ticket booking
  Future<TicketBooking> createBooking({
    required String userId,
    required String eventId,
    required int quantity,
    required double unitPrice,
    required double totalAmount,
    required bool isVibePrice,
  }) async {
    // Generate a unique booking reference (e.g. 'VB-12345678')
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    final bookingReference = 'VB-$timestamp';

    final response = await _supabase.from('ticket_bookings').insert({
      'booking_reference': bookingReference,
      'user_id': userId,
      'event_id': eventId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'is_vibe_price': isVibePrice,
      'booking_status': BookingStatus.pending.toString().split('.').last,
      'payment_status': PaymentStatus.unpaid.toString().split('.').last,
    }).select().single();

    return TicketBooking.fromMap(response);
  }

  // Update booking status
  Future<void> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    await _supabase.from('ticket_bookings').update({
      'booking_status': status.toString().split('.').last,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  // Update payment status
  Future<void> updatePaymentStatus({
    required String bookingId,
    required PaymentStatus status,
  }) async {
    await _supabase.from('ticket_bookings').update({
      'payment_status': status.toString().split('.').last,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  // Create payment transaction
  Future<void> createPaymentTransaction({
    required String bookingId,
    required String userId,
    required String paymentMethod,
    required String? paymentProvider,
    required double amount,
    required String status,
    String? paymentReference,
    Map<String, dynamic>? metadata,
  }) async {
    await _supabase.from('payment_transactions').insert({
      'booking_id': bookingId,
      'user_id': userId,
      'payment_reference': paymentReference,
      'payment_method': paymentMethod,
      'payment_provider': paymentProvider,
      'amount': amount,
      'currency': 'INR',
      'status': status,
      'metadata': metadata ?? {},
    });
  }

  // Record payment interaction metrics
  Future<void> recordPaymentInteraction({
    required String userId,
    required String eventId,
    required String interactionType,
    String? bookingId,
    String? paymentMethod,
    bool? succeeded,
    Map<String, dynamic>? deviceInfo,
  }) async {
    await _supabase.from('payment_interaction_metrics').insert({
      'user_id': userId,
      'event_id': eventId,
      'booking_id': bookingId,
      'interaction_type': interactionType,
      'payment_method': paymentMethod,
      'succeeded': succeeded,
      'device_info': deviceInfo ?? {},
    });
  }

  // Get booking by id
  Future<TicketBooking?> getBookingById(String id) async {
    final response = await _supabase
        .from('ticket_bookings')
        .select()
        .eq('id', id)
        .maybeSingle();
        
    if (response == null) return null;
    return TicketBooking.fromMap(response);
  }

  // Get user's bookings for an event
  Future<List<TicketBooking>> getUserBookingsForEvent({
    required String userId,
    required String eventId,
  }) async {
    final response = await _supabase
        .from('ticket_bookings')
        .select()
        .eq('user_id', userId)
        .eq('event_id', eventId)
        .order('created_at', ascending: false);

    return response.map((item) => TicketBooking.fromMap(item)).toList();
  }

  // Get all user's bookings
  Future<List<TicketBooking>> getUserBookings(String userId) async {
    final response = await _supabase
        .from('ticket_bookings')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response.map((item) => TicketBooking.fromMap(item)).toList();
  }

  // Get all user's bookings with event details (for bookings history)
  Future<List<Map<String, dynamic>>> getUserBookingsWithEventDetails(String userId) async {
    final response = await _supabase
        .from('ticket_bookings')
        .select('''
          *,
          events!fk_event(*),
          payment:payment_transactions!fk_booking(*)
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response;
  }

  // Get a single booking with complete details (for ticket view)
  Future<Map<String, dynamic>?> getBookingWithCompleteDetails(String bookingId) async {
    final response = await _supabase
        .from('ticket_bookings')
        .select('''
          *,
          events!fk_event(*),
          payment:payment_transactions!fk_booking(*),
          metrics:payment_interaction_metrics!payment_interaction_metrics_booking_id_fkey(*)
        ''')
        .eq('id', bookingId)
        .maybeSingle();
        
    return response;
  }

  // Generate ticket data (for downloading)
  Future<Map<String, dynamic>> generateTicketData(String bookingId) async {
    // Get booking with event details
    final bookingData = await getBookingWithCompleteDetails(bookingId);
    if (bookingData == null) {
      throw Exception('Booking not found');
    }
    
    // Get user profile
    final userId = bookingData['user_id'];
    final userResponse = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
        
    if (userResponse == null) {
      throw Exception('User profile not found');
    }
    
    // Create ticket data structure
    final ticketData = {
      'booking': bookingData,
      'event': bookingData['events'],
      'user': userResponse,
      'generated_at': DateTime.now().toIso8601String(),
      'ticket_number': bookingData['booking_reference'],
      'is_valid': bookingData['booking_status'] == 'confirmed' && 
                 bookingData['payment_status'] == 'paid',
    };
    
    return ticketData;
  }

  // Get booking by reference (for QR code scanning)
  Future<TicketBooking?> getBookingByReference(String bookingReference) async {
    try {
      final response = await _supabase
          .from('ticket_bookings')
          .select()
          .eq('booking_reference', bookingReference)
          .maybeSingle();
          
      if (response == null) return null;
      return TicketBooking.fromMap(response);
    } catch (e) {
      print('Error getting booking by reference: $e');
      return null;
    }
  }
  
  // Check if a booking has been checked in
  Future<bool> isBookingCheckedIn(String bookingId) async {
    try {
      final checkIn = await _supabase
          .from('ticket_check_ins')
          .select()
          .eq('booking_id', bookingId)
          .not('checked_in_at', 'is', null)  // Ensure checked_in timestamp exists
          .maybeSingle();
      
      return checkIn != null;
    } catch (e) {
      print('Error checking if booking is checked in: $e');
      return false;
    }
  }
  
  // Record check-in for a booking
  Future<bool> recordCheckIn(String bookingId, String eventId) async {
    try {
      // Check if already checked in
      final isAlreadyCheckedIn = await isBookingCheckedIn(bookingId);
      if (isAlreadyCheckedIn) {
        return false; // Already checked in
      }
      
      // Create check-in record
      await _supabase.from('ticket_check_ins').insert({
        'booking_id': bookingId,
        'event_id': eventId,
        'checked_in_at': DateTime.now().toIso8601String(),
        'check_in_method': 'qr_scan',
      });
      
      return true; // Successfully checked in
    } catch (e) {
      print('Error recording check-in: $e');
      return false;
    }
  }
}
