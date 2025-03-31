import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scompass_07/config/theme.dart';
import 'package:scompass_07/features/events/chat/models/payment_analytics.dart';
import 'package:scompass_07/features/events/chat/models/payment_type.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:scompass_07/shared/widgets/app_bar.dart';

class PaymentAnalyticsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const PaymentAnalyticsScreen({
    Key? key,
    required this.eventId,
    required this.eventName,
  }) : super(key: key);

  @override
  State<PaymentAnalyticsScreen> createState() => _PaymentAnalyticsScreenState();
}

class _PaymentAnalyticsScreenState extends State<PaymentAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, int> _summary = {};
  List<PaymentAnalytics> _recentInteractions = [];
  
  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }
  
  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load the summary data
      final summary = await PaymentAnalyticsService.getEventAnalyticsSummary(widget.eventId);
      
      // Load recent interactions (last 20)
      final analytics = await PaymentAnalyticsService.getEventPaymentAnalytics(widget.eventId);
      final recentInteractions = analytics.take(20).toList();
      
      setState(() {
        _summary = summary;
        _recentInteractions = recentInteractions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: SCompassAppBar(
        title: 'Payment Analytics',
        subtitle: Text(widget.eventName),
        centerTitle: false,
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(theme),
                    const SizedBox(height: 24),
                    _buildCharts(theme),
                    const SizedBox(height: 24),
                    _buildRecentActivityList(theme),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildSummaryCard(ThemeData theme) {
    final totalInteractions = _summary['total_interactions'] ?? 0;
    
    return Card(
      elevation: 3,
      shadowColor: theme.shadowColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, 
                  color: AppTheme.primaryGradientStart, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Payment Interactions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildMetricRow(
              theme,
              'Total Interactions', 
              totalInteractions.toString(),
              Icons.touch_app_outlined,
              AppTheme.primaryGradientStart,
            ),
            Divider(color: theme.dividerColor.withOpacity(0.1), height: 24),
            _buildMetricRow(
              theme,
              'Link Clicks', 
              (_summary['link_clicks'] ?? 0).toString(),
              Icons.link,
              AppTheme.primaryGradientEnd,
            ),
            Divider(color: theme.dividerColor.withOpacity(0.1), height: 24),
            _buildMetricRow(
              theme,
              'UPI Interactions', 
              (_summary['upi_interactions'] ?? 0).toString(),
              Icons.account_balance_wallet_outlined,
              Colors.green.shade400,
            ),
            Divider(color: theme.dividerColor.withOpacity(0.1), height: 24),
            _buildMetricRow(
              theme,
              'Razorpay Interactions', 
              (_summary['razorpay_interactions'] ?? 0).toString(),
              Icons.payment_outlined,
              Colors.pink,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricRow(ThemeData theme, String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildCharts(ThemeData theme) {
    // Determine if we have any payment data to show
    final hasPaymentData = (_summary['upi_interactions'] ?? 0) > 0 || 
                           (_summary['razorpay_interactions'] ?? 0) > 0;
    
    if (!hasPaymentData) {
      return const SizedBox.shrink(); // Don't show chart if no data
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.pie_chart, color: AppTheme.primaryGradientStart, size: 28),
            const SizedBox(width: 12),
            Text(
              'Payment Methods',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 3,
          shadowColor: theme.shadowColor.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: 1.3,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  centerSpaceColor: Colors.white,
                  sections: [
                    PieChartSectionData(
                      value: (_summary['upi_interactions'] ?? 0).toDouble(),
                      color: Colors.green.shade400,
                      title: '',
                      radius: 60,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      badgeWidget: null,
                      badgePositionPercentageOffset: 1.1,
                    ),
                    PieChartSectionData(
                      value: (_summary['razorpay_interactions'] ?? 0).toDouble(),
                      color: Colors.pink,
                      title: '',
                      radius: 60,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      badgeWidget: null,
                      badgePositionPercentageOffset: 1.1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Chart Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('UPI', Colors.green.shade400, theme),
              const SizedBox(width: 32),
              _buildLegendItem('Razorpay', Colors.pink, theme),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildLegendItem(String label, Color color, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _getIndicator(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
  
  Widget _buildRecentActivityList(ThemeData theme) {
    if (_recentInteractions.isEmpty) {
      return Card(
        elevation: 3,
        shadowColor: theme.shadowColor.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.history_outlined, 
                size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No payment interactions yet',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Your payment method interactions will appear here as users start scanning QR codes and clicking payment links.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: AppTheme.primaryGradientStart, size: 28),
            const SizedBox(width: 12),
            Text(
              'Recent Activity',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 3,
          shadowColor: theme.shadowColor.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _recentInteractions.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: theme.dividerColor.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final interaction = _recentInteractions[index];
              return ListTile(
                leading: _getInteractionIcon(interaction, theme),
                title: Text(
                  _getInteractionTitle(interaction),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(interaction.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                trailing: Text(
                  interaction.paymentType.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold, 
                    color: _getPaymentMethodColor(interaction.paymentType),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, 
                  vertical: 8,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _getInteractionIcon(PaymentAnalytics interaction, ThemeData theme) {
    final IconData icon;
    final Color color;
    
    if (interaction.interactionType == PaymentInteractionType.linkClick) {
      icon = Icons.link;
      color = AppTheme.primaryGradientEnd;
    } else {
      icon = Icons.qr_code_scanner;
      color = AppTheme.primaryGradientStart;
    }
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
  
  String _getInteractionTitle(PaymentAnalytics interaction) {
    switch (interaction.interactionType) {
      case PaymentInteractionType.linkClick:
        return 'Payment Link Clicked';
      case PaymentInteractionType.qrCodeScan:
        return 'QR Code Viewed';
      default:
        return 'Payment Interaction';
    }
  }
  
  Color _getPaymentMethodColor(PaymentType type) {
    switch (type) {
      case PaymentType.upi:
        return Colors.green.shade600;
      case PaymentType.razorpay:
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}
