import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ticket_booking_model.dart';
import '../providers/event_providers.dart';
import '../repositories/ticket_booking_repository.dart';
import '../../auth/providers/auth_provider.dart';
import 'dart:convert';

// State for ticket verification
class TicketVerificationState {
  final bool isLoading;
  final String? error;
  final TicketBooking? booking;
  final bool isVerified;
  final bool isAlreadyVerified;

  TicketVerificationState({
    this.isLoading = false,
    this.error,
    this.booking,
    this.isVerified = false,
    this.isAlreadyVerified = false,
  });

  TicketVerificationState copyWith({
    bool? isLoading,
    String? error,
    TicketBooking? booking,
    bool? isVerified,
    bool? isAlreadyVerified,
  }) {
    return TicketVerificationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      booking: booking ?? this.booking,
      isVerified: isVerified ?? this.isVerified,
      isAlreadyVerified: isAlreadyVerified ?? this.isAlreadyVerified,
    );
  }
}

// Provider for the ticket verification controller
final ticketVerificationControllerProvider = StateNotifierProvider.autoDispose<TicketVerificationController, TicketVerificationState>((ref) {
  return TicketVerificationController(
    ref.watch(ticketBookingRepositoryProvider),
    ref,
  );
});

// Controller for ticket verification
class TicketVerificationController extends StateNotifier<TicketVerificationState> {
  final TicketBookingRepository _repository;
  final Ref _ref;

  TicketVerificationController(this._repository, this._ref) : super(TicketVerificationState());

  // Verify a ticket by scanning QR code
  Future<void> verifyTicket(String scanData) async {
    try {
      // Set initial loading state
      state = state.copyWith(isLoading: true, error: null, isVerified: false, isAlreadyVerified: false);
      
      // Extract booking reference from QR code
      String bookingReference = _extractBookingReference(scanData);
      
      // 1. Check if booking exists in ticket_bookings table
      final booking = await _repository.getBookingByReference(bookingReference);
      if (booking == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Ticket not found. Please scan a valid ticket QR code.',
        );
        return;
      }
      
      // 2. Check if already checked in
      final bool isCheckedIn = await _repository.isBookingCheckedIn(booking.id);
      if (isCheckedIn) {
        // Already checked in - show appropriate screen
        state = state.copyWith(
          isLoading: false,
          booking: booking,
          isAlreadyVerified: true,
        );
        return;
      }
      
      // Get current user for RLS policy compliance
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'You must be logged in to verify tickets.',
        );
        return;
      }
      
      // 3. Create check-in record with proper user ID for RLS policy
      final checkInSuccess = await _repository.recordCheckIn(
        booking.id, 
        booking.eventId,
        checkedInBy: currentUser.id, // Pass user ID for RLS policy
      );
      
      if (checkInSuccess) {
        // Successfully checked in
        state = state.copyWith(
          isLoading: false,
          booking: booking,
          isVerified: true,
        );
      } else {
        // Failed to check in - could be RLS authorization failure
        state = state.copyWith(
          isLoading: false,
          error: 'Not authorized to check in this ticket. Only event organizers can perform check-ins.',
        );
      }
    } catch (e) {
      print('Scan error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error scanning ticket. Please try again.',
      );
    }
  }
  
  // Helper method to extract booking reference from QR code data
  String _extractBookingReference(String scanData) {
    String bookingReference = scanData.trim();
    
    // Check if it's in JSON format
    if (bookingReference.startsWith('{') && bookingReference.endsWith('}')) {
      try {
        final Map<String, dynamic> jsonData = Map<String, dynamic>.from(
          jsonDecode(bookingReference) as Map,
        );
        if (jsonData.containsKey('booking_reference')) {
          bookingReference = jsonData['booking_reference'] as String;
        } else if (jsonData.containsKey('reference')) {
          bookingReference = jsonData['reference'] as String;
        }
      } catch (e) {
        print('Error parsing QR JSON: $e, using raw string');
      }
    }
    
    return bookingReference;
  }
  
  // Reset verification state
  void reset() {
    state = TicketVerificationState();
  }
}
