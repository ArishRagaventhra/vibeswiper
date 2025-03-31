import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:scompass_07/features/events/chat/models/payment_type.dart';
import 'package:scompass_07/features/events/chat/models/payment_analytics.dart';
import 'package:flutter/services.dart';

class UpiQrCode extends StatelessWidget {
  final String upiId;
  final double size;
  final PaymentType paymentType;
  final String eventName;
  final String? userName;
  final String eventId;

  const UpiQrCode({
    Key? key,
    required this.upiId,
    this.size = 200,
    this.paymentType = PaymentType.upi,
    this.eventName = 'Event',
    this.userName,
    this.eventId = 'unknown',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format payment info for QR code based on payment type
    String qrData;
    
    // Create payment note with event name and user name
    String paymentNote = 'Vibeswiper $eventName event';
    if (userName != null && userName!.isNotEmpty) {
      paymentNote += ' by $userName';
    }
    
    // Encode the payment note for URL usage
    final encodedNote = Uri.encodeComponent(paymentNote);
    
    switch (paymentType) {
      case PaymentType.upi:
        // Format UPI ID for QR code with payment note - deep link that will open UPI apps
        qrData = 'upi://pay?pa=$upiId&pn=$encodedNote&tn=$encodedNote&am=&cu=INR';
        break;
      case PaymentType.razorpay:
        // For Razorpay, add the transaction note if not already present
        if (!upiId.contains('tn=')) {
          final separator = upiId.contains('?') ? '&' : '?';
          qrData = '$upiId${separator}tn=$encodedNote';
        } else {
          qrData = upiId;
        }
        break;
      case PaymentType.stripe:
      case PaymentType.url:
        // For other URLs, just use the URL directly
        qrData = upiId;
        break;
    }

    return GestureDetector(
      onTap: () {
        // Track the QR code scan when user taps on it (to view full screen or copy)
        _trackQRInteraction();
        
        // Show QR code in a dialog for easier scanning
        _showFullScreenQR(context, qrData);
      },
      child: QrImageView(
        data: qrData,
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        gapless: false,
      ),
    );
  }
  
  // Track QR code interaction
  Future<void> _trackQRInteraction() async {
    try {
      await PaymentAnalyticsService.trackPaymentInteraction(
        eventId: eventId,
        paymentType: paymentType,
        interactionType: PaymentInteractionType.qrCodeScan,
        paymentInfo: upiId,
      );
    } catch (e) {
      debugPrint('Failed to track QR code interaction: $e');
    }
  }
  
  // Show QR code in full screen for easier scanning
  void _showFullScreenQR(BuildContext context, String qrData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan QR Code',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: MediaQuery.of(context).size.width * 0.7,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: qrData));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('QR data copied to clipboard'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Data'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
