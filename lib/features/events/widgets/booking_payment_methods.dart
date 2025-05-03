import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingPaymentMethods extends StatelessWidget {
  final double amount;
  final Function(String method, String? provider) onPaymentSelected;
  final Function(String interactionType, String? provider)? onInteractionTracked;

  const BookingPaymentMethods({
    Key? key,
    required this.amount,
    required this.onPaymentSelected,
    this.onInteractionTracked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Text(
                  'Payment Methods',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context),
                  color: theme.colorScheme.onSurface,
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Text(
              'Total amount: ${currencyFormat.format(amount)}',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // UPI Section
                  Text(
                    'UPI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentMethodGrid([
                    _PaymentMethod(
                      name: 'Google Pay',
                      icon: 'assets/icons/google_pay.png',
                      method: 'upi',
                      provider: 'google_pay',
                    ),
                    _PaymentMethod(
                      name: 'PhonePe',
                      icon: 'assets/icons/phonepe.png',
                      method: 'upi',
                      provider: 'phonepe',
                    ),
                    _PaymentMethod(
                      name: 'Paytm',
                      icon: 'assets/icons/paytm.png',
                      method: 'upi',
                      provider: 'paytm',
                    ),
                    _PaymentMethod(
                      name: 'BHIM',
                      icon: 'assets/icons/bhim.png',
                      method: 'upi',
                      provider: 'bhim',
                    ),
                  ], context, theme, onPaymentSelected, onInteractionTracked),
                  
                  const SizedBox(height: 24),
                  
                  // Cards/Wallets Section
                  Text(
                    'Cards & Wallets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentMethodGrid([
                    _PaymentMethod(
                      name: 'Razorpay',
                      icon: 'assets/icons/razorpay.png',
                      method: 'razorpay',
                      provider: null,
                    ),
                    _PaymentMethod(
                      name: 'Credit Card',
                      icon: 'assets/icons/credit_card.png',
                      method: 'card',
                      provider: 'credit',
                    ),
                    _PaymentMethod(
                      name: 'Debit Card',
                      icon: 'assets/icons/debit_card.png',
                      method: 'card',
                      provider: 'debit',
                    ),
                    _PaymentMethod(
                      name: 'Net Banking',
                      icon: 'assets/icons/netbanking.png',
                      method: 'netbanking',
                      provider: null,
                    ),
                  ], context, theme, onPaymentSelected, onInteractionTracked),
                  
                  const SizedBox(height: 24),
                  
                  // QR Code Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Scan QR Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 200,
                          height: 200,
                          color: Colors.white,
                          child: GestureDetector(
                            onTap: () {
                              // Track QR code scan interaction
                              onInteractionTracked?.call('qr_code_scan', null);
                            },
                            child: Center(
                              child: Icon(
                                Icons.qr_code,
                                size: 160,
                                color: isDark ? Colors.black87 : Colors.grey[800],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            // Track QR code scan action and handle payment
                            onInteractionTracked?.call('qr_code_selected', null);
                            onPaymentSelected('qr_code', null);
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Scan & Pay',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodGrid(
    List<_PaymentMethod> methods,
    BuildContext context,
    ThemeData theme,
    Function(String method, String? provider) onPaymentSelected,
    Function(String interactionType, String? provider)? onInteractionTracked,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: methods.length,
      itemBuilder: (context, index) {
        final method = methods[index];
        return InkWell(
          onTap: () {
            onInteractionTracked?.call('payment_method_selected', method.provider);
            onPaymentSelected(method.method, method.provider);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // In a real app, we'd use Image.asset here. For now using a placeholder.
                Icon(
                  Icons.account_balance_wallet,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  method.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentMethod {
  final String name;
  final String icon;
  final String method;
  final String? provider;

  _PaymentMethod({
    required this.name,
    required this.icon,
    required this.method,
    this.provider,
  });
}
