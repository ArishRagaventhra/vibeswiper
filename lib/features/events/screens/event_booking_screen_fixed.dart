import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/theme.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../controllers/ticket_booking_controller.dart';
import '../controllers/event_participant_controller.dart';
import '../models/event_model.dart';
import '../providers/event_providers.dart';
import '../widgets/booking_quantity_selector.dart';
import '../widgets/booking_summary_card.dart';

class EventBookingScreen extends ConsumerStatefulWidget {
  final String eventId;
  final Event event;

  const EventBookingScreen({
    Key? key,
    required this.eventId,
    required this.event,
  }) : super(key: key);

  @override
  ConsumerState<EventBookingScreen> createState() => _EventBookingScreenState();
}

class _EventBookingScreenState extends ConsumerState<EventBookingScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the booking controller with the event
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ticketBookingControllerProvider.notifier).setEvent(widget.event);
    });
  }

  void _handlePayNow() async {
    final controller = ref.read(ticketBookingControllerProvider.notifier);
    
    // Track payment button interaction
    await controller.recordInteraction('payment_button_clicked');
    
    // First create the booking
    await controller.createBooking();
    
    // Check if booking was successful
    final state = ref.read(ticketBookingControllerProvider);
    if (state.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Get current user for payment details
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to make a payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Initialize Razorpay payment directly
    if (mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Track payment gateway redirected
      await controller.recordInteraction('payment_gateway_redirected', paymentMethod: 'razorpay');

      // Process Razorpay payment
      await controller.processRazorpayPayment(
        userEmail: currentUser.email ?? '',
        userContact: currentUser.phone ?? '',
        onPaymentComplete: (success, message) {
          // Dismiss loading indicator
          Navigator.of(context).pop();

          if (success) {
            _handleSuccessfulPayment();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message ?? 'Payment failed'),
                backgroundColor: Colors.red,
              ),
            );
            
            // Track payment failure
            controller.recordInteraction('payment_failed', paymentMethod: 'razorpay');
          }
        },
      );
    }
  }

  void _handleSuccessfulPayment() async {
    final state = ref.read(ticketBookingControllerProvider);
    final controller = ref.read(ticketBookingControllerProvider.notifier);
    
    if (state.confirmedBooking == null || state.event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking information is missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) return;

      // Join user to event automatically after successful payment
      await ref.read(eventParticipantControllerProvider.notifier).joinEvent(
        state.event!.id,
        currentUser.id,
      );

      // Record the join event as a payment interaction
      await controller.recordInteraction(
        'event_joined_after_payment',
        paymentMethod: 'razorpay',
      );

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Payment Successful'),
            content: const Text(
              'Your booking has been confirmed. You can view your tickets in the My Bookings section.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/events/${state.event!.id}/booking/${state.confirmedBooking!.id}');
                },
                child: const Text('View Booking'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = widget.event;
    final bookingState = ref.watch(ticketBookingControllerProvider);
    final currencyFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    );
    
    // Determine if we're on a larger screen
    final isLargerScreen = !ResponsiveLayout.isMobile(context);
    final horizontalPadding = ResponsiveLayout.getHorizontalPadding(context);
    final contentMaxWidth = ResponsiveLayout.getContentMaxWidth(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Book Tickets',
          style: TextStyle(
            fontSize: isLargerScreen ? 22 : 18,
            fontWeight: FontWeight.w600,
            color: theme.brightness == Brightness.dark 
                ? Colors.white 
                : Colors.black87,
          ),
        ),
        centerTitle: !isLargerScreen,
        titleSpacing: isLargerScreen ? 8 : NavigationToolbar.kMiddleSpacing,
        leading: BackButton(
          color: theme.brightness == Brightness.dark 
              ? Colors.white 
              : Colors.black87,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: bookingState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: isLargerScreen 
                ? _buildLargeScreenLayout(context, theme, event, bookingState, currencyFormat, contentMaxWidth, horizontalPadding)
                : _buildMobileLayout(context, theme, event, bookingState, currencyFormat),
            ),
    );
  }

  // Layout for mobile screens
  Widget _buildMobileLayout(BuildContext context, ThemeData theme, Event event, 
      dynamic bookingState, NumberFormat currencyFormat) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Event Image
                if (event.mediaUrls != null && event.mediaUrls!.isNotEmpty)
                  Container(
                    height: 200,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      image: DecorationImage(
                        image: NetworkImage(event.mediaUrls!.first),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  ),

                // Event details and booking widgets
                _buildEventDetailsCard(theme, event),
                _buildTicketSelectionCard(theme, event, bookingState, currencyFormat),
                
                // Booking Summary Card
                BookingSummaryCard(
                  quantity: bookingState.quantity,
                  regularTotal: bookingState.regularTotal,
                  vibeDiscount: bookingState.discount,
                  totalAmount: bookingState.totalAmount,
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        
        // Payment Button
        _buildPaymentButton(theme, bookingState, currencyFormat),
      ],
    );
  }

  // Layout for larger screens (tablet, desktop, laptop)
  Widget _buildLargeScreenLayout(BuildContext context, ThemeData theme, Event event, 
      dynamic bookingState, NumberFormat currencyFormat, double contentMaxWidth, EdgeInsets horizontalPadding) {
    return Center(
      child: SizedBox(
        width: contentMaxWidth,
        child: Padding(
          padding: horizontalPadding,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column - Event image and details
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Event Image
                            if (event.mediaUrls != null && event.mediaUrls!.isNotEmpty)
                              Container(
                                height: 320,
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  image: DecorationImage(
                                    image: NetworkImage(event.mediaUrls!.first),
                                    fit: BoxFit.cover,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                              ),
                            
                            // Event Details
                            _buildEventDetailsCard(theme, event),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // Right column - Ticket selection and summary
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTicketSelectionCard(theme, event, bookingState, currencyFormat),
                            
                            // Booking Summary
                            BookingSummaryCard(
                              quantity: bookingState.quantity,
                              regularTotal: bookingState.regularTotal,
                              vibeDiscount: bookingState.discount,
                              totalAmount: bookingState.totalAmount,
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Payment button appears in the right column for desktop
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _handlePayNow,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: AppTheme.primaryGradient,
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Pay ${currencyFormat.format(bookingState.totalAmount)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Event details card - extracted to avoid duplication
  Widget _buildEventDetailsCard(ThemeData theme, Event event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event title
          Text(
            event.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Date & Time
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('E, MMM d, yyyy').format(event.startTime)} · '
                '${DateFormat('h:mm a').format(event.startTime)} - '
                '${DateFormat('h:mm a').format(event.endTime)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Location
          if (event.location != null)
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.location!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Ticket selection card - extracted to avoid duplication
  Widget _buildTicketSelectionCard(ThemeData theme, Event event, dynamic bookingState, NumberFormat currencyFormat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tickets',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Price display
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Regular Price: ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        event.ticketPrice != null
                            ? currencyFormat.format(event.ticketPrice)
                            : 'Free',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: bookingState.isVibePrice
                              ? TextDecoration.lineThrough
                              : null,
                          color: bookingState.isVibePrice
                              ? theme.colorScheme.onSurface.withOpacity(0.5)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  
                  if (event.vibePrice != null)
                    Row(
                      children: [
                        Text(
                          'Vibe Price: ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          currencyFormat.format(event.vibePrice),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: bookingState.isVibePrice
                                ? FontWeight.bold
                                : null,
                            color: bookingState.isVibePrice
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              
              const Spacer(),
              
              // Use vibe price toggle
              if (event.vibePrice != null)
                Switch(
                  value: bookingState.isVibePrice,
                  onChanged: (value) {
                    ref.read(ticketBookingControllerProvider.notifier)
                        .togglePriceType();
                  },
                  activeColor: theme.colorScheme.primary,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Quantity selector
          BookingQuantitySelector(
            quantity: bookingState.quantity,
            onChanged: (quantity) {
              ref.read(ticketBookingControllerProvider.notifier)
                  .updateQuantity(quantity);
            },
          ),
        ],
      ),
    );
  }

  // Payment button - only used in mobile layout
  Widget _buildPaymentButton(ThemeData theme, dynamic bookingState, NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _handlePayNow,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppTheme.primaryGradient,
            ),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                'Pay ${currencyFormat.format(bookingState.totalAmount)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
