import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/config/routes.dart';
import 'package:scompass_07/config/theme.dart';
import 'package:scompass_07/features/payments/providers/creator_payment_provider.dart';

import '../../features/events/providers/event_providers.dart';

class CreateOptionsSheet extends ConsumerWidget {
  const CreateOptionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewPadding = MediaQuery.of(context).viewPadding;
    
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        bottom: 16 + viewPadding.bottom, // Add padding for system navigation bar
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Create',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _CreateOption(
            icon: Icons.event_available,
            title: 'Create Event',
            subtitle: 'Plan and organize events',
            onTap: () => _checkPaymentSettingsAndNavigate(context, ref),
          ),
          SizedBox(height: 8), // Add some extra padding at the bottom
        ],
      ),
    );
  }

  // Method to check if user has payment settings before navigating to create event
  Future<void> _checkPaymentSettingsAndNavigate(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(currentUserProvider);
    
    if (currentUser == null) {
      // If not logged in, redirect to login
      context.go(AppRoutes.login);
      return;
    }

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing event creation...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      // Check if the creator has valid payment settings
      final hasValidSettings = await ref.read(hasValidPaymentSettingsProvider(currentUser.id).future);

      if (hasValidSettings) {
        // Has payment settings, proceed to create event
        if (context.mounted) context.go(AppRoutes.createEvent);
      } else {
        // No payment settings, show popup dialog
        if (context.mounted) {
          // Show popup dialog to inform user
          _showPaymentRequiredDialog(context);
        }
      }
    } catch (e) {
      // Handle any errors
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking payment settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to show payment required dialog
  void _showPaymentRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  'Payment Setup Required',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Message
                Text(
                  'Please set up your payment details before creating an event. This ensures you can receive payments seamlessly.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel button
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                    
                    // Setup button with gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGradientStart.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go(AppRoutes.creatorPaymentSettings);
                          },
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Text(
                              'Set Up Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreateOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}
