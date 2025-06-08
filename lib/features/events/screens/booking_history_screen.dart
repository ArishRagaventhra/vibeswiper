import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../controllers/booking_history_controller.dart';
import '../../../config/routes.dart';  

class BookingHistoryScreen extends ConsumerStatefulWidget {
  const BookingHistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends ConsumerState<BookingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(bookingHistoryControllerProvider.notifier).loadBookingHistory());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingHistoryControllerProvider);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Bookings'),
        elevation: 0,
        backgroundColor: isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : theme.iconTheme.color,
        ),
        foregroundColor: isDarkMode ? Colors.white : theme.appBarTheme.foregroundColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => context.go(AppRoutes.account),
        ),
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, BookingHistoryState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null) {
      return _buildErrorState(context, state.error!);
    }

    if (state.bookings.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildBookingsList(context, state.bookings);
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(bookingHistoryControllerProvider.notifier).loadBookingHistory();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 70,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No confirmed bookings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Book tickets for an event to see your confirmed bookings here',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList(BuildContext context, List<dynamic> bookings) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 600;
    
    // Filter to show only confirmed bookings
    final confirmedBookings = bookings.where((booking) => 
      booking['payment_status'] == 'paid' && 
      booking['booking_status'] == 'confirmed'
    ).toList();
    
    // Show empty state if no confirmed bookings
    if (confirmedBookings.isEmpty) {
      return _buildEmptyState(context);
    }
    
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = _calculateColumnCount(constraints.maxWidth);
      
      if (isDesktop) {
        // Desktop layout with grid for larger screens
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: confirmedBookings.length,
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) => _buildBookingItem(context, confirmedBookings[index], isDarkMode),
        );
      } else {
        // Mobile layout with list
        return ListView.builder(
          itemCount: confirmedBookings.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) => _buildBookingItem(context, confirmedBookings[index], isDarkMode),
        );
      }
    });
  }
  
  int _calculateColumnCount(double width) {
    if (width > 1200) return 3;
    if (width > 800) return 2;
    return 1;
  }
  
  Widget _buildBookingItem(BuildContext context, Map<String, dynamic> booking, bool isDarkMode) {
    final event = booking['events'] as Map<String, dynamic>;
    final bookingStatus = booking['booking_status'] as String;
    final paymentStatus = booking['payment_status'] as String;
    final theme = Theme.of(context);
    
    // Check for recurring pattern first
    String? eventDateStr;
    bool hasRecurringPattern = false;
    Map<String, dynamic> patternInfo = {};
    
    // First check for booked occurrence date
    if (booking['booked_occurrence_date'] != null) {
      final bookedDate = DateTime.parse(booking['booked_occurrence_date']);
      eventDateStr = DateFormat('E, MMM d, yyyy').format(bookedDate);
      
      // Still get pattern info for the icon if it's a recurring event
      if (event['recurring_pattern'] != null && event['recurring_pattern'].toString().isNotEmpty) {
        hasRecurringPattern = true;
        patternInfo = _getRecurringPatternInfo(event['recurring_pattern']);
      }
    }
    // Then check for recurring pattern if no booked date
    else if (event['recurring_pattern'] != null && event['recurring_pattern'].toString().isNotEmpty) {
      try {
        final patternData = json.decode(event['recurring_pattern']);
        final type = patternData['type'] as String? ?? 'none';
        
        if (type != 'none') {
          hasRecurringPattern = true;
          patternInfo = _getRecurringPatternInfo(event['recurring_pattern']);
          
          // Format date string differently for recurring events - show only date without time
          if (event['start_date'] != null) {
            var eventDate = DateTime.parse(event['start_date']);
            eventDateStr = '${patternInfo['label']} • ${DateFormat('E, MMM d, yyyy').format(eventDate)}';
          } else {
            eventDateStr = patternInfo['label'];
          }
        }
      } catch (e) {
        // If parsing fails, use standard formatting
        hasRecurringPattern = false;
      }
    }
    
    // Use standard date formatting if no recurring pattern
    if (!hasRecurringPattern && event['start_date'] != null) {
      final eventDate = DateTime.parse(event['start_date']);
      final now = DateTime.now();
      final isToday = eventDate.year == now.year && 
                    eventDate.month == now.month &&
                    eventDate.day == now.day;
      
      final datePart = isToday ? 'Today' : DateFormat('dd MMM').format(eventDate);
      eventDateStr = '$datePart | ${DateFormat('hh:mm a').format(eventDate)}';
    }
    
    final ticketCount = booking['quantity'] ?? 1;
    final statusText = _getStatusText(paymentStatus, bookingStatus);
    final statusColor = _getStatusColor(paymentStatus, bookingStatus);
    
    // Create image URL
    final imageUrl = event['media_urls'] != null && (event['media_urls'] as List).isNotEmpty 
        ? event['media_urls'][0] 
        : 'https://via.placeholder.com/120x180?text=Event';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1, // Slightly increased elevation for better shadow
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDarkMode 
              ? theme.colorScheme.primary.withOpacity(0.3) 
              : theme.colorScheme.primary.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(AppRoutes.bookingDetails.replaceFirst(':id', booking['id'])),
          child: SizedBox(
            height: 150, // Increased height to accommodate content better
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max, // Changed from min to max to fill available space
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Added to distribute space
                      children: [
                        Text(
                          event['title'] ?? 'Unknown Event',
                          style: TextStyle(
                            fontSize: 15, // Slightly smaller font
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (eventDateStr != null) ...[  
                          const SizedBox(height: 2), // Reduced spacing
                          hasRecurringPattern
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: patternInfo['color'].withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: patternInfo['color'].withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    patternInfo['icon'],
                                    size: 12,
                                    color: patternInfo['color'],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    eventDateStr ?? patternInfo['label'],
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: patternInfo['color'],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              eventDateStr ?? 'Date not specified',
                              style: TextStyle(
                                fontSize: 12, // Smaller font
                                color: isDarkMode ? Colors.grey : Colors.black54,
                              ),
                            ),
                        ],
                        const SizedBox(height: 2), // Reduced spacing
                        Text(
                          '$ticketCount ${ticketCount > 1 ? 'tickets' : 'ticket'}',
                          style: TextStyle(
                            fontSize: 12, // Smaller font
                            color: isDarkMode ? Colors.grey : Colors.black54,
                          ),
                        ),
                        
                        if (event['location'] != null) ...[  
                          const SizedBox(height: 4), // Reduced spacing
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event['location'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode ? Colors.white70 : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.location_on_outlined,
                                size: 16, // Reduced size
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 4), // Reduced spacing
                        // Status chip and View details button
                        Row(
                          children: [
                            // Status pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Reduced padding
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(12), // Smaller radius
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11, // Smaller font
                                  fontWeight: FontWeight.w500,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // View details text with arrow
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View details',
                                  style: TextStyle(
                                    fontSize: 12, // Smaller font
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 10, // Smaller icon
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Space before image
                const SizedBox(width: 12),
                
                // Event poster/thumbnail with rounded corners on all sides
                Padding(
                  padding: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 60,
                      height: 100,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          child: Center(
                            child: Icon(
                              Icons.event,
                              size: 30,
                              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                            ),
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
      ),
    );
  }

  Color _getStatusColor(String paymentStatus, String bookingStatus) {
    // Since we're only showing confirmed bookings, we can simplify this
    return Colors.green;  // All shown bookings will be confirmed
  }

  String _getStatusText(String paymentStatus, String bookingStatus) {
    // Since we're only showing confirmed bookings, we can simplify this
    return 'Confirmed';  // All shown bookings will be confirmed
  }
  
  // Helper method to get recurring pattern display info
  Map<String, dynamic> _getRecurringPatternInfo(String patternJson) {
    try {
      final Map<String, dynamic> result = {
        'hasPattern': false,
        'icon': Icons.calendar_today,
        'label': '',
        'color': Colors.grey,
      };
      
      final patternData = json.decode(patternJson);
      final type = patternData['type'] as String? ?? 'none';
      
      if (type == 'none') return result;
      
      result['hasPattern'] = true;
      
      switch (type) {
        case 'daily':
          result['icon'] = Icons.calendar_view_day;
          result['label'] = 'Daily';
          result['color'] = Colors.blue;
          break;
        case 'weekly':
          result['icon'] = Icons.calendar_view_week;
          result['label'] = 'Weekly';
          result['color'] = Colors.green;
          break;
        case 'monthly':
          result['icon'] = Icons.calendar_view_month;
          result['label'] = 'Monthly';
          result['color'] = Colors.purple;
          break;
        default:
          result['icon'] = Icons.repeat;
          result['label'] = 'Recurring';
          result['color'] = Colors.orange;
      }
      
      return result;
    } catch (e) {
      return {
        'hasPattern': false,
        'icon': Icons.calendar_today,
        'label': '',
        'color': Colors.grey,
      };
    }
  }
}
