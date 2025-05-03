import 'package:flutter/material.dart';

/// Helper class for handling responsive layouts across different screen sizes
class ResponsiveLayout {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;
  
  /// Returns true if the screen width is smaller than the mobile breakpoint
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;
  
  /// Returns true if the screen width is between mobile and tablet breakpoints
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;
  
  /// Returns true if the screen width is larger than the tablet breakpoint
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;
  
  /// Returns a value based on screen size
  /// [mobile] - Value for mobile screens
  /// [tablet] - Value for tablet screens
  /// [desktop] - Value for desktop screens
  static T getResponsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) {
      return desktop;
    } else if (isTablet(context)) {
      return tablet ?? desktop;
    } else {
      return mobile;
    }
  }
  
  /// Returns a layout width constraint based on screen size
  static double getContentMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= tabletBreakpoint) {
      // On large screens, constrain content width
      return tabletBreakpoint - 200;
    } else if (width >= mobileBreakpoint) {
      // On medium screens, use a percentage of available width
      return width * 0.85;
    } else {
      // On small screens, use nearly full width
      return width;
    }
  }
  
  /// Returns appropriate horizontal padding based on screen size
  static EdgeInsets getHorizontalPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 40);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24);
    } else {
      return const EdgeInsets.symmetric(horizontal: 20);
    }
  }
}
