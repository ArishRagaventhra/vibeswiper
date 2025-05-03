import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/ticket_booking_repository.dart';

// State class for booking history
class BookingHistoryState {
  final bool isLoading;
  final List<Map<String, dynamic>> bookings;
  final String? error;
  final Map<String, dynamic>? selectedBooking;
  final bool isGeneratingTicket;

  BookingHistoryState({
    this.isLoading = false,
    this.bookings = const [],
    this.error,
    this.selectedBooking,
    this.isGeneratingTicket = false,
  });

  BookingHistoryState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? bookings,
    String? error,
    Map<String, dynamic>? selectedBooking,
    bool? isGeneratingTicket,
  }) {
    return BookingHistoryState(
      isLoading: isLoading ?? this.isLoading,
      bookings: bookings ?? this.bookings,
      error: error,
      selectedBooking: selectedBooking,
      isGeneratingTicket: isGeneratingTicket ?? this.isGeneratingTicket,
    );
  }
}

// Provider for booking history controller
final bookingHistoryControllerProvider = StateNotifierProvider<BookingHistoryController, BookingHistoryState>((ref) {
  final repository = ref.watch(ticketBookingRepositoryProvider);
  return BookingHistoryController(repository: repository);
});

class BookingHistoryController extends StateNotifier<BookingHistoryState> {
  final TicketBookingRepository _repository;
  
  BookingHistoryController({
    required TicketBookingRepository repository,
  }) : _repository = repository, 
      super(BookingHistoryState());
  
  // Load booking history for current user
  Future<void> loadBookingHistory() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'User not authenticated',
        );
        return;
      }
      
      final bookings = await _repository.getUserBookingsWithEventDetails(currentUser.id);
      
      state = state.copyWith(
        isLoading: false,
        bookings: bookings,
      );
    } catch (e) {
      debugPrint('Error loading booking history: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load bookings: $e',
      );
    }
  }
  
  // Load details for a single booking
  Future<void> loadBookingDetails(String bookingId) async {
    debugPrint('⚠️ LOADING BOOKING DETAILS FOR ID: $bookingId');
    
    // IMPORTANT: Reset error but preserve other state fields
    state = state.copyWith(
      isLoading: true, 
      error: null,
      // Keep other fields from previous state
      selectedBooking: state.selectedBooking,
      isGeneratingTicket: state.isGeneratingTicket
    );
    
    try {
      final bookingDetails = await _repository.getBookingWithCompleteDetails(bookingId);
      debugPrint('⚠️ REPOSITORY RETURNED BOOKING: ${bookingDetails != null}');
      
      if (bookingDetails == null) {
        debugPrint('❌ BOOKING NOT FOUND: $bookingId');
        state = state.copyWith(
          isLoading: false,
          error: 'Booking not found',
          // Keep the previous booking data if possible
          selectedBooking: state.selectedBooking
        );
        return;
      }
      
      debugPrint('✅ BOOKING LOADED SUCCESSFULLY');
      state = state.copyWith(
        isLoading: false,
        selectedBooking: bookingDetails,
        // Clear any previous errors
        error: null
      );
    } catch (e) {
      debugPrint('❌ ERROR LOADING BOOKING DETAILS: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load booking details: $e',
        // CRITICAL FIX: Preserve any existing booking data
        selectedBooking: state.selectedBooking
      );
    }
  }
  
  // Generate ticket data for download
  Future<Map<String, dynamic>?> generateTicket(String bookingId) async {
    debugPrint('⚠️ GENERATING TICKET FOR ID: $bookingId');
    debugPrint('⚠️ CURRENT STATE Before Ticket Gen: selectedBooking=${state.selectedBooking != null}');
    
    // CRITICAL FIX: Keep the selectedBooking when changing state
    final currentBooking = state.selectedBooking;
    state = state.copyWith(
      isGeneratingTicket: true, 
      error: null, 
      // Keep the currently selected booking to prevent data loss
      selectedBooking: currentBooking
    );
    
    try {
      // First make sure we have a valid booking
      if (currentBooking == null) {
        debugPrint('⚠️ CRITICAL ERROR: No booking selected when generating ticket');
        // Try to load the booking first
        await loadBookingDetails(bookingId);
        
        // Check if loading was successful
        if (state.selectedBooking == null) {
          debugPrint('⚠️ FAILED TO LOAD BOOKING FOR TICKET: $bookingId');
          throw Exception('Booking data not found. Please try again.');
        }
      }
      
      final ticketData = await _repository.generateTicketData(bookingId);
      
      if (ticketData == null) {
        debugPrint('⚠️ TICKET DATA RETURNED NULL FROM REPOSITORY');
        throw Exception('Ticket data is missing');
      }
      
      debugPrint('✅ TICKET GENERATED SUCCESSFULLY: ${ticketData.length} fields');
      
      // CRITICAL FIX: Preserve the selected booking when updating state
      state = state.copyWith(
        isGeneratingTicket: false,
        // Ensure we don't lose our selected booking
        selectedBooking: state.selectedBooking
      );
      return ticketData;
    } catch (e) {
      debugPrint('❌ ERROR GENERATING TICKET: $e');
      // CRITICAL FIX: Keep the booking data even when there's an error
      state = state.copyWith(
        isGeneratingTicket: false,
        error: 'Failed to generate ticket: $e',
        // Preserve the booking data so we don't lose it on error
        selectedBooking: state.selectedBooking
      );
      return null;
    }
  }
  
  // Clear selected booking
  void clearSelectedBooking() {
    state = state.copyWith(selectedBooking: null);
  }
}
