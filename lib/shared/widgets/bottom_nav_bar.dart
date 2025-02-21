import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/config/routes.dart';
import 'package:scompass_07/features/forum/routes/forum_routes.dart';
import 'package:scompass_07/shared/widgets/compass_rose_shape.dart';
import 'package:scompass_07/shared/icons/nav_icons.dart';

import 'create_options_sheet.dart';

final selectedNavIndexProvider = StateProvider<int>((ref) => 0);

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

  Widget _buildNavItem(IconData icon, IconData selectedIcon, int index, bool isSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
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
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: isSelected
            ? ShapeDecoration(
                shape: const CompassRoseShape(),
                color: isDark ? Colors.white : Colors.black,
                shadows: [
                  BoxShadow(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : null,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            isSelected ? selectedIcon : icon,
            color: isSelected 
              ? (isDark ? Colors.black : Colors.white)  // Icon color opposite of indicator
              : theme.colorScheme.onSurface.withOpacity(0.7),
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton(bool isDark) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
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
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 28,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withOpacity(0.8),
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
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
    );
  }
}
