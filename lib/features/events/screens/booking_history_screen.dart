import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
              'No bookings found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Book tickets for an event to see your bookings here',
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
          itemCount: bookings.length,
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) => _buildBookingItem(context, bookings[index], isDarkMode),
        );
      } else {
        // Mobile layout with list
        return ListView.builder(
          itemCount: bookings.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) => _buildBookingItem(context, bookings[index], isDarkMode),
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
    
    // Format dates
    String? eventDateStr;
    if (event['start_date'] != null) {
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
                          Text(
                            eventDateStr,
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
    if (paymentStatus == 'paid' && bookingStatus == 'confirmed') {
      return Colors.green;
    } else if (paymentStatus == 'paid' && bookingStatus == 'cancelled') {
      return Colors.red;
    } else if (paymentStatus == 'failed') {
      return Colors.red;
    } else if (paymentStatus == 'pending') {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  String _getStatusText(String paymentStatus, String bookingStatus) {
    if (paymentStatus == 'paid' && bookingStatus == 'confirmed') {
      return 'Confirmed';
    } else if (paymentStatus == 'paid' && bookingStatus == 'cancelled') {
      return 'Cancelled';
    } else if (paymentStatus == 'failed') {
      return 'Payment Failed';
    } else if (paymentStatus == 'pending') {
      return 'Pending';
    } else {
      return 'Processing';
    }
  }
}
