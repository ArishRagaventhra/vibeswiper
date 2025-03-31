import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../config/theme.dart';
import '../../payments/models/payment.dart';
import '../../payments/providers/payment_provider.dart';
import '../../../config/supabase_config.dart';

class EventPaymentScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventName;
  final VoidCallback onPaymentSuccess;

  const EventPaymentScreen({
    Key? key,
    required this.eventId,
    required this.eventName,
    required this.onPaymentSuccess,
  }) : super(key: key);

  @override
  ConsumerState<EventPaymentScreen> createState() => _EventPaymentScreenState();
}

class _EventPaymentScreenState extends ConsumerState<EventPaymentScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  Payment? _payment;
  bool _paymentFinalized = false;
  // Flag to check if we're using a placeholder event ID
  bool get _isPlaceholderEvent => widget.eventId == '00000000-0000-0000-0000-000000000000';

  @override
  Widget build(BuildContext context) {
    final userEmail = ref.read(supabaseClientProvider).auth.currentUser?.email ?? '';
    final userPhone = ref.read(supabaseClientProvider).auth.currentUser?.phone ?? '';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (!_isProcessing) {
              context.pop();
            } else {
              // Show dialog to prevent accidental navigation during payment
              _showCancelConfirmation();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Payment status card
              _buildPaymentStatusCard(),
              
              const SizedBox(height: 24),
              
              // Event details
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Event Name:', widget.eventName),
                      const SizedBox(height: 8),
                      _buildDetailRow('Event ID:', widget.eventId),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Amount:', 
                        '\u20b9499.00', // Get this from your config
                        valueStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Error message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Payment button
              if (!_paymentFinalized)
                SCompassButton(
                  text: _isProcessing ? 'Processing...' : 'Pay Now',
                  onPressed: _isProcessing
                      ? () {} // Disabled state
                      : () => _initiatePayment(userEmail, userPhone),
                  isLoading: _isProcessing,
                  variant: SCompassButtonVariant.filled,
                ),
              
              // Done button (after payment is complete)
              if (_paymentFinalized && _payment?.isSuccessful == true)
                SCompassButton(
                  text: 'Continue',
                  onPressed: () {
                    widget.onPaymentSuccess();
                    context.pop();
                  },
                  variant: SCompassButtonVariant.filled,
                ),
              
              // Retry button (if payment failed)
              if (_paymentFinalized && _payment?.isSuccessful != true)
                Column(
                  children: [
                    SCompassButton(
                      text: 'Try Again',
                      onPressed: () {
                        setState(() {
                          _paymentFinalized = false;
                          _errorMessage = null;
                          _payment = null;
                        });
                      },
                      variant: SCompassButtonVariant.filled,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentStatusCard() {
    if (_isProcessing) {
      return Card(
        color: const Color(0xFFF5F5F5), // Light gray background
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              LoadingWidget(),
              const SizedBox(height: 16),
              Text(
                'Processing Payment',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait while we process your payment. Do not close this screen.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (_paymentFinalized && _payment != null) {
      return Card(
        color: _payment!.isSuccessful
            ? Colors.green.shade50
            : Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                _payment!.isSuccessful ? Icons.check_circle : Icons.error,
                color: _payment!.isSuccessful ? Colors.green : Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _payment!.isSuccessful
                    ? 'Payment Successful!'
                    : 'Payment Failed',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _payment!.isSuccessful ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _payment!.isSuccessful
                    ? 'Your payment has been processed successfully.'
                    : _payment!.errorMessage ?? 'There was an issue processing your payment.',
                textAlign: TextAlign.center,
              ),
              if (_payment!.isSuccessful) ...[  
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Transaction ID: '),
                    SelectableText(
                      _payment!.razorpayPaymentId,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(
                Icons.payment,
                color: AppTheme.primaryColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Complete Payment',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please complete the payment to create your event.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ?? Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  void _initiatePayment(String email, String phone) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (!_isPlaceholderEvent) {
        await ref.read(paymentProvider.notifier).initiateEventPayment(
          eventId: widget.eventId,
          eventName: widget.eventName,
          userEmail: email,
          userContact: phone,
          onPaymentFinalized: (payment) {
            setState(() {
              _payment = payment;
              _paymentFinalized = true;
              _isProcessing = false;
            });
          },
        );
      } else {
        // Handle placeholder event ID
        setState(() {
          _payment = Payment.placeholder(
            razorpayPaymentId: 'placeholder_payment_id',
            isSuccessful: true,
          );
          _paymentFinalized = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text('A payment is currently being processed. Are you sure you want to leave this screen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              context.pop(); // Navigate back
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
