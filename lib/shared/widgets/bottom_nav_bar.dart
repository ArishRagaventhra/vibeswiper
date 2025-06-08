import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/config/routes.dart';
import 'package:scompass_07/features/forum/routes/forum_routes.dart';
import 'package:scompass_07/shared/widgets/compass_rose_shape.dart';
import 'package:scompass_07/shared/icons/nav_icons.dart';
import 'package:scompass_07/config/providers/theme_provider.dart';
import 'package:scompass_07/shared/widgets/user_avatar.dart';

import 'create_options_sheet.dart';

final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

// Screen size breakpoints
const double kTabletBreakpoint = 768;
const double kDesktopBreakpoint = 1024;

class SCompassBottomNavBar extends ConsumerStatefulWidget {
  const SCompassBottomNavBar({super.key});

  @override
  ConsumerState<SCompassBottomNavBar> createState() => _SCompassBottomNavBarState();
}

class _SCompassBottomNavBarState extends ConsumerState<SCompassBottomNavBar> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Navigation handler - centralized to ensure consistency between nav styles
  void _handleNavigation(int index) {
    HapticFeedback.lightImpact();
    ref.read(selectedNavIndexProvider.notifier).state = index;
    switch (index) {
      case 0:
        context.go(AppRoutes.eventsList);
        break;
      case 1:
        context.go(AppRoutes.eventSearch);
        break;
      case 2:
        context.go(AppRoutes.myEvents);
        break;
      case 3:
        context.go(AppRoutes.myEvents);
        break;
      case 4:
        context.go(AppRoutes.account);
        break;
    }
  }

  // Open create options sheet
  void _openCreateOptions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      builder: (context) => const CreateOptionsSheet(),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData selectedIcon, int index, bool isSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isProfileTab = index == 4;
    
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleNavigation(index),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: isProfileTab
                ? UserAvatar(
                    size: 28,
                    showBorder: false,
                  )
                : Icon(
                    isSelected ? selectedIcon : icon,
                    color: isSelected 
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton(bool isDark) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openCreateOptions,
        child: Container(
          height: 64,
          alignment: Alignment.center,
          child: Icon(
            Icons.add_circle_rounded,
            size: 32, // Slightly larger than regular icons
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  // Sidebar navigation item for larger screens
  Widget _buildSidebarNavItem(IconData icon, IconData selectedIcon, int index, bool isSelected, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isProfileTab = index == 4;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _handleNavigation(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: isSelected 
                ? theme.colorScheme.primary.withOpacity(0.1) 
                : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: isSelected && !isProfileTab
                    ? BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      )
                    : null,
                  child: isProfileTab
                    ? UserAvatar(
                        size: 36,
                        showBorder: !isSelected,
                      )
                    : Icon(
                        isSelected ? selectedIcon : icon,
                        color: isSelected 
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                        size: 20,
                      ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected 
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Create button for sidebar
  Widget _buildSidebarCreateButton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _openCreateOptions,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Create',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Sidebar Navigation for desktop and laptop
  Widget _buildSidebar() {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentThemeMode = ref.watch(themeNotifierProvider);

    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark 
            ? Color(0xFF1A1A1A) 
            : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(1, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Create button moved to top
          _buildSidebarCreateButton(),
          const SizedBox(height: 32),
          
          // Navigation Menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MENU',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSidebarNavItem(NavIcons.eventsOutlined, NavIcons.events, 0, selectedIndex == 0, 'Events'),
                _buildSidebarNavItem(Icons.search, Icons.search, 1, selectedIndex == 1, 'Search'),
                _buildSidebarNavItem(NavIcons.myEventsOutlined, NavIcons.myEvents, 3, selectedIndex == 3, 'My Events'),
                _buildSidebarNavItem(NavIcons.profileOutlined, NavIcons.profile, 4, selectedIndex == 4, 'Profile'),
              ],
            ),
          ),

          // Theme Toggle Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  // Toggle between light and dark mode
                  final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                  ref.read(themeNotifierProvider.notifier).setTheme(newMode);
                },
                child: Container(
                  width: 56,
                  height: 30,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: isDark
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : theme.colorScheme.primary,
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: isDark ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.grey[400]
                            : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          size: 16,
                          color: isDark
                              ? Colors.black.withOpacity(0.8)
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // App logo moved to bottom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/app_icon/vibeswiper.svg',
                height: 100,
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Navigation Bar for mobile and tablet
  Widget _buildBottomNavBar() {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewPadding = MediaQuery.of(context).viewPadding;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: EdgeInsets.only(bottom: viewPadding.bottom),
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(NavIcons.eventsOutlined, NavIcons.events, 0, selectedIndex == 0),
                  _buildNavItem(Icons.search, Icons.search, 1, selectedIndex == 1),
                  _buildCreateButton(isDark),
                  _buildNavItem(NavIcons.myEventsOutlined, NavIcons.myEvents, 3, selectedIndex == 3),
                  _buildNavItem(NavIcons.profileOutlined, NavIcons.profile, 4, selectedIndex == 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // For desktop/laptop (wide screens), return sidebar
    if (screenWidth >= kDesktopBreakpoint) {
      return _buildSidebar();
    }
    
    // For mobile/tablet (narrow screens), return bottom nav bar
    return _buildBottomNavBar();
  }
}
