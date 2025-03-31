import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scompass_07/config/theme.dart';
import 'package:scompass_07/features/events/chat/models/event_payment.dart';
import 'package:scompass_07/features/events/chat/models/payment_type.dart';
import 'package:scompass_07/features/events/chat/widgets/upi_qr_code.dart';
import 'package:scompass_07/features/events/chat/models/payment_analytics.dart';

class PaymentLinkBanner extends StatelessWidget {
  final List<EventPayment> payments;
  final bool isOrganizer;
  final VoidCallback? onEdit;
  final Function(PaymentType)? onRemove;
  final String eventName;
  final String? userName;
  final String eventId;

  const PaymentLinkBanner({
    Key? key,
    required this.payments,
    required this.isOrganizer,
    this.onEdit,
    this.onRemove,
    this.eventName = 'Event',
    this.userName,
    this.eventId = 'unknown',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const SizedBox();
    }

    // Show the first payment method as the primary banner
    final primaryPayment = payments.first;
    final theme = Theme.of(context);
    final isUpi = primaryPayment.paymentType == PaymentType.upi;
    
    return Column(
      children: [
        // Primary payment banner with gradient
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book your spot now!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUpi 
                          ? 'Scan QR code to pay'
                          : _getPaymentDisplayText(primaryPayment),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryGradientStart,
                  elevation: 0,
                  minimumSize: const Size(96, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () {
                  _showPaymentOptionsModal(context, payments);
                },
                child: const Text(
                  'Pay Now', 
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        
        // If we have more than one payment method, show them as small chips
        if (payments.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surface.withOpacity(0.1),
            child: Row(
              children: [
                Text(
                  'Other payment options:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: payments.skip(1).map((payment) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildPaymentChip(context, payment),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Helper to get display text for payment methods
  String _getPaymentDisplayText(EventPayment payment) {
    switch(payment.paymentType) {
      case PaymentType.upi:
        return 'UPI: ${payment.paymentInfo}';
      case PaymentType.razorpay:
        return 'Pay here: ${payment.paymentInfo}';
      case PaymentType.stripe:
        return 'Pay here: ${payment.paymentInfo}';
      default:
        return 'Pay here: ${payment.paymentInfo}';
    }
  }
  
  // Launch payment URL or UPI app
  Future<void> _launchPayment(String paymentString, {PaymentType paymentType = PaymentType.url, EventPayment? payment}) async {
    String urlString = paymentString;
    String paymentNote = 'Vibeswiper ${eventName} event';
    
    if (userName != null && userName!.isNotEmpty) {
      paymentNote += ' by ${userName}';
    }
    
    // Encode the payment note for URL usage
    final encodedNote = Uri.encodeComponent(paymentNote);
    
    // Format UPI ID into a proper UPI intent URL with note
    if (paymentType == PaymentType.upi) {
      urlString = 'upi://pay?pa=$paymentString&pn=$encodedNote&tn=$encodedNote&am=&cu=INR';
    } else if (paymentType == PaymentType.razorpay && !paymentString.contains('tn=')) {
      // If it's a Razorpay URL and doesn't already have a transaction note, append it
      final separator = paymentString.contains('?') ? '&' : '?';
      urlString = '$paymentString${separator}tn=$encodedNote';
    }
    
    try {
      // Track the link click interaction
      await PaymentAnalyticsService.trackPaymentInteraction(
        eventId: payment?.eventId ?? eventId,
        paymentType: paymentType,
        interactionType: PaymentInteractionType.linkClick,
        paymentInfo: paymentString,
      );
      
      final Uri url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch payment method';
      }
    } catch (e) {
      debugPrint('Error launching payment: $e');
      // Show error toast or dialog here
    }
  }
  
  // Copy payment info to clipboard
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment info copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show all payment options in a modal
  void _showPaymentOptionsModal(BuildContext context, List<EventPayment> payments) {
    HapticFeedback.lightImpact();
    
    showDialog(
      context: context,
      builder: (context) => _buildPaymentOptionsDialog(context, payments),
    );
  }

  Widget _buildPaymentOptionsDialog(BuildContext context, List<EventPayment> payments) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    
    // Find UPI and other payment types if available
    final upiPayment = payments.firstWhere(
      (p) => p.paymentType == PaymentType.upi, 
      orElse: () => payments.first
    );
    
    // Calculate QR size based on screen dimensions
    final qrSize = size.width > 600 
        ? size.shortestSide * 0.35
        : size.width * 0.5;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: size.width > 600 ? size.width * 0.6 : null,
        constraints: BoxConstraints(
          maxHeight: size.height * 0.75,
          maxWidth: 500,
        ),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Book your spot now!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Loop through all payment methods and show them
                      ...payments.map((payment) => _buildPaymentMethod(context, payment, qrSize)),
                    
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              'Payments are made directly to the event organizer.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'VibeSwiper does not handle or guarantee payments. For any questions regarding the amount or payment methods, please reach out to the organizer directly.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethod(BuildContext context, EventPayment payment, double qrSize) {
    final isUpi = payment.paymentType == PaymentType.upi;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360; // Threshold for very small screens
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment method title
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _getColorForType(payment.paymentType).withOpacity(0.2),
                child: Icon(
                  _getIconForType(payment.paymentType),
                  size: 18,
                  color: _getColorForType(payment.paymentType),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getLabelForType(payment.paymentType),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // QR Code
          Center(
            child: Column(
              children: [
                Text(
                  isUpi ? 'Scan to Pay' : 'Scan to Visit Payment Page',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                UpiQrCode(
                  upiId: payment.paymentInfo,
                  paymentType: payment.paymentType,
                  size: qrSize,
                  eventName: eventName,
                  userName: userName,
                  eventId: eventId,
                ),
                const SizedBox(height: 12),
                Text(
                  isUpi 
                    ? 'UPI ID: ${payment.paymentInfo}'
                    : _getPaymentLabel(payment),
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Action buttons - adaptive layout based on screen size
          isSmallScreen
              ? Column(
                  children: [
                    // Copy button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(isUpi ? 'Copy ID' : 'Copy Link'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGradientStart,
                          side: BorderSide(color: AppTheme.primaryGradientStart),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          _copyToClipboard(context, payment.paymentInfo);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Open button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          isUpi ? Icons.smartphone : Icons.open_in_browser, 
                          size: 16
                        ),
                        label: Text(isUpi ? 'Open App' : 'Open Link'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGradientStart,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          _launchPayment(payment.paymentInfo, paymentType: payment.paymentType, payment: payment);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(
                          screenWidth < 400 
                              ? (isUpi ? 'Copy ID' : 'Copy') 
                              : (isUpi ? 'Copy UPI ID' : 'Copy Link')
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGradientStart,
                          side: BorderSide(color: AppTheme.primaryGradientStart),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () {
                          _copyToClipboard(context, payment.paymentInfo);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          isUpi ? Icons.smartphone : Icons.open_in_browser, 
                          size: 16
                        ),
                        label: Text(
                          screenWidth < 400 
                              ? (isUpi ? 'Open App' : 'Open') 
                              : (isUpi ? 'Open UPI App' : 'Open Link')
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGradientStart,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () {
                          _launchPayment(payment.paymentInfo, paymentType: payment.paymentType, payment: payment);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  String _getPaymentLabel(EventPayment payment) {
    switch (payment.paymentType) {
      case PaymentType.razorpay:
        return 'Razorpay: ${_truncateUrl(payment.paymentInfo)}';
      case PaymentType.stripe:
        return 'Stripe: ${_truncateUrl(payment.paymentInfo)}';
      default:
        return _truncateUrl(payment.paymentInfo);
    }
  }
  
  String _truncateUrl(String url) {
    if (url.length > 40) {
      return '${url.substring(0, 37)}...';
    }
    return url;
  }

  // Secondary payment method chip
  Widget _buildPaymentChip(BuildContext context, EventPayment payment) {
    final theme = Theme.of(context);
    final chipColor = _getColorForType(payment.paymentType);
    
    return InkWell(
      onTap: () {
        if (payment.paymentType == PaymentType.upi) {
          _showPaymentOptionsModal(context, [payment]);
        } else {
          _launchPayment(payment.paymentInfo, paymentType: payment.paymentType, payment: payment);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: chipColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconForType(payment.paymentType),
              size: 14,
              color: chipColor,
            ),
            const SizedBox(width: 4),
            Text(
              _getLabelForType(payment.paymentType),
              style: theme.textTheme.bodySmall?.copyWith(
                color: chipColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getIconForType(PaymentType type) {
    switch (type) {
      case PaymentType.upi:
        return Icons.account_balance_wallet;
      case PaymentType.razorpay:
        return Icons.payment;
      case PaymentType.stripe:
        return Icons.credit_card;
      default:
        return Icons.link;
    }
  }
  
  Color _getColorForType(PaymentType type) {
    switch (type) {
      case PaymentType.upi:
        return Colors.green;
      case PaymentType.razorpay:
        return Colors.blue;
      case PaymentType.stripe:
        return Colors.purple;
      default:
        return AppTheme.primaryGradientStart;
    }
  }
  
  String _getLabelForType(PaymentType type) {
    switch (type) {
      case PaymentType.upi:
        return 'UPI';
      case PaymentType.razorpay:
        return 'Razorpay';
      case PaymentType.stripe:
        return 'Stripe';
      default:
        return 'Payment Link';
    }
  }
}
