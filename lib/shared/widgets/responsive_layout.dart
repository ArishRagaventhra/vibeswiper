import 'package:flutter/material.dart';
import 'package:scompass_07/config/theme.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AppTheme.mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppTheme.mobileBreakpoint &&
      MediaQuery.of(context).size.width < AppTheme.tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppTheme.desktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppTheme.desktopBreakpoint && desktop != null) {
          return desktop!;
        }
        if (constraints.maxWidth >= AppTheme.tabletBreakpoint && tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}

class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  T resolve(BuildContext context) {
    if (ResponsiveLayout.isDesktop(context) && desktop != null) {
      return desktop!;
    }
    if (ResponsiveLayout.isTablet(context) && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}

class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry mobilePadding;
  final EdgeInsetsGeometry? tabletPadding;
  final EdgeInsetsGeometry? desktopPadding;

  const ResponsivePadding({
    super.key,
    required this.child,
    required this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: ResponsiveValue(
        mobile: mobilePadding,
        tablet: tabletPadding ?? EdgeInsets.all(AppTheme.spacing24),
        desktop: desktopPadding ?? EdgeInsets.all(AppTheme.spacing32),
      ).resolve(context),
      child: child,
    );
  }
}
