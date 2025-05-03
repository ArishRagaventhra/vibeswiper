import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../controllers/ticket_verification_controller.dart';
import '../models/ticket_booking_model.dart';

class TicketScannerScreen extends ConsumerStatefulWidget {
  final String eventId;
  
  const TicketScannerScreen({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  ConsumerState<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends ConsumerState<TicketScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool hasPermission = false;
  bool isFlashOn = false;
  bool isFrontCamera = false;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      hasPermission = status.isGranted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final verificationState = ref.watch(ticketVerificationControllerProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Ticket QR'),
        elevation: 0,
        actions: [
          // Flash toggle
          IconButton(
            icon: Icon(
              isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: isDarkMode ? Colors.white : null,
            ),
            onPressed: () {
              cameraController.toggleTorch();
              setState(() {
                isFlashOn = !isFlashOn;
              });
            },
          ),
          // Camera flip
          IconButton(
            icon: Icon(
              Icons.flip_camera_ios,
              color: isDarkMode ? Colors.white : null,
            ),
            onPressed: () {
              cameraController.switchCamera();
              setState(() {
                isFrontCamera = !isFrontCamera;
              });
            },
          ),
        ],
      ),
      body: _buildBody(verificationState, isDarkMode),
    );
  }

  Widget _buildBody(TicketVerificationState verificationState, bool isDarkMode) {
    if (!hasPermission) {
      return _buildPermissionDenied(isDarkMode);
    }

    if (verificationState.isVerified) {
      return _buildSuccessState(verificationState.booking!, isDarkMode);
    }

    if (verificationState.isAlreadyVerified) {
      return _buildAlreadyVerifiedState(verificationState.booking!, isDarkMode);
    }

    if (verificationState.error != null) {
      return _buildErrorState(verificationState.error!, isDarkMode);
    }

    return _buildScannerView(isDarkMode);
  }

  Widget _buildPermissionDenied(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_photography,
              size: 70,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
            ),
            const SizedBox(height: 24),
            Text(
              'Camera permission required',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please grant camera permission to scan ticket QR codes',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final status = await Permission.camera.request();
                setState(() {
                  hasPermission = status.isGranted;
                });
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Grant Permission'),
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

  Widget _buildScannerView(bool isDarkMode) {
    return Stack(
      children: [
        // Camera scanner
        MobileScanner(
          controller: cameraController,
          onDetect: (capture) {
            if (isProcessing) return; // Prevent multiple scans while processing
            
            final List<Barcode> barcodes = capture.barcodes;
            
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                setState(() {
                  isProcessing = true;
                });
                
                // Stop the camera while processing
                cameraController.stop();
                
                // Process the QR code
                _verifyTicket(barcode.rawValue!);
                break;
              }
            }
          },
        ),
        
        // Scanner overlay with colorful corners
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.transparent, width: 0),
            ),
            child: Stack(
              children: [
                // Top left corner
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: const Color(0xFFFF5252), width: 5),
                        left: BorderSide(color: const Color(0xFFFF5252), width: 5),
                      ),
                    ),
                  ),
                ),
                // Top right corner
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: const Color(0xFFFFB300), width: 5),
                        right: BorderSide(color: const Color(0xFFFFB300), width: 5),
                      ),
                    ),
                  ),
                ),
                // Bottom left corner
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: const Color(0xFF2979FF), width: 5),
                        left: BorderSide(color: const Color(0xFF2979FF), width: 5),
                      ),
                    ),
                  ),
                ),
                // Bottom right corner
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: const Color(0xFF00C853), width: 5),
                        right: BorderSide(color: const Color(0xFF00C853), width: 5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Scanner instructions and animation
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Scanning indicator
              if (isProcessing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? Colors.grey[900]!.withOpacity(0.8) 
                        : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? Colors.grey[900]!.withOpacity(0.8) 
                        : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'Align QR code within frame',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(TicketBooking booking, bool isDarkMode) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Check-in Complete',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Attendee successfully verified',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildTicketInfoCard(booking, isDarkMode),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Reset state and continue scanning
                ref.read(ticketVerificationControllerProvider.notifier).reset();
                // Restart camera
                cameraController.start();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Another'),
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

  Widget _buildAlreadyVerifiedState(TicketBooking booking, bool isDarkMode) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Already Checked In',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.amber[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This attendee has already been verified',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildTicketInfoCard(booking, isDarkMode),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Reset state and continue scanning
                ref.read(ticketVerificationControllerProvider.notifier).reset();
                // Restart camera
                cameraController.start();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Another'),
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

  Widget _buildErrorState(String error, bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.red[900] : Colors.red[100])?.withOpacity(0.3),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Verification Failed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Display a user-friendly error message
            Text(
              _formatErrorMessage(error),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                // Reset the verification state
                ref.read(ticketVerificationControllerProvider.notifier).reset();
                // Start scanner again
                cameraController.start();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Format error messages to be more user-friendly
  String _formatErrorMessage(String error) {
    // If it's a PostgreSQL exception, make it user-friendly
    if (error.contains('PostgrestException')) {
      return 'There was a problem accessing ticket information. Please try again or contact support.';
    }
    
    // Remove technical details from error messages
    if (error.contains('message:') && error.contains('code:')) {
      return 'Unable to verify ticket. Please make sure you are scanning a valid ticket QR code.';
    }
    
    return error;
  }

  Widget _buildTicketInfoCard(TicketBooking booking, bool isDarkMode) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking Reference',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.grey : Colors.grey[600],
                  ),
                ),
                Text(
                  booking.bookingReference,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quantity',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.grey : Colors.grey[600],
                  ),
                ),
                Text(
                  '${booking.quantity}',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.grey : Colors.grey[600],
                  ),
                ),
                Text(
                  '₹${booking.totalAmount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Status',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.grey : Colors.grey[600],
                  ),
                ),
                _buildStatusChip(
                  _getPaymentStatusText(booking.paymentStatus),
                  _getPaymentStatusColor(booking.paymentStatus),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking Status',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.grey : Colors.grey[600],
                  ),
                ),
                _buildStatusChip(
                  _getBookingStatusText(booking.bookingStatus),
                  _getBookingStatusColor(booking.bookingStatus),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  String _getPaymentStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.partially_paid:
        return 'Partially Paid';
      case PaymentStatus.refunded:
        return 'Refunded';
      default:
        return 'Unknown';
    }
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.unpaid:
        return Colors.red;
      case PaymentStatus.partially_paid:
        return Colors.orange;
      case PaymentStatus.refunded:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getBookingStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _getBookingStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _verifyTicket(String rawValue) async {
    try {
      // Verify the ticket with the controller
      await ref.read(ticketVerificationControllerProvider.notifier).verifyTicket(rawValue);
    } catch (e) {
      print('Error in _verifyTicket: $e');
      
      // In case of error, show the error screen
      if (mounted) {
        ref.read(ticketVerificationControllerProvider.notifier).state = 
          ref.read(ticketVerificationControllerProvider).copyWith(
            error: 'Error scanning ticket. Please try again.',
            isLoading: false
          );
      }
    } finally {
      // Ensure we set processing to false when done
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
