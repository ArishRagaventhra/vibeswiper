import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_saver/file_saver.dart';
import '../controllers/booking_history_controller.dart';
import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../utils/recurring_event_utils.dart';
import '../models/event_model.dart';

class BookingDetailsScreen extends ConsumerStatefulWidget {
  final String bookingId;
  
  const BookingDetailsScreen({
    Key? key,
    required this.bookingId,
  }) : super(key: key);

  @override
  ConsumerState<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  bool _isImageLiked = false;
  int _currentImageIndex = 0;

  // Track QR code interactions for analytics
  int _qrCodeInteractions = 0;
  bool _hasTrackedPaymentLinkClick = false;
  
  // Key for the ticket widget to prevent rendering issues
  // We've moved this to a field to ensure it's stable across rebuilds

  
  @override
  void initState() {
    super.initState();
    // Load booking details only once at initialization
    Future.microtask(() => 
        ref.read(bookingHistoryControllerProvider.notifier).loadBookingDetails(
            widget.bookingId)
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingHistoryControllerProvider);
    final booking = state.selectedBooking;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 1024;
    final isTablet = screenSize.width > 768 && screenSize.width <= 1024;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Booking Details',
          style: theme.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? Colors.black : theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => context.go(AppRoutes.bookingHistory),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.share,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              if (booking != null) {
                Share.share(
                    'Check out my booking: ${booking['booking_reference']}');
              }
            },
          ),
        ],
      ),
      body: isDesktop || isTablet
          ? _buildDesktopLayout(context, state, isDarkMode)
          : _buildBody(context, state),
      bottomNavigationBar: booking != null && !isDesktop
          ? _buildBottomBar(context, booking)
          : null,
    );
  }

  Widget _buildDesktopLayout(BuildContext context, BookingHistoryState state,
      bool isDarkMode) {
    final theme = Theme.of(context);
    final booking = state.selectedBooking;

    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            isDarkMode ? Colors.white : theme.primaryColor,
          ),
        ),
      );
    }

    if (state.error != null || booking == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Oops! Something went wrong',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? 'Booking not found',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(bookingHistoryControllerProvider.notifier)
                    .loadBookingDetails(widget.bookingId);
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Event Image and Details
          Expanded(
            flex: 3,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          booking['events']['media_urls']?[0] ??
                              'https://via.placeholder.com/400x200',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      booking['events']['title'] ?? 'Unknown Event',
                      style: theme.textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildEventDetails(context, booking['events']),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Right side - Booking Information
          Expanded(
            flex: 2,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking Information',
                      style: theme.textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildBookingDetails(context, booking),
                    const SizedBox(height: 24),
                    if (booking['booking_status'] == 'confirmed' &&
                        booking['payment_status'] == 'paid')
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Download Ticket'),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              isDarkMode ? theme.primaryColorDark : theme
                                  .primaryColor,
                            ),
                            foregroundColor: WidgetStateProperty.all(
                                Colors.white),
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 24,
                              ),
                            ),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                          ),
                          onPressed: () {
                            // Track payment link interaction
                            if (!_hasTrackedPaymentLinkClick) {
                              setState(() {
                                _hasTrackedPaymentLinkClick = true;
                              });
                              // You could log this to analytics in a real app
                              debugPrint(
                                  'Payment link clicked - tracking interaction');
                            }
                            _downloadTicket(context);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, BookingHistoryState state) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            isDarkMode ? Colors.white : theme.primaryColor,
          ),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(bookingHistoryControllerProvider.notifier)
                    .loadBookingDetails(widget.bookingId);
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final booking = state.selectedBooking;
    if (booking == null) {
      return const Center(
        child: Text('Booking not found'),
      );
    }

    final event = booking['events'] as Map<String, dynamic>;
    final payments = booking['payment'] as List<dynamic>?;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16, top: 16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        event['title'] ?? 'Unknown Event',
                        style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                      ),
                      child: Text(
                        _getStatusText(booking['payment_status'] ?? '', booking['booking_status'] ?? ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Event images
          _buildEventImagesGallery(context, event),

          // Booking details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBookingDetails(context, booking),
                const SizedBox(height: 24),
                _buildEventDetails(context, event),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, Map<String, dynamic> booking) {
    final paymentStatus = booking['payment_status'] as String? ?? '';
    final bookingStatus = booking['status'] as String? ?? '';
    final hasQrCode = booking['ticket_number'] != null;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () => _downloadTicket(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasQrCode 
                        ? theme.colorScheme.primary
                        : Colors.purple,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasQrCode ? Icons.download_rounded : Icons.download_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Download Ticket',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    context.go(AppRoutes.bookingHistory);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme
          .of(context)
          .textTheme
          .titleMedium!
          .copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context,
      String label,
      String value, {
        bool isHighlighted = false,
        Color? valueColor,
        IconData? icon,
      }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[  
            Icon(
              icon,
              size: 20,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 8),
          ],
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                
                Text(
                  value,
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: valueColor ?? (isDarkMode ? Colors.white : Colors.black87),
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Global key for the ticket widget
  final GlobalKey _ticketKey = GlobalKey();

  Future<void> _downloadTicket(BuildContext context) async {
    final String localBookingId = widget.bookingId;
    
    try {
      if (!mounted) return;
      
      if (!_hasTrackedPaymentLinkClick) {
        setState(() {
          _hasTrackedPaymentLinkClick = true;
        });
        debugPrint('Payment link clicked - tracking interaction');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating your ticket...'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
      
      debugPrint('🎫 DOWNLOAD TICKET INITIATED - Booking ID: $localBookingId');
      final currentState = ref.read(bookingHistoryControllerProvider);
      debugPrint('🎫 CURRENT STATE - Has Booking: ${currentState.selectedBooking != null}');
      debugPrint('🎫 CURRENT STATE - Has Error: ${currentState.error ?? "None"}');
      
      final hasBookingData = ref.read(bookingHistoryControllerProvider).selectedBooking != null;
      
      if (!hasBookingData) {
        debugPrint('🎫 NO BOOKING DATA - LOADING DETAILS FIRST');
        await ref.read(bookingHistoryControllerProvider.notifier)
            .loadBookingDetails(localBookingId);
        
        final loadedState = ref.read(bookingHistoryControllerProvider);
        if (loadedState.selectedBooking == null) {
          debugPrint('❌ FATAL ERROR - COULD NOT LOAD BOOKING DATA');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Could not load booking data. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }
      
      if (!mounted) return;
      
      final ticketData = await ref.read(
          bookingHistoryControllerProvider.notifier)
          .generateTicket(localBookingId);
        
      if (!mounted) return;
      
      if (!context.mounted) return;
      
      final afterGenState = ref.read(bookingHistoryControllerProvider);
      debugPrint('🎫 AFTER TICKET GEN - Has Booking: ${afterGenState.selectedBooking != null}');
      debugPrint('🎫 AFTER TICKET GEN - Has Error: ${afterGenState.error ?? "None"}');
        
      if (ticketData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate ticket: No data found'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
        
      final booking = ticketData['booking'] as Map<String, dynamic>?;
      final event = ticketData['event'] as Map<String, dynamic>?;
      final user = ticketData['user'] as Map<String, dynamic>?;
      final ticketNumber = ticketData['ticket_number'] as String?;
        
      if (booking == null || event == null || user == null || ticketNumber == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate ticket: Missing required data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted || !context.mounted) return;
      
      await showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (BuildContext dialogContext) {
          final isDarkMode = Theme.of(dialogContext).brightness == Brightness.dark;

          return PopScope(
            canPop: true,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
                  maxWidth: 400,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Text(
                        'Your Ticket',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                        child: RepaintBoundary(
                          key: _ticketKey,
                          child: _buildTicketWidget(dialogContext, event, booking, user, ticketNumber),
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: ElevatedButton(
                        onPressed: () {
                          if (dialogContext.mounted) {
                            try {
                              _captureAndShareTicket(dialogContext, event['title'] as String? ?? 'Event');
                            } catch (e) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to share: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(dialogContext).brightness == Brightness.dark 
                              ? Colors.purple.shade600
                              : Theme.of(dialogContext).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Download & Share',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

    } catch (e) {
      debugPrint('Error generating ticket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download ticket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to capture the ticket widget as an image and share it
  Future<void> _captureAndShareTicket(BuildContext context, String eventTitle) async {
    try {
      // Track payment link interaction
      if (!_hasTrackedPaymentLinkClick) {
        setState(() {
          _hasTrackedPaymentLinkClick = true;
        });
        // You could log this to analytics in a real app
        debugPrint('Ticket download clicked - tracking interaction');
      }
      
      // Show loading indicator - using try-catch to prevent any UI errors
      try {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preparing your ticket...'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        // Silently handle any UI errors
        debugPrint('Error showing snackbar: $e');
      }
      
      // CRITICAL FIX: Add delay to ensure the widget is properly rendered
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Capture the ticket widget as an image with additional error handling
      RenderRepaintBoundary? boundary;
      try {
        boundary = _ticketKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          throw Exception('Cannot capture ticket image - boundary not found');
        }
      } catch (e) {
        debugPrint('Error finding render object: $e');
        throw Exception('Cannot capture ticket - rendering error');
      }
      
      // Capture the image with higher quality for better results
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to generate image data');
      }
      Uint8List pngBytes = byteData.buffer.asUint8List();
      
      // Close the dialog safely - using rootNavigator to ensure proper handling
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (e) {
          debugPrint('Error closing dialog: $e');
          // Fallback in case of navigation error
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      }

      if (kIsWeb) {
        // Web implementation - download directly in browser
        await _downloadTicketOnWeb(pngBytes, eventTitle);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket downloaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        try {
          if (Platform.isAndroid || Platform.isIOS) {
            // For mobile, first try the FileSaver method (works better on newer Android)
            final fileName = 'ticket_${eventTitle.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
            final result = await FileSaver.instance.saveFile(
              name: fileName,
              bytes: pngBytes,
              ext: 'png',
              mimeType: MimeType.png,
            );

            // If FileSaver worked, also offer to share
            final output = await getTemporaryDirectory();
            final file = File('${output.path}/$fileName');
            await file.writeAsBytes(pngBytes);
            
            // Share the image file
            await Share.shareXFiles(
              [XFile(file.path)],
              text: 'Your ticket for $eventTitle',
            );
          } else {
            // Fallback for other platforms
            final output = await getApplicationDocumentsDirectory();
            final file = File('${output.path}/ticket_${DateTime.now().millisecondsSinceEpoch}.png');
            await file.writeAsBytes(pngBytes);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ticket saved to: ${file.path}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error with FileSaver, using fallback method: $e');
          // Fallback to temporary directory and sharing
          final output = await getTemporaryDirectory();
          final file = File('${output.path}/ticket_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(pngBytes);

          // Share the image file
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Your ticket for $eventTitle',
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket saved and shared successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error capturing ticket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share ticket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Platform-specific method for downloading ticket on web
  Future<void> _downloadTicketOnWeb(Uint8List pngBytes, String eventTitle) async {
    final fileName = 'ticket_${eventTitle.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
    
    try {
      // Use FileSaver which works on both web and mobile
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: pngBytes,
        ext: 'png',
        mimeType: MimeType.png,
      );
    } catch (e) {
      debugPrint('Error saving file: $e');
      throw Exception('Failed to save file: $e');
    }
  }

  // Build the vertical ticket widget with the primary gradient
  Widget _buildTicketWidget(BuildContext context, Map<String, dynamic> event, 
      Map<String, dynamic> booking, Map<String, dynamic> user, String ticketNumber) {
    // Format dates - with recurring pattern support
    String formattedEventDate = 'Date not specified';
    String formattedTime = '8:00 p.m.';
    bool isRecurringEvent = false;
    String recurringLabel = '';
    Color recurringColor = Colors.amber;
    IconData recurringIcon = Icons.repeat;
    
    try {
      // First check for booked occurrence date
      DateTime? eventDate;
      DateTime? eventEndDate;
      
      if (booking['booked_occurrence_date'] != null) {
        eventDate = DateTime.parse(booking['booked_occurrence_date']);
        
        // For end time, add event duration to start time
        if (event['duration_minutes'] != null) {
          eventEndDate = eventDate.add(Duration(minutes: event['duration_minutes'] as int));
        } else {
          // Default to 1 hour if no duration specified
          eventEndDate = eventDate.add(const Duration(hours: 1));
        }
      } else {
        // Fallback to event start time if no booked occurrence date
        if (event['start_time'] != null) {
          eventDate = DateTime.parse(event['start_time']);
        } else if (event['start_date'] != null) {
          eventDate = DateTime.parse(event['start_date']);
        } else if (event['start_datetime'] != null) {
          eventDate = DateTime.parse(event['start_datetime']);
        }

        // Get end time
        if (event['end_time'] != null) {
          eventEndDate = DateTime.parse(event['end_time']);
        } else if (event['end_date'] != null) {
          eventEndDate = DateTime.parse(event['end_date']);
        } else if (event['end_datetime'] != null) {
          eventEndDate = DateTime.parse(event['end_datetime']);
        }
      }
      
      // Format the date and time
      if (eventDate != null) {
        formattedEventDate = DateFormat('EEE, MMM dd, yyyy').format(eventDate);
        formattedTime = DateFormat('hh:mm a').format(eventDate);
        if (eventEndDate != null) {
          formattedTime += ' - ${DateFormat('hh:mm a').format(eventEndDate)}';
        }
      }
    } catch (e) {
      debugPrint('Error formatting event date: $e');
    }
    
    String formattedBookingDate = 'Date not available';
    try {
      final createdAt = booking['created_at'] as String?;
      if (createdAt != null) {
        formattedBookingDate = DateFormat('MMM dd, yyyy')
            .format(DateTime.parse(createdAt));
      }
    } catch (e) {
      debugPrint('Error formatting booking date: $e');
    }
        
    // Get the event image URL
    final mediaUrlsRaw = event['media_urls'];
    final List<dynamic> mediaUrls = mediaUrlsRaw != null ? List.from(mediaUrlsRaw) : [];
    final String imageUrl = mediaUrls.isNotEmpty && mediaUrls[0] != null ? 
        mediaUrls[0].toString() : 'https://via.placeholder.com/400x200';
    
    // Get seat/row information if available
    final String row = (booking['seat_row'] as String?) ?? 'A';
    final String seatText = (booking['seat_number'] as String?) ?? '10';
    final int quantity = (booking['quantity'] as num?)?.toInt() ?? 1;
    
    // Create a container with gradient border
  return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 350),
      // Add a padding to create space for the border
      padding: const EdgeInsets.all(2),
      // Apply gradient as background for border effect
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Card(
        elevation: 0, // No shadow needed as the container handles the design
        margin: EdgeInsets.zero, // No margin needed
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with vertical rectangle image and text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event title and E-ticket tag (left aligned)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // E-Ticket tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'E-TICKET',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Event title
                          Text(
                            (event['title'] as String?) ?? 'Unknown Event',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    // Event image (right aligned)
                    const SizedBox(width: 16),
                    Container(
                      width: 100,
                      height: 140,
                      decoration: BoxDecoration(
                        // We'll keep just a slight rounding on the image to look nice
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main details section with white background
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                color: Colors.white.withOpacity(0.9),
                child: Column(
                  children: [
                    // Key info row (Date, Time, Row)
                    Row(
                      children: [
                        // Date column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show recurring badge if applicable
                              if (isRecurringEvent) ...[  
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: recurringColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: recurringColor.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(recurringIcon, size: 10, color: recurringColor),
                                      const SizedBox(width: 2),
                                      Text(
                                        recurringLabel,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: recurringColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Text(
                                'Date',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF757575),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedEventDate,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isRecurringEvent ? recurringColor : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Time column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF757575),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedTime,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black, // Always solid black
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Row column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quantity',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF757575),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                quantity.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black, // Always solid black
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Second row - Location
                    if (event['location'] != null) ...[  
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (event['location'] as String?) ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              
              // Divider with ticket cutout look
              Container(
                color: Colors.white.withOpacity(0.9),
                child: Row(
                  children: List.generate(
                    50,
                    (index) => Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: index % 2 == 0 ? Colors.transparent : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
              
              // QR Code section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                color: Colors.white.withOpacity(0.9),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Reference number column
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ticket #',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ticketNumber,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Amount',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${(booking['total_amount'] as num?)?.toString() ?? '0'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        
                        // QR code
                        QrImageView(
                          data: ticketNumber,
                          version: QrVersions.auto,
                          size: 100,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    Text(
                      'Show this QR code at the entrance',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Footer section with booking reference
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Text(
                  'Booking Reference: ${(booking['booking_reference'] as String?) ?? ticketNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Issue date and powered by text
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white.withOpacity(0.9),
                child: Column(
                  children: [
                    Text(
                      'Issued: $formattedBookingDate',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Powered by Vibe Swiper',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
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
  
  // Helper method for ticket detail rows
  Widget _buildTicketDetailRow(BuildContext context, String label, String value, {
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: valueStyle ?? Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildEventDetails(BuildContext context, Map<String, dynamic> event) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Event date parsing - with null safety
    DateTime? eventDate;
    DateTime? eventEndDate;
    String formattedEventDate = 'Date not specified';

    try {
      // First check for booked occurrence date from the booking
      final state = ref.read(bookingHistoryControllerProvider);
      final booking = state.selectedBooking;
      
      if (booking != null && booking['booked_occurrence_date'] != null) {
        eventDate = DateTime.parse(booking['booked_occurrence_date']);
        
        // For end time, add event duration to start time
        if (event['duration_minutes'] != null) {
          eventEndDate = eventDate.add(Duration(minutes: event['duration_minutes'] as int));
        } else {
          // Default to 1 hour if no duration specified
          eventEndDate = eventDate.add(const Duration(hours: 1));
        }
      } else {
        // Fallback to event start time if no booked occurrence date
        if (event['start_time'] != null) {
          eventDate = DateTime.parse(event['start_time']);
        } else if (event['start_date'] != null) {
          eventDate = DateTime.parse(event['start_date']);
        } else if (event['start_datetime'] != null) {
          eventDate = DateTime.parse(event['start_datetime']);
        }

        // Get end time
        if (event['end_time'] != null) {
          eventEndDate = DateTime.parse(event['end_time']);
        } else if (event['end_date'] != null) {
          eventEndDate = DateTime.parse(event['end_date']);
        } else if (event['end_datetime'] != null) {
          eventEndDate = DateTime.parse(event['end_datetime']);
        }
      }

      // Format the date and time
      if (eventDate != null) {
        if (eventEndDate != null) {
          formattedEventDate = '${DateFormat('EEE, MMM dd, yyyy - hh:mm a').format(eventDate)} to ${DateFormat('hh:mm a').format(eventEndDate)}';
        } else {
          formattedEventDate = DateFormat('EEE, MMM dd, yyyy - hh:mm a').format(eventDate);
        }
      }
    } catch (e) {
      debugPrint('Error parsing event date: $e');
      formattedEventDate = 'Date information unavailable';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location
        if (event['location'] != null) _buildDetailRow(
          context,
          'Location',
          event['location'],
          icon: Icons.location_on_outlined,
        ),

        // Date and Time
        _buildDetailRow(
          context,
          'Date & Time',
          formattedEventDate,
          icon: Icons.access_time,
        ),

        // Organizer
        if (event['organizer_name'] != null) _buildDetailRow(
          context,
          'Organizer',
          event['organizer_name'],
          icon: Icons.person_outline,
        ),

        // Description
        if (event['description'] != null) ...[
          const SizedBox(height: 16),
          Text(
            'About this event',
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event['description'],
            style: theme.textTheme.bodyMedium!.copyWith(
              height: 1.5,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],

        // Cancellation policy
        if (event['cancellation_policy'] != null) ...[
          const SizedBox(height: 24),
          Text(
            'Cancellation Policy',
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event['cancellation_policy'],
            style: theme.textTheme.bodyMedium!.copyWith(
              height: 1.5,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBookingDetails(BuildContext context,
      Map<String, dynamic> booking) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bookingStatus = booking['booking_status'] as String;
    final paymentStatus = booking['payment_status'] as String;
    final isPaid = paymentStatus == 'paid';
    final isConfirmed = bookingStatus == 'confirmed';
    final payments = booking['payment'] as List<dynamic>?;

    final bookingDate = DateTime.parse(booking['created_at']);
    final formattedBookingDate = DateFormat('MMM dd, yyyy - hh:mm a').format(
        bookingDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reference Number
        _buildDetailRow(
          context,
          'Reference',
          booking['booking_reference'] ?? '',
          isHighlighted: true,
        ),

        // QR Code for confirmed bookings
        if (isPaid && isConfirmed) ...[
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    // Track QR code interaction for analytics
                    setState(() {
                      _qrCodeInteractions++;
                    });
                    // Show a brief confirmation
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'QR Code accessed: $_qrCodeInteractions times'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: Theme
                            .of(context)
                            .primaryColor,
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: QrImageView(
                        data: booking['booking_reference'] ?? '',
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap QR code to scan ticket',
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Booking Details
        Text(
          'Booking Information',
          style: theme.textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow(context, 'Date', formattedBookingDate),
        _buildDetailRow(
          context, 'Status', _getStatusText(paymentStatus, bookingStatus),
          valueColor: _getStatusColor(paymentStatus, bookingStatus),
        ),
        _buildDetailRow(context, 'Quantity', '${booking['quantity']}'),
        _buildDetailRow(
            context, 'Price per ticket', '₹${booking['unit_price']}'),
        _buildDetailRow(
          context,
          'Total Amount',
          '₹${booking['total_amount']}',
          isHighlighted: true,
        ),

        // Payment Information if available
        if (payments != null && payments.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Payment Information',
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (payments.first['payment_method'] != null)
            _buildDetailRow(
              context,
              'Method',
              payments.first['payment_method'],
            ),
          if (payments.first['payment_reference'] != null)
            _buildDetailRow(
              context,
              'Reference',
              payments.first['payment_reference'],
            ),
        ],
      ],
    );
  }

// Build image component - displays a single image if only one is available
  Widget _buildEventImagesGallery(BuildContext context,
      Map<String, dynamic> event) {
    // Get original media URLs without duplication
    final List<dynamic> originalMediaUrls = event['media_urls'] != null ? List
        .from(event['media_urls']) : [];

    // If no images are available, show a placeholder
    if (originalMediaUrls.isEmpty) {
      originalMediaUrls.add(
          'https://via.placeholder.com/400x300?text=No+Image');
    }

    // If there's only one image, show a simplified view
    if (originalMediaUrls.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          height: 240,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  originalMediaUrls[0],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 50),
                        ),
                      ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isImageLiked = !_isImageLiked;
                        });
                      },
                      child: Icon(
                        _isImageLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isImageLiked ? Colors.red : Colors.grey,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show full gallery when multiple images are available
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary large image
          Container(
            height: 240,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    originalMediaUrls[_currentImageIndex],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 50),
                          ),
                        ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isImageLiked = !_isImageLiked;
                          });
                        },
                        child: Icon(
                          _isImageLiked ? Icons.favorite : Icons
                              .favorite_border,
                          color: _isImageLiked ? Colors.red : Colors.grey,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Row of smaller images
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: originalMediaUrls.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: _currentImageIndex == index
                          ? Border.all(color: Theme
                          .of(context)
                          .primaryColor, width: 2)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        originalMediaUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                  Icons.image_not_supported, size: 24),
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Image counter indicator
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
            child: Text(
              'Image ${_currentImageIndex + 1}/${originalMediaUrls.length}',
              style: Theme
                  .of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Status helper methods
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
