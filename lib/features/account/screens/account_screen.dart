import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/current_profile_provider.dart';
import '../widgets/account_list_tile.dart';
import '../widgets/appearance_bottom_sheet.dart';
import '../../../config/routes.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isLoading = false;
  int _currentIndex = 3; // Account tab index

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signOut();
      if (mounted) {
        context.go('/login');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAppearanceBottomSheet() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => const AppearanceBottomSheet(),
    );
  }

  Future<void> _talkToFounder() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'arishragaventhra@gmail.com',
      query: 'subject=Feedback for Vibeswiper',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _shareApp() async {
    const text = 'Check out Vibeswiper - Turn swipes into stories!\n\n'
        'Download now from Play Store:\n'
        'https://play.google.com/store/apps/details?id=com.packages.scompass&pcampaignid=web_share';

    await Share.share(text);
  }

  Future<void> _rateApp() async {
    // Direct Play Store URL for the app - this will open the rating flow directly
    final Uri playStoreUrl = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.packages.scompass&showRating=true',
    );
    
    try {
      // Open directly in Play Store app to show the rating dialog
      await launchUrl(
        playStoreUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Play Store')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const LoadingWidget();
    }

    return ResponsiveScaffold(
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: Text('Profile not found'));

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                  title: Text(
                    'Account',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: false,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Section
                      Container(
                        padding: const EdgeInsets.all(16),
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
                        child: Row(
                          children: [
                            Hero(
                              tag: 'profile-avatar',
                              child: Avatar(
                                url: profile.avatarUrl,
                                size: 70,
                                name: profile.fullName ?? profile.username,
                                userId: profile.id,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName ?? profile.username,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '@${profile.username}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => context.push('/profile/edit'),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Account Section
                      Text(
                        'Account',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                              title: 'Settings',
                              icon: Icons.settings_outlined,
                              onTap: () => context.push('/settings'),
                              useDivider: false,
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Divider(
                                height: 1,
                                color: Colors.black12,
                              ),
                            ),
                            AccountListTile(
                              title: 'Paid Event History ',
                              icon: Icons.receipt_long_outlined,
                              onTap: () => context.push('/payments/history'),
                              useDivider: false,
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Divider(
                                height: 1,
                                color: Colors.black12,
                              ),
                            ),
                            AccountListTile(
                              title: 'Feedback & Feature Requests',
                              icon: Icons.feedback_outlined,
                              onTap: _talkToFounder,
                              useDivider: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // App Section
                      Text(
                        'App',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                              title: 'Appearance',
                              icon: Icons.palette_outlined,
                              onTap: _showAppearanceBottomSheet,
                              useDivider: false,
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Divider(
                                height: 1,
                                color: Colors.black12,
                              ),
                            ),
                            AccountListTile(
                              title: 'Share App',
                              icon: Icons.share_outlined,
                              onTap: _shareApp,
                              useDivider: false,
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Divider(
                                height: 1,
                                color: Colors.black12,
                              ),
                            ),
                            AccountListTile(
                              title: 'Rate App',
                              icon: Icons.star_outline,
                              onTap: _rateApp,
                              useDivider: false,
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              child: const Divider(
                                height: 1,
                                color: Colors.black12,
                              ),
                            ),
                            AccountListTile(
                              title: 'Talk to Founder',
                              icon: Icons.email_outlined,
                              onTap: _talkToFounder,
                              useDivider: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Logout Section
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
                          title: 'Logout',
                          icon: Icons.logout,
                          onTap: _logout,
                          textColor: theme.colorScheme.error,
                          iconColor: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}
