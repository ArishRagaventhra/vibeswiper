import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../providers/payment_provider.dart';
import '../models/payment.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarColor = isDark ? AppTheme.darkBackgroundColor : Colors.white;
    final paymentsAsync = ref.watch(paymentProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Payment History',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: appBarColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.refresh(paymentProvider);
        },
        child: paymentsAsync.when(
          loading: () => const LoadingWidget(),
          error: (error, stack) => Center(
            child: EmptyState(
              icon: Icons.error_outline,
              title: 'Error Loading Payments',
              message: error.toString(),
              actionText: 'Try Again',
              onAction: () => ref.refresh(paymentProvider),
            ),
          ),
          data: (payments) => payments.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Payments Yet',
                    message: 'Your payment history will appear here',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    return PaymentHistoryItem(payment: payment);
                  },
                ),
        ),
      ),
    );
  }
}

class PaymentHistoryItem extends StatelessWidget {
  final Payment payment;

  const PaymentHistoryItem({
    Key? key,
    required this.payment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPaymentDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rs. ${payment.amount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(payment.createdAt),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusChip(payment.status),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                'Transaction ID',
                payment.razorpayPaymentId,
                Icons.confirmation_number_outlined,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                'Order ID',
                payment.razorpayOrderId,
                Icons.receipt_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'success':
        chipColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'failed':
        chipColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      default:
        chipColor = Colors.orange;
        statusIcon = Icons.pending_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDetails(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMMM dd, yyyy hh:mm a');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildDetailRow(context, 'Amount', 'Rs. ${payment.amount.toStringAsFixed(2)}'),
            _buildDetailRow(context, 'Status', payment.status.toUpperCase()),
            _buildDetailRow(context, 'Date', dateFormat.format(payment.createdAt)),
            _buildDetailRow(context, 'Transaction ID', payment.razorpayPaymentId),
            _buildDetailRow(context, 'Order ID', payment.razorpayOrderId),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  backgroundColor: theme.brightness == Brightness.dark 
                      ? AppTheme.darkPrimaryColor 
                      : AppTheme.primaryColor,
                  foregroundColor: theme.brightness == Brightness.dark 
                      ? AppTheme.darkLightTextColor 
                      : AppTheme.lightTextColor,
                ),
                child: Text(
                  'CLOSE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
