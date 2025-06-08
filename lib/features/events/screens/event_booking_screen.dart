import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.brightness == Brightness.dark 
                ? Colors.white 
                : Colors.black87,
          ),
          onPressed: () {
            // Track back button press interaction
            ref.read(ticketBookingControllerProvider.notifier)
                .recordInteraction('back_button_pressed');
                
            // Navigate back to event details screen
            context.go('/events/${widget.eventId}');
          },
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
    final screenSize = MediaQuery.of(context).size;
    final horizontalPadding = screenSize.width * 0.04;

    return Stack(  // Changed from Column to Stack to properly handle Positioned widget
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: 100), // Add padding for payment button
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Event title and image in a column layout for mobile
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image at the top
                      if (event.mediaUrls != null && event.mediaUrls!.isNotEmpty)
                        Container(
                          height: screenSize.width * 0.6, // 60% of screen width
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              event.mediaUrls!.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: theme.colorScheme.surfaceVariant,
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      size: 32,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        
                      // Title and basic info below image
                      Text(
                        event.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                            
                      // Daily Event badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_repeat,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Daily Event',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                            
                      // Use the same date/time section as desktop layout
                      _buildDateTimeSection(theme, event),

                      if (event.location != null) ...[  
                        const SizedBox(height: 12),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Tickets Section with Date Selection
                Container(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Date',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Date selection chips with better scrolling
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 7,
                          itemBuilder: (context, index) {
                            final date = DateTime.now().add(Duration(days: index));
                            final isSelected = bookingState.selectedOccurrenceDate != null &&
                                DateUtils.isSameDay(bookingState.selectedOccurrenceDate, date);
                            
                            return Container(
                              margin: EdgeInsets.only(
                                right: 8,
                                left: index == 0 ? 0 : 0,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    ref.read(ticketBookingControllerProvider.notifier)
                                        .setSelectedOccurrenceDate(date);
                                  },
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.outline.withOpacity(0.3),
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          DateFormat('MMM d').format(date),
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: isSelected
                                                ? theme.colorScheme.onPrimary
                                                : theme.colorScheme.onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Price and quantity section
                Container(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tickets',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Price display with better spacing
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Regular Price',
                                  style: theme.textTheme.bodyLarge,
                                ),
                                Text(
                                  currencyFormat.format(1500),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Vibe Price',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(1300),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Quantity selector
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Number of tickets',
                              style: theme.textTheme.bodyLarge,
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (bookingState.quantity > 1) {
                                      ref.read(ticketBookingControllerProvider.notifier)
                                          .updateQuantity(bookingState.quantity - 1);
                                    }
                                  },
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceVariant,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      size: 20,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${bookingState.quantity}',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    ref.read(ticketBookingControllerProvider.notifier)
                                        .updateQuantity(bookingState.quantity + 1);
                                  },
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      size: 20,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Summary section
                Container(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtotal (1 ticket)',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Text(
                                  currencyFormat.format(1500),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Vibe Discount',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  '- ${currencyFormat.format(200)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(1300),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ),
        
        // Payment Button - Now correctly positioned in Stack
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(16).copyWith(
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
          ),
        ),
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

          // Date & Time - Check for recurring pattern
          _buildDateTimeSection(theme, event),

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
    // Check if this is a recurring event
    bool isRecurringEvent = event.recurringPattern != null && event.recurringPattern!.isNotEmpty;
    List<DateTime> availableDates = [];
    
    if (isRecurringEvent) {
      try {
        final patternData = json.decode(event.recurringPattern!);
        final type = patternData['type'] as String? ?? 'none';
        
        if (type != 'none') {
          // Start from today or event start time, whichever is later
          DateTime currentDate = DateTime.now();
          if (event.startTime.isAfter(currentDate)) {
            currentDate = event.startTime;
          }
          // Remove time component to compare dates only
          currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
          
          final DateTime endDate = patternData['endDate'] != null 
              ? DateTime.parse(patternData['endDate'])
              : currentDate.add(const Duration(days: 90)); // 3 months max if no end date
          
          while (availableDates.length < 30 && currentDate.isBefore(endDate)) {
            switch (type) {
              case 'daily':
                availableDates.add(currentDate);
                currentDate = currentDate.add(const Duration(days: 1));
                break;
              case 'weekly':
                final weekdays = patternData['weekdays'] as List?;
                if (weekdays != null && weekdays.isNotEmpty) {
                  final Map<String, int> weekdayMap = {
                    'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6, 'Sun': 7
                  };
                  final List<int> selectedDays = weekdays
                      .map((day) => weekdayMap[day.toString()] ?? 0)
                      .where((day) => day > 0)
                      .toList();
                  
                  if (selectedDays.contains(currentDate.weekday)) {
                    availableDates.add(currentDate);
                  }
                  currentDate = currentDate.add(const Duration(days: 1));
                }
                break;
              case 'monthly':
                final dayOfMonth = patternData['dayOfMonth'] as int? ?? event.startTime.day;
                if (currentDate.day == dayOfMonth) {
                  availableDates.add(currentDate);
                }
                // Move to next month's same day
                DateTime nextMonth = DateTime(currentDate.year, currentDate.month + 1, 1);
                // Handle cases where the day might not exist in next month
                int daysInNextMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
                int targetDay = dayOfMonth > daysInNextMonth ? daysInNextMonth : dayOfMonth;
                currentDate = DateTime(nextMonth.year, nextMonth.month, targetDay);
                break;
              default:
                currentDate = currentDate.add(const Duration(days: 1));
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing recurring pattern: $e');
      }
    }

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

          // Date selector for recurring events
          if (isRecurringEvent && availableDates.isNotEmpty) ...[
            Text(
              'Select Date',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: availableDates.length,
                itemBuilder: (context, index) {
                  final date = availableDates[index];
                  final isSelected = bookingState.selectedOccurrenceDate?.year == date.year &&
                                   bookingState.selectedOccurrenceDate?.month == date.month &&
                                   bookingState.selectedOccurrenceDate?.day == date.day;
                  
                  return Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        ref.read(ticketBookingControllerProvider.notifier)
                            .setSelectedOccurrenceDate(date);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? theme.colorScheme.primary.withOpacity(0.2)  // Semi-transparent primary color
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected 
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withOpacity(0.3),
                            width: isSelected ? 1.5 : 1.0,  // Slightly thicker border for selected state
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          DateFormat('MMM d').format(date),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected 
                                ? theme.colorScheme.primary  // Use primary color for selected text
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

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

  // Helper method to calculate the first occurrence for recurring patterns
  String _getFirstOccurrenceText(String patternType, Map<String, dynamic> patternData, Event event) {
    DateTime firstOccurrence = event.startTime;
    
    // Handle weekly pattern special case
    if (patternType == 'weekly') {
      // Get selected weekdays
      final List<dynamic> weekdays = patternData['weekdays'] ?? [];
      
      if (weekdays.isNotEmpty) {
        // Convert weekday names to day numbers (1-7 where 1 is Monday)
        final Map<String, int> weekdayMap = {
          'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6, 'Sun': 7
        };
        
        // Get day numbers from weekday strings
        final List<int> selectedDays = weekdays
            .map((day) => weekdayMap[day] ?? 0)
            .where((day) => day > 0)
            .toList();
        
        if (selectedDays.isNotEmpty) {
          // Get current day of week (1-7)
          final int startDayOfWeek = event.startTime.weekday;
          
          // Find the next selected day
          int daysToAdd = 0;
          bool foundDay = false;
          
          // Check if current day is selected
          if (selectedDays.contains(startDayOfWeek)) {
            foundDay = true;
          } else {
            // Find the next closest selected day
            for (int i = 1; i <= 7; i++) {
              final int checkDay = (startDayOfWeek + i) > 7 ? 
                  (startDayOfWeek + i) - 7 : (startDayOfWeek + i);
              
              if (selectedDays.contains(checkDay)) {
                daysToAdd = i;
                foundDay = true;
                break;
              }
            }
          }
          
          // Calculate first occurrence date
          if (foundDay) {
            firstOccurrence = event.startTime.add(Duration(days: daysToAdd));
          }
        }
      }
    }
    
    // Return formatted string with the first occurrence (date only, no time)
    return '${DateFormat('E, MMM d, yyyy').format(firstOccurrence)}';
  }

  // Helper method to build the date and time section with recurring pattern support
  Widget _buildDateTimeSection(ThemeData theme, Event event) {
    // Check if we have a recurring pattern
    if (event.recurringPattern != null && event.recurringPattern!.isNotEmpty) {
      try {
        // Parse the recurring pattern
        final patternData = json.decode(event.recurringPattern!);
        final type = patternData['type'] as String? ?? 'none';
        
        // Only proceed if we have a valid pattern type that's not 'none'
        if (type != 'none') {
          // Choose the appropriate icon and label based on pattern
          IconData patternIcon;
          String patternLabel;
          Color patternColor = theme.colorScheme.primary;
          
          switch (type) {
            case 'daily':
              patternIcon = Icons.calendar_view_day;
              patternLabel = 'Daily';
              patternColor = Colors.blue.shade600;
              break;
            case 'weekly':
              patternIcon = Icons.calendar_view_week;
              patternLabel = 'Weekly';
              patternColor = Colors.green.shade600;
              break;
            case 'monthly':
              patternIcon = Icons.calendar_view_month;
              patternLabel = 'Monthly';
              patternColor = Colors.purple.shade600;
              break;
            default:
              patternIcon = Icons.repeat;
              patternLabel = 'Recurring';
          }
          
          // Build the recurring pattern description
          String patternDesc = '';
          switch (type) {
            case 'daily':
              patternDesc = 'Repeats daily';
              break;
            case 'weekly':
              final weekdays = patternData['weekdays'] as List?;
              if (weekdays != null && weekdays.isNotEmpty) {
                patternDesc = 'Repeats weekly on ${weekdays.join(', ')}';
              } else {
                patternDesc = 'Repeats weekly';
              }
              break;
            case 'monthly':
              final dayOfMonth = patternData['dayOfMonth'] as int? ?? event.startTime.day;
              patternDesc = 'Repeats monthly on day $dayOfMonth';
              break;
            case 'custom':
              patternDesc = 'Custom recurring pattern';
              break;
            default:
              patternDesc = 'Recurring event';
          }
          
          // Add end condition info
          String endInfo = '';
          if (patternData.containsKey('endDate')) {
            final endDate = DateTime.parse(patternData['endDate']);
            endInfo = ' until ${DateFormat('MMM d, y').format(endDate)}';
          } else if (patternData.containsKey('occurrences')) {
            final occurrences = patternData['occurrences'];
            endInfo = ' for $occurrences occurrences';
          }
          
          // Return the recurring pattern display
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pattern type with icon
              Row(
                children: [
                  Icon(
                    patternIcon,
                    size: 16,
                    color: patternColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$patternLabel Event',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: patternColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 6),
              
              // Pattern description
              Text(
                '$patternDesc$endInfo',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 6),
              
              // First occurrence information
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'First occurrence: ${_getFirstOccurrenceText(type, patternData, event)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
      } catch (e) {
        print('Error parsing recurring pattern: $e');
      }
    }
    
    // Fallback to standard date display if no valid recurring pattern
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 16,
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${DateFormat('E, MMM d, yyyy').format(event.startTime)} · '
            '${DateFormat('h:mm a').format(event.startTime)} - '
            '${DateFormat('h:mm a').format(event.endTime)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}
