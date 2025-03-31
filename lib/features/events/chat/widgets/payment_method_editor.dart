import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme.dart';
import '../models/event_payment.dart';
import '../models/payment_type.dart';
import '../controllers/payment_controller.dart';

/// A dedicated widget for managing UPI and Razorpay payment methods
/// with direct database integration and caching support
class PaymentMethodEditor extends ConsumerStatefulWidget {
  final String eventId;
  final List<EventPayment> existingPayments;
  final VoidCallback? onPaymentUpdated;
  final int initialTabIndex;

  const PaymentMethodEditor({
    Key? key,
    required this.eventId,
    required this.existingPayments,
    this.onPaymentUpdated,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  ConsumerState<PaymentMethodEditor> createState() => _PaymentMethodEditorState();
}

class _PaymentMethodEditorState extends ConsumerState<PaymentMethodEditor> {
  // Active tab index
  int _activeTabIndex = 0;
  
  // Controllers for inputs
  final _upiController = TextEditingController();
  final _rzpController = TextEditingController();
  
  // Validation states
  bool _isUpiValid = false;
  bool _isRzpValid = false;
  
  // Loading states
  bool _isUpiLoading = false;
  bool _isRzpLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Look for existing UPI payment
    final upiPayment = widget.existingPayments.firstWhere(
      (payment) => payment.paymentType == PaymentType.upi,
      orElse: () => EventPayment(
        id: '',
        eventId: widget.eventId,
        paymentInfo: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    // Look for existing Razorpay payment
    final rzpPayment = widget.existingPayments.firstWhere(
      (payment) => payment.paymentType == PaymentType.razorpay,
      orElse: () => EventPayment(
        id: '',
        eventId: widget.eventId,
        paymentInfo: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    // Set initial values
    _upiController.text = upiPayment.paymentInfo;
    _rzpController.text = rzpPayment.paymentInfo;
    
    // Validate initial values
    _validateUpi(_upiController.text);
    _validateRazorpay(_rzpController.text);
    
    // Set initial tab based on what's available
    if (_upiController.text.isNotEmpty) {
      _activeTabIndex = 0;
    } else if (_rzpController.text.isNotEmpty) {
      _activeTabIndex = 1;
    } else {
      _activeTabIndex = widget.initialTabIndex;
    }
  }

  @override
  void dispose() {
    _upiController.dispose();
    _rzpController.dispose();
    super.dispose();
  }

  void _validateUpi(String value) {
    // UPI ID format validation
    final upiRegExp = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9]+$');
    setState(() {
      _isUpiValid = upiRegExp.hasMatch(value);
    });
  }

  void _validateRazorpay(String value) {
    // Razorpay link validation
    final urlRegExp = RegExp(
      r'^(http|https)://([\w-]+\.)+[\w-]+(/[\w-./?%&=]*)?$',
      caseSensitive: false,
      multiLine: false
    );
    
    setState(() {
      _isRzpValid = urlRegExp.hasMatch(value) && 
          (value.toLowerCase().contains('razorpay.com') || 
           value.toLowerCase().contains('rzp.io'));
    });
  }

  Future<void> _saveUpiPayment() async {
    if (!_isUpiValid) return;
    
    setState(() => _isUpiLoading = true);
    
    try {
      // Save UPI payment to database
      await ref.read(paymentControllerProvider.notifier).saveEventPayment(
        eventId: widget.eventId,
        paymentInfo: _upiController.text,
        paymentType: PaymentType.upi,
      );
      
      // Notify parent widget
      if (widget.onPaymentUpdated != null) {
        widget.onPaymentUpdated!();
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('UPI payment details saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving UPI details: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpiLoading = false);
      }
    }
  }

  Future<void> _saveRazorpayPayment() async {
    if (!_isRzpValid) return;
    
    setState(() => _isRzpLoading = true);
    
    try {
      // Save Razorpay payment to database
      await ref.read(paymentControllerProvider.notifier).saveEventPayment(
        eventId: widget.eventId,
        paymentInfo: _rzpController.text,
        paymentType: PaymentType.razorpay,
        paymentProcessor: 'razorpay',
      );
      
      // Notify parent widget
      if (widget.onPaymentUpdated != null) {
        widget.onPaymentUpdated!();
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Razorpay payment details saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving Razorpay details: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRzpLoading = false);
      }
    }
  }

  Future<void> _removePayment(PaymentType type) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove payment method?'),
          content: Text('Are you sure you want to remove this ${type == PaymentType.upi ? 'UPI' : 'Razorpay'} payment method?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      // Remove payment from database
      await ref.read(paymentControllerProvider.notifier).removeEventPaymentByType(
        widget.eventId,
        type,
      );
      
      // Update UI
      if (type == PaymentType.upi) {
        _upiController.clear();
        _isUpiValid = false;
      } else {
        _rzpController.clear();
        _isRzpValid = false;
      }
      
      // Notify parent widget
      if (widget.onPaymentUpdated != null) {
        widget.onPaymentUpdated!();
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type == PaymentType.upi ? 'UPI' : 'Razorpay'} payment method removed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing payment method: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      backgroundColor: theme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Manage your payments',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Tabs
            Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    context,
                    'UPI',
                    0,
                    Icons.account_balance_wallet,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton(
                    context,
                    'Razorpay',
                    1,
                    Icons.payment,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Tab content
            if (_activeTabIndex == 0) _buildUpiTab(context),
            if (_activeTabIndex == 1) _buildRazorpayTab(context),
            
            const SizedBox(height: 24),
            
            // Action buttons - Wrapped in a column for better responsiveness
            LayoutBuilder(
              builder: (context, constraints) {
                // On small screens (under 320dp width), use a column layout
                final isSmallScreen = constraints.maxWidth < 320;
                
                return isSmallScreen 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildActionButtons(isSmallScreen),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: _buildActionButtons(isSmallScreen),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build action buttons with consistent layout
  List<Widget> _buildActionButtons(bool isSmallScreen) {
    // On small screens, reverse the order so primary action is at the bottom
    final buttonSpacing = isSmallScreen ? const SizedBox(height: 8) : const SizedBox(width: 8);
    final buttons = <Widget>[];
    
    // Close button
    buttons.add(
      isSmallScreen
        ? TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          )
        : TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
    );
    
    buttons.add(buttonSpacing);
    
    // Remove button (when applicable)
    if (_activeTabIndex == 0 && _upiController.text.isNotEmpty) {
      buttons.add(
        isSmallScreen
          ? OutlinedButton.icon(
              onPressed: () => _removePayment(PaymentType.upi),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 40),
              ),
            )
          : OutlinedButton.icon(
              onPressed: () => _removePayment(PaymentType.upi),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
      );
    } else if (_activeTabIndex == 1 && _rzpController.text.isNotEmpty) {
      buttons.add(
        isSmallScreen
          ? OutlinedButton.icon(
              onPressed: () => _removePayment(PaymentType.razorpay),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 40),
              ),
            )
          : OutlinedButton.icon(
              onPressed: () => _removePayment(PaymentType.razorpay),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
      );
    }
    
    buttons.add(buttonSpacing);
    
    // Save button
    if (_activeTabIndex == 0) {
      buttons.add(
        isSmallScreen
          ? ElevatedButton(
              onPressed: _isUpiValid && !_isUpiLoading ? _saveUpiPayment : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade300,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ).copyWith(
                backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade300;
                    }
                    return null; // Use the component's default
                  },
                ),
                overlayColor: MaterialStateProperty.all(Colors.transparent),
              ),
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: _isUpiLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save UPI'),
                ),
              ),
            )
          : ElevatedButton(
              onPressed: _isUpiValid && !_isUpiLoading ? _saveUpiPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade300,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ).copyWith(
                backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade300;
                    }
                    return null;
                  },
                ),
                overlayColor: MaterialStateProperty.all(Colors.transparent),
              ),
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _isUpiLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save UPI'),
                ),
              ),
            ),
      );
    } else if (_activeTabIndex == 1) {
      buttons.add(
        isSmallScreen
          ? ElevatedButton(
              onPressed: _isRzpValid && !_isRzpLoading ? _saveRazorpayPayment : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade300,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ).copyWith(
                backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade300;
                    }
                    return null;
                  },
                ),
                overlayColor: MaterialStateProperty.all(Colors.transparent),
              ),
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: _isRzpLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Razorpay'),
                ),
              ),
            )
          : ElevatedButton(
              onPressed: _isRzpValid && !_isRzpLoading ? _saveRazorpayPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade300,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ).copyWith(
                backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.disabled)) {
                      return Colors.grey.shade300;
                    }
                    return null;
                  },
                ),
                overlayColor: MaterialStateProperty.all(Colors.transparent),
              ),
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _isRzpLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Razorpay'),
                ),
              ),
            ),
      );
    }
    
    // On small screens, return in display order (primary at bottom)
    // On larger screens, reverse to get the normal order (primary at right)
    return isSmallScreen ? buttons : buttons.reversed.toList();
  }

  Widget _buildTabButton(
    BuildContext context,
    String title,
    int index,
    IconData icon,
    Color color,
  ) {
    final isActive = _activeTabIndex == index;
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? color
                : theme.dividerColor,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? color : theme.iconTheme.color,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isActive ? color : theme.textTheme.bodyMedium?.color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'UPI ID',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your UPI ID (e.g., username@okbank)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _upiController,
          decoration: InputDecoration(
            hintText: 'username@upi',
            prefixIcon: const Icon(
              Icons.account_balance_wallet,
              color: Colors.green,
            ),
            suffixIcon: _upiController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _upiController.clear();
                      _validateUpi('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isUpiValid ? Colors.green : Colors.grey.shade300,
              ),
            ),
          ),
          onChanged: _validateUpi,
          autocorrect: false,
        ),
        if (!_isUpiValid && _upiController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Please enter a valid UPI ID (e.g., username@okbank)',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRazorpayTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Razorpay Payment Link',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your Razorpay payment link (e.g., https://rzp.io/...)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _rzpController,
          decoration: InputDecoration(
            hintText: 'https://rzp.io/...',
            prefixIcon: const Icon(
              Icons.payment,
              color: Colors.blue,
            ),
            suffixIcon: _rzpController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _rzpController.clear();
                      _validateRazorpay('');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _isRzpValid ? Colors.blue : Colors.grey.shade300,
              ),
            ),
          ),
          onChanged: _validateRazorpay,
          autocorrect: false,
          keyboardType: TextInputType.url,
        ),
        if (!_isRzpValid && _rzpController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Please enter a valid Razorpay link (e.g., https://rzp.io/...)',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.getData(Clipboard.kTextPlain).then((value) {
              if (value != null && value.text != null) {
                final text = value.text!;
                if (text.startsWith('http') && 
                   (text.contains('razorpay') || text.contains('rzp.io'))) {
                  _rzpController.text = text;
                  _validateRazorpay(text);
                }
              }
            });
          },
          icon: const Icon(Icons.paste, size: 16),
          label: const Text('Paste from clipboard'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
        ),
      ],
    );
  }
}
