import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../payments/models/payment.dart';
import '../../payments/providers/payment_provider.dart';
import '../../../config/razorpay_config.dart';

class PaymentProcessDialog extends ConsumerStatefulWidget {
  final VoidCallback onPaymentComplete;
  final double? amount; // Add amount parameter to show dynamic payment amount

  const PaymentProcessDialog({
    required this.onPaymentComplete,
    this.amount, // Pass the payment amount (vibePrice or platform fee)
    super.key,
  });

  @override
  ConsumerState<PaymentProcessDialog> createState() => _PaymentProcessDialogState();
}

class _PaymentProcessDialogState extends ConsumerState<PaymentProcessDialog> {
  bool _paymentSuccess = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    
    // Set up a safety timeout - if a payment is successful but we don't get notified properly,
    // this will check payment status directly after 10 seconds and navigate if needed
    Future.delayed(Duration(seconds: 10), () {
      if (mounted && !_navigating && !_paymentSuccess) {
        _checkPaymentStatusDirectly();
      }
    });
  }
  
  // This is a fallback method to check payment status directly
  Future<void> _checkPaymentStatusDirectly() async {
    try {
      final payments = ref.read(paymentProvider).value ?? [];
      if (payments.isNotEmpty && payments.first.isSuccessful) {
        _navigateToEventsList();
      }
    } catch (e) {
      debugPrint('Error checking payment status directly: $e');
    }
  }
  
  void _navigateToEventsList() {
    if (_navigating) return; // Avoid duplicate navigation
    
    setState(() {
      _navigating = true;
      _paymentSuccess = true;
    });
    
    // First call the completion callback
    widget.onPaymentComplete();
    
    // Close dialog first
    Navigator.of(context).pop();
    
    // Then navigate to events list
    if (mounted) {
      debugPrint('Navigating to events list after payment from dialog');
      context.go('/events');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Get the amount to show - either the passed amount or default to platform listing fee
    final displayAmount = widget.amount?.toInt() ?? RazorpayConfig.PLATFORM_LISTING_FEE.toInt();

    // Set up our listener for payment status updates
    ref.listen<AsyncValue<List<Payment>>>(
      paymentProvider,
      (previous, next) {
        next.whenData((payments) {
          if (payments.isNotEmpty && payments.first.status == 'success' && !_navigating) {
            debugPrint('Payment success detected in dialog - navigating to events list');
            _navigateToEventsList();
          }
        });
      },
    );
    
    // Also listen to our navigation provider for a more comprehensive solution
    ref.listen(navigateToEventsAfterPaymentProvider, (previous, current) {
      if (current == true && !_navigating && mounted) {
        debugPrint('Navigation provider triggered in dialog - navigating to events list');
        _navigateToEventsList();
      }
    });

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_paymentSuccess) ...[
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Payment Successful!',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your event has been created.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Redirecting to events list...',
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Processing Payment',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Please complete the payment of Rs. $displayAmount in the Razorpay window.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'Do not close this window until payment is complete.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
