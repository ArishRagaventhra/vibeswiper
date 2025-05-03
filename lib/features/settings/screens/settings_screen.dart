import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../config/theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../account/widgets/account_list_tile.dart';
import '../../../config/routes.dart';

// Provider for notification permission status
final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  final status = await Permission.notification.status;
  return status.isGranted;
});

// Provider for notification enabled state with persistence
final notificationEnabledProvider = StateProvider<bool>((ref) {
  // Default to true, but will be updated with actual permission status when available
  return true;
});

// Provider for supabase client
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});



class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? Your account will be permanently deleted after 30 days. You can recover your account by logging in within this period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authProvider).value;
      if (user == null) throw Exception('User not found');

      // Mark account for deletion
      await ref.read(supabaseProvider)
          .from('profiles')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', user.id);

      // Sign out the user
      await ref.read(authProvider.notifier).signOut();
      
      if (mounted) {
        context.go(AppRoutes.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarColor = isDark ? AppTheme.darkBackgroundColor : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;

    if (_isLoading) {
      return const LoadingWidget();
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: foregroundColor,
            size: 20,
          ),
          onPressed: () => context.go(AppRoutes.account),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const SizedBox(height: 8),
          
          // Account & Privacy Section
          _buildSectionHeader(
            context,
            'Account & Privacy',
            Icons.shield_outlined,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                AccountListTile(
                  title: 'Privacy Policy',
                  subtitle: 'How we handle your data',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => context.go(AppRoutes.privacyPolicy),
                  useDivider: false,
                ),
                AccountListTile(
                  title: 'Terms & Conditions',
                  subtitle: 'Rules and guidelines',
                  icon: Icons.description_outlined,
                  onTap: () => context.go(AppRoutes.termsConditions),
                  useDivider: false,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Help & Support Section
          _buildSectionHeader(
            context,
            'Help & Support',
            Icons.help_outline_rounded,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AccountListTile(
              title: 'Report Abuse',
              subtitle: 'Contact our support team',
              icon: Icons.support_agent,
              iconColor: theme.colorScheme.primary,
              onTap: () async {
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: 'scompassqueries@gmail.com',
                  query: 'subject=Report Abuse - Urgent',
                );
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                }
              },
              useDivider: false,
            ),
          ),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader(
            context,
            'Notifications',
            Icons.notifications_outlined,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Consumer(
              builder: (context, ref, _) {
                final notificationEnabled = ref.watch(notificationEnabledProvider);
                
                // Check current permission status
                final permissionStatus = ref.watch(notificationPermissionProvider);
                
                return permissionStatus.when(
                  data: (isGranted) {
                    // Sync our state with actual permission
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (ref.read(notificationEnabledProvider) != isGranted) {
                        ref.read(notificationEnabledProvider.notifier).state = isGranted;
                      }
                    });
                    
                    return SwitchListTile(
                      title: const Text('Push Notifications'),
                      subtitle: const Text('Receive updates about events and messages'),
                      value: notificationEnabled,
                      secondary: Icon(
                        notificationEnabled 
                            ? Icons.notifications_active
                            : Icons.notifications_off_outlined,
                        color: notificationEnabled
                            ? theme.colorScheme.primary
                            : theme.disabledColor,
                      ),
                      activeColor: theme.colorScheme.primary,
                      onChanged: (value) async {
                        if (value) {
                          // If turning on, request permission
                          final status = await Permission.notification.request();
                          final granted = status.isGranted;
                          
                          // Update state based on actual permission result
                          ref.read(notificationEnabledProvider.notifier).state = granted;
                          
                          // Refresh the permission provider
                          ref.refresh(notificationPermissionProvider);
                          
                          // Show appropriate message
                          if (mounted) {
                            if (granted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notifications enabled'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Permission denied. Please enable notifications in device settings.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              
                              // Show dialog to guide user to settings
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Enable Notifications'),
                                  content: const Text('To receive notifications, please enable them in your device settings.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        openAppSettings();
                                      },
                                      child: const Text('Open Settings'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        } else {
                          // If turning off, guide user to system settings
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Disable Notifications'),
                                content: const Text('To disable notifications, you need to turn them off in your device settings.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      openAppSettings();
                                    },
                                    child: const Text('Open Settings'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                  loading: () => const ListTile(
                    title: Text('Push Notifications'),
                    subtitle: Text('Checking permission status...'),
                    trailing: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => ListTile(
                    title: const Text('Push Notifications'),
                    subtitle: const Text('Unable to determine status'),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.refresh(notificationPermissionProvider),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Danger Zone Section
          _buildSectionHeader(
            context,
            'Danger Zone',
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.error.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: AccountListTile(
              title: 'Delete Account',
              subtitle: 'Permanently remove your account',
              icon: Icons.delete_outline,
              onTap: _deleteAccount,
              textColor: theme.colorScheme.error,
              iconColor: theme.colorScheme.error,
              useDivider: false,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    final headerColor = color ?? theme.colorScheme.primary;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: headerColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: headerColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class AccountListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool useDivider;
  final Color? iconColor;
  final Color? textColor;

  const AccountListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.useDivider = true,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor;

    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          leading: Icon(
            icon,
            size: 20,
            color: iconColor ?? theme.colorScheme.primary,
          ),
          title: Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: textColor ?? theme.colorScheme.onBackground,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor ?? theme.colorScheme.onBackground,
            ),
          ),
        ),
        if (useDivider)
          Divider(
            color: dividerColor,
            thickness: 1,
            height: 1,
            indent: 72,
            endIndent: 16,
          ),
      ],
    );
  }
}
