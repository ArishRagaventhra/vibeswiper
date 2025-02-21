import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../payments/models/payment.dart';
import '../../payments/providers/payment_provider.dart';

class PaymentProcessDialog extends ConsumerStatefulWidget {
  final VoidCallback onPaymentComplete;

  const PaymentProcessDialog({
    required this.onPaymentComplete,
    super.key,
  });

  @override
  ConsumerState<PaymentProcessDialog> createState() => _PaymentProcessDialogState();
}

class _PaymentProcessDialogState extends ConsumerState<PaymentProcessDialog> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Move ref.listen inside build method
    ref.listen<AsyncValue<List<Payment>>>(
      paymentProvider,
      (previous, next) {
        next.whenData((payments) {
          if (payments.isNotEmpty && payments.first.status == 'success') {
            widget.onPaymentComplete();
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        });
      },
    );

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Processing Payment',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Please complete the payment of Rs. 99 in the Razorpay window.',
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
        ),
      ),
    );
  }
}
